import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/ipo_item.dart';
import 'bist_stocks.dart';

/// Yeni Yaklaşan halka arz ikazı için callback tipi.
/// [newItems]: bu yenilemede ilk kez görülen Yaklaşan IPO listesi.
typedef IpoNewUpcomingCallback = void Function(List<IpoItem> newItems);

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

  /// Daha önce bildirim gönderilmiş IPO sembollerini saklayan Hive anahtarı.
  static const String _notifiedSymbolsKey = 'notified_ipo_symbols';

  /// Cache şema versiyonu — bu değer değişince eski cache otomatik temizlenir.
  static const String _cacheVersionKey = 'cache_version';
  static const int _cacheVersion = 3; // GitHub merge ile eksik price/lot/distributionType tamamlama

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

    // Cache versiyonunu kontrol et — eski versiyon varsa temizle
    final storedVersion = box.get(_cacheVersionKey) as int? ?? 0;
    if (storedVersion < _cacheVersion) {
      await box.delete(_cacheItemsKey);
      await box.delete(_cacheLastSyncedAtKey);
      await box.put(_cacheVersionKey, _cacheVersion);
      debugPrint('IPO cache temizlendi (versiyon $storedVersion → $_cacheVersion)');
    }

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

    // Firestore'da price/lot/distributionType eksik/"-" olan kayıtlar için
    // GitHub feed'den tamamlayıcı veri çek ve merge et.
    final mergedItems = await _mergeWithGithubFallback(rawItems);

    final items = _mapItems(mergedItems);
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
    await _saveToCache(mergedItems, lastUpdated, source);

    syncBistStocksWithIpoItems(items);

    return IpoFeedData(
      items: items,
      lastSyncedAt: lastUpdated,
      source: source,
      isFromCache: false,
    );
  }

  /// Firestore'dan gelen kayıtlarda price/lot/distributionType eksikse
  /// GitHub feed'den tamamlar. Ağ hatası olursa sessizce devam eder.
  static Future<List<Map<String, dynamic>>> _mergeWithGithubFallback(
    List<Map<String, dynamic>> firestoreItems,
  ) async {
    // Eksik alan var mı kontrol et
    bool hasMissing = firestoreItems.any((item) =>
        _isMissingField(item['price']) ||
        _isMissingField(item['lot']) ||
        _isMissingField(item['distributionType']));

    if (!hasMissing) return firestoreItems;

    // GitHub feed'i çek
    Map<String, Map<String, dynamic>> githubMap = {};
    try {
      for (final url in _candidateUrls()) {
        try {
          final response = await http
              .get(Uri.parse(url), headers: const {'Accept': 'application/json'})
              .timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final payload = jsonDecode(response.body) as Map<String, dynamic>;
            final ghItems = payload['items'] as List? ?? [];
            for (final ghItem in ghItems) {
              if (ghItem is Map) {
                final sym = (ghItem['symbol'] ?? '').toString().toUpperCase();
                if (sym.isNotEmpty) {
                  githubMap[sym] = Map<String, dynamic>.from(ghItem);
                }
              }
            }
            break;
          }
        } catch (_) {}
      }
    } catch (_) {}

    if (githubMap.isEmpty) return firestoreItems;

    // Merge: Firestore'da eksik olan alanları GitHub'dan tamamla
    return firestoreItems.map((item) {
      final sym = (item['symbol'] ?? '').toString().toUpperCase();
      final ghItem = githubMap[sym];
      if (ghItem == null) return item;

      final merged = Map<String, dynamic>.from(item);

      if (_isMissingField(item['price']) && !_isMissingField(ghItem['price'])) {
        merged['price'] = ghItem['price'];
      }
      if (_isMissingField(item['lot']) && !_isMissingField(ghItem['lot'])) {
        merged['lot'] = ghItem['lot'];
      }
      if (_isMissingField(item['distributionType']) &&
          !_isMissingField(ghItem['distributionType'])) {
        merged['distributionType'] = ghItem['distributionType'];
      }
      // listingDate eksikse GitHub'dan al
      if (_isMissingField(item['listingDate']) &&
          !_isMissingField(ghItem['listingDate'])) {
        merged['listingDate'] = ghItem['listingDate'];
      }
      // requestDates eksikse GitHub'dan al
      if (_isMissingField(item['requestDates']) &&
          !_isMissingField(ghItem['requestDates'])) {
        merged['requestDates'] = ghItem['requestDates'];
      }

      return merged;
    }).toList();
  }

  /// Bir alanın boş veya "-" olup olmadığını kontrol eder.
  static bool _isMissingField(dynamic value) {
    if (value == null) return true;
    final s = value.toString().trim();
    return s.isEmpty || s == '-';
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
    // publishedAt yoksa createdAt'i fallback olarak kullan
    if (!result.containsKey('publishedAt') || result['publishedAt'] == null) {
      final createdAt = result['createdAt'];
      if (createdAt != null) {
        result['publishedAt'] = createdAt;
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
      await box.put(_cacheVersionKey, _cacheVersion);
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
      IpoStatus.postponed: 0,
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

  // ── Yeni Yaklaşan IPO tespiti ─────────────────────────────────────────────

  /// [items] listesindeki Yaklaşan (upcoming) IPO'lardan daha önce
  /// bildirilmemiş olanları döndürür.
  /// Dönen liste boş değilse çağıran taraf bildirim göstermelidir.
  static Future<List<IpoItem>> detectNewUpcomingIpos(
    List<IpoItem> items,
  ) async {
    final box = await _openBox();
    final raw = box.get(_notifiedSymbolsKey)?.toString() ?? '';
    final notified = raw.isEmpty
        ? <String>{}
        : Set<String>.from(
            (jsonDecode(raw) as List).map((e) => e.toString()),
          );

    final upcoming = items
        .where((item) => item.status == IpoStatus.upcoming)
        .toList();

    final newOnes = upcoming.where((item) {
      final key = item.symbol.isNotEmpty
          ? item.symbol.toUpperCase()
          : item.companyName.trim().toLowerCase();
      return !notified.contains(key);
    }).toList();

    if (newOnes.isNotEmpty) {
      for (final item in newOnes) {
        final key = item.symbol.isNotEmpty
            ? item.symbol.toUpperCase()
            : item.companyName.trim().toLowerCase();
        notified.add(key);
      }
      await box.put(_notifiedSymbolsKey, jsonEncode(notified.toList()));
    }

    return newOnes;
  }
}
