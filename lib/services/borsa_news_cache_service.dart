import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/borsa_news_item.dart';

/// Borsa haberlerini Firestore'da günlük olarak önbelleğe alır.
/// - Her gün 1 kez Firestore'a yazar
/// - İnternet yoksa Firestore'dan son haberleri yükler
class BorsaNewsCacheService {
  static const String _collectionName = 'news_cache';
  static const String _docId = 'borsa_latest';
  static const String _prefKey = 'borsa_news_last_saved_date';

  /// Haberleri Firestore'a günlük olarak kaydeder.
  /// Bugün zaten kaydedildiyse atlar.
  static Future<void> saveIfNeeded(List<BorsaNewsItem> items) async {
    if (items.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSaved = prefs.getString(_prefKey);
      final today = _todayStr();

      if (lastSaved == today) return; // Bugün zaten kaydedildi

      final firestore = FirebaseFirestore.instance;
      final encoded = items.map((item) => _itemToMap(item)).toList();

      await firestore.collection(_collectionName).doc(_docId).set({
        'items': encoded,
        'savedAt': FieldValue.serverTimestamp(),
        'date': today,
        'count': items.length,
      });

      await prefs.setString(_prefKey, today);
    } catch (_) {
      // Kaydetme başarısız olursa sessizce devam et
    }
  }

  /// Firestore'dan son kaydedilmiş haberleri yükler.
  /// Başarısız olursa boş liste döner.
  static Future<List<BorsaNewsItem>> loadFromFirestore() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final doc = await firestore
          .collection(_collectionName)
          .doc(_docId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) return [];

      final data = doc.data();
      if (data == null) return [];

      final rawItems = data['items'];
      if (rawItems is! List) return [];

      return rawItems
          .whereType<Map>()
          .map((m) => _itemFromMap(Map<String, dynamic>.from(m)))
          .where((item) => item.title.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Map<String, dynamic> _itemToMap(BorsaNewsItem item) => {
        'title': item.title,
        'summary': item.summary,
        'source': item.source,
        'time': item.time,
        'url': item.url,
        'category': item.category,
        'publishedDate': item.publishedDate?.toIso8601String(),
      };

  static BorsaNewsItem _itemFromMap(Map<String, dynamic> m) {
    DateTime? dt;
    try {
      final raw = m['publishedDate'];
      if (raw is String && raw.isNotEmpty) dt = DateTime.parse(raw).toLocal();
    } catch (_) {}

    return BorsaNewsItem(
      title: '${m['title'] ?? ''}',
      summary: '${m['summary'] ?? ''}',
      source: '${m['source'] ?? ''}',
      time: '${m['time'] ?? ''}',
      url: '${m['url'] ?? ''}',
      category: '${m['category'] ?? ''}',
      publishedDate: dt,
    );
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
