import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/ipo_item.dart';

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
  static const String _cacheBoxName = 'ipo_cache';
  static const String _cacheItemsKey = 'items_json';
  static const String _cacheLastSyncedAtKey = 'last_synced_at';
  static const String _cacheSourceKey = 'source';
  static const String _defaultFeedUrl =
      'https://raw.githubusercontent.com/01Alikose01/teknik_bakis/main/data/ipo_feed.json';
  static const String _defaultFeedCdnUrl =
      'https://cdn.jsdelivr.net/gh/01Alikose01/teknik_bakis@main/data/ipo_feed.json';

  static const String _configuredFeedUrl = String.fromEnvironment(
    'IPO_FEED_URL',
    defaultValue: '',
  );

  static const Duration refreshInterval = Duration(minutes: 45);

  static Future<IpoFeedData> loadCachedOrSeed() async {
    final box = await _openBox();
    final cachedJson = box.get(_cacheItemsKey)?.toString() ?? '';
    if (cachedJson.isNotEmpty) {
      final items = _decodeItems(cachedJson);
      if (items.isNotEmpty) {
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

    return IpoFeedData(
      items: _mapItems(seedData['items'] as List? ?? []),
      lastSyncedAt: _parseDate(seedData['lastUpdated']),
      source: seedData['source']?.toString() ?? 'Yerel yedek veri',
      isFromCache: false,
    );
  }

  static Future<IpoFeedData> refresh() async {
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
          lastError = 'Feed bos geldi';
          continue;
        }

        final box = await _openBox();
        await box.put(_cacheItemsKey, response.body);
        await box.put(
          _cacheLastSyncedAtKey,
          (payload['lastUpdated'] ?? DateTime.now().toIso8601String())
              .toString(),
        );
        await box.put(_cacheSourceKey, payload['source']?.toString() ?? url);

        return IpoFeedData(
          items: items,
          lastSyncedAt: _parseDate(payload['lastUpdated']) ?? DateTime.now(),
          source: payload['source']?.toString() ?? url,
          isFromCache: false,
        );
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw Exception('Halka arz verisi yenilenemedi: $lastError');
    }
    throw Exception('Halka arz verisi için URL yapılandırılmadı.');
  }

  static bool shouldRefresh(DateTime? lastSyncedAt) {
    if (lastSyncedAt == null) return true;
    return DateTime.now().difference(lastSyncedAt) >= refreshInterval;
  }

  static List<String> _candidateUrls() {
    final urls = <String>[];
    final configuredUrl = _configuredFeedUrl.trim();
    if (configuredUrl.isNotEmpty) {
      urls.add(configuredUrl);
    }
    for (final url in [_defaultFeedUrl, _defaultFeedCdnUrl]) {
      if (!urls.contains(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  static List<IpoItem> _decodeItems(String rawJson) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    return _mapItems(decoded['items'] as List? ?? []);
  }

  static List<IpoItem> _mapItems(List<dynamic> rawItems) {
    return rawItems
        .whereType<Map>()
        .map((item) => IpoItem.fromJson(Map<String, dynamic>.from(item)))
        .toList()
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
    if (Hive.isBoxOpen(_cacheBoxName)) {
      return Hive.box(_cacheBoxName);
    }
    return Hive.openBox(_cacheBoxName);
  }
}
