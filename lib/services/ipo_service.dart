import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/ipo_item.dart';
import 'bist_stocks.dart';

class IpoFeedData {
  final List<IpoItem> items;
  final DateTime? lastSyncedAt;
  final String source;
  final bool isFromCache;

  const IpoFeedData({
    required this.items,
    required this.lastSyncedAt,
    required this.source,
    required this.isFromCache,
  });
}

class IpoService {
  // ── Hive cache ─────────────────────────────────────────────────────────────
  static const String _cacheBoxName = 'ipo_cache';
  static const String _cacheItemsKey = 'items_json';
  static const String _cacheLastSyncedAtKey = 'last_synced_at';
  static const String _cacheSourceKey = 'source';

  // ── GitHub fallback (Firestore çalışmazsa) ─────────────────────────────────
  static const String _defaultFeedUrl =
      'https://raw.githubusercontent.com/01Alikose01/teknik_bakis/main/data/ipo_feed.json';
  static const String _defaultFeedCdnUrl =
      'https://cdn.jsdelivr.net/gh/01Alikose01/teknik_bakis@main/data/ipo_feed.json';

  static const String _configuredFeedUrl = String.fromEnvironment(
    'IPO_FEED_URL',
    defaultValue: '',
  );

  static const Duration refreshInterval = Duration(minutes: 45);

  // ── Önce cache/seed yükle, arka planda refresh ────────────────────────────
  static Future<IpoFeedData> loadCachedOrSeed() async {
    final box = await _openBox();
    final cachedJson = box.get(_cacheItemsKey)?.toString() ?? '';
    if (cachedJson.isNotEmpty) {
      final items = _decodeItems(cachedJson);
      if (items.isNotEmpty) {
        syncBistStocksWithIpoItems(items);
        return IpoFeedData(
          items: items,
          lastSyncedAt: _parseDate(box.get(_cacheLastSyncedAtKey)),
          source: box.get(_cacheSourceKey)?.toString() ?? 'Cache',
          isFromCache: true,
        );
      }
    }

    final seedJson = await rootBundle.loadString('assets/data/ipo_seed.json');
    final seedData = jsonDecode(seedJson) as Map<String, dynamic>;
    final items = _mapItems(seedData['items'] as List? ?? []);
    syncBistStocksWithIpoItems(items);

    return IpoFeedData(
      items: items,
      lastSyncedAt: _parseDate(seedData['lastUpdated']),
      source: seedData['source']?.toString() ?? 'Yerel yedek veri',
      isFromCache: false,
    );
  }

  // ── Yenile: önce Firestore, hata alırsa GitHub fallback ───────────────────
  static Future<IpoFeedData> refresh() async {
    // 1. Firestore'dan dene
    try {
      final result = await _refreshFromFirestore();
      if (result != null) return result;
    } catch (e) {
      debugPrint('Firestore IPO yenilemesi başarısız, GitHub fallback deneniyor: $e');
    }

    // 2. GitHub fallback
    return _refreshFromGithub();
  }

  // ── Firestore'dan çek ─────────────────────────────────────────────────────
  static Future<IpoFeedData?> _refreshFromFirestore() async {
    final firestore = FirebaseFirestore.instance;

    final snapshot = await firestore
        .collection('ipo_items')
        .get()
        .timeout(const Duration(seconds: 15));

    if (snapshot.docs.isEmpty) return null;

    final rawItems = snapshot.docs.map((doc) {
      final data = doc.data();
      // Firestore Timestamp → ISO string dönüşümü
      return _convertFirestoreDoc(data);
    }).toList();

    final items = _mapItems(rawItems);
    if (items.isEmpty) return null;

    // Meta belgeden lastUpdated al
    DateTime? lastUpdated;
    String source = 'Firestore';
    try {
      final metaDoc = await firestore.collection('ipo_meta').doc('feed').get();
      if (metaDoc.exists) {
        final ts = metaDoc.data()?['lastUpdated'];
        if (ts is Timestamp) lastUpdated = ts.toDate();
        source = metaDoc.data()?['source']?.toString() ?? 'Firestore';
      }
    } catch (_) {}

    lastUpdated ??= DateTime.now();

    // Cache'e kaydet (Firestore çalışmazsa bir sonraki açılışta kullanılır)
    await _saveToCache(rawItems, lastUpdated, source);

    syncBistStocksWithIpoItems(items);

    return IpoFeedData(
      items: items,
      lastSyncedAt: lastUpdated,
      source: source,
      isFromCache: false,
    );
  }

  // ── GitHub fallback ────────────────────────────────────────────────────────
  static Future<IpoFeedData> _refreshFromGithub() async {
    final urls = _candidateUrls();
    Object? lastError;

    for (final url in urls) {
      try {
        final response = await http
            .get(Uri.parse(url), headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          lastError = 'HTTP ${response.statusCode}';
          continue;
        }

        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final items = _mapItems(payload['items'] as List? ?? []);
        if (items.isEmpty) {
          lastError = 'Feed boş geldi';
          continue;
        }

        final box = await _openBox();
        await box.put(_cacheItemsKey, response.body);
        final lastUpdated = _parseDate(payload['lastUpdated']) ?? DateTime.now();
        await box.put(_cacheLastSyncedAtKey, lastUpdated.toIso8601String());
        await box.put(_cacheSourceKey, payload['source']?.toString() ?? url);

        syncBistStocksWithIpoItems(items);

        return IpoFeedData(
          items: items,
          lastSyncedAt: lastUpdated,
          source: payload['source']?.toString() ?? url,
          isFromCache: false,
        );
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception('Halka arz verisi yenilenemedi: $lastError');
  }

  static bool shouldRefresh(DateTime? lastSyncedAt) {
    if (lastSyncedAt == null) return true;
    return DateTime.now().difference(lastSyncedAt) >= refreshInterval;
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  static Map<String, dynamic> _convertFirestoreDoc(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is Timestamp) {
        result[entry.key] = value.toDate().toIso8601String();
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  static Future<void> _saveToCache(
    List<Map<String, dynamic>> rawItems,
    DateTime lastUpdated,
    String source,
  ) async {
    try {
      final box = await _openBox();
      final payload = jsonEncode({
        'lastUpdated': lastUpdated.toIso8601String(),
        'source': source,
        'items': rawItems,
      });
      await box.put(_cacheItemsKey, payload);
      await box.put(_cacheLastSyncedAtKey, lastUpdated.toIso8601String());
      await box.put(_cacheSourceKey, source);
    } catch (_) {}
  }

  static List<String> _candidateUrls() {
    final urls = <String>[];
    final configuredUrl = _configuredFeedUrl.trim();
    if (configuredUrl.isNotEmpty) urls.add(configuredUrl);
    for (final url in [_defaultFeedUrl, _defaultFeedCdnUrl]) {
      if (!urls.contains(url)) urls.add(url);
    }
    return urls;
  }

  static List<IpoItem> _decodeItems(String rawJson) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    return _mapItems(decoded['items'] as List? ?? []);
  }

  static List<IpoItem> _mapItems(List<dynamic> rawItems) {
    final all = rawItems
        .whereType<Map>()
        .map((item) => IpoItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    // Aynı sembol için en yüksek öncelikli statüyü tut
    final statusPriority = {
      IpoStatus.trading: 4,
      IpoStatus.pendingListing: 3,
      IpoStatus.collecting: 2,
      IpoStatus.upcoming: 1,
    };

    final deduped = <String, IpoItem>{};
    for (final item in all) {
      final key = item.symbol.toUpperCase();
      if (key.isEmpty) continue;
      final existing = deduped[key];
      if (existing == null) {
        deduped[key] = item;
      } else {
        final ep = statusPriority[existing.status] ?? 0;
        final np = statusPriority[item.status] ?? 0;
        if (np > ep) {
          deduped[key] = item;
        } else if (np == ep) {
          final ed = existing.publishedAt ?? existing.sortDate ?? DateTime(1970);
          final nd = item.publishedAt ?? item.sortDate ?? DateTime(1970);
          if (nd.isAfter(ed)) deduped[key] = item;
        }
      }
    }

    // Sembolsüz kayıtlar: aynı şirket adında sembolli kayıt yoksa ekle
    final normalizedNames = deduped.values
        .map((i) => i.companyName.trim().toLowerCase())
        .toSet();

    final noSymbol = all.where((item) {
      if (item.symbol.isNotEmpty) return false;
      return !normalizedNames.contains(item.companyName.trim().toLowerCase());
    }).toList();

    return [...deduped.values, ...noSymbol]
      ..sort((a, b) {
        final aDate = a.sortDate ?? DateTime(1970);
        final bDate = b.sortDate ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
  }

  static DateTime? _parseDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<Box<dynamic>> _openBox() async {
    if (Hive.isBoxOpen(_cacheBoxName)) return Hive.box(_cacheBoxName);
    return Hive.openBox(_cacheBoxName);
  }
}
