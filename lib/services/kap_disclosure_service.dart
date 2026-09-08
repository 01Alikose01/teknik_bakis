import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kap_news_item.dart';

/// KAP bildirimlerini Firestore'dan okur.
///
/// Flutter uygulaması KAP API'ye HİÇBİR ZAMAN direkt bağlanmaz.
/// Tüm veriler Cloud Function (syncKapDisclosures) tarafından
/// merkezi olarak Firestore'a yazılır, buradan okunur.
///
/// Koleksiyonlar:
///   kap_disclosures/{disclosureIndex}  — Bildirimler
///   kap_members/{id}                   — Şirket listesi
///   meta/kap                           — Son sync zamanı
class KapDisclosureService {
  static final _db = FirebaseFirestore.instance;

  // In-memory cache — aynı seansta Firestore'u tekrar yüklemeyi önler
  static final Map<String, _CachedDisclosures> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 10);

  static DateTime? _lastSyncTime;

  // ── Son sync zamanını al ──────────────────────────────────────────────────

  static Future<DateTime?> getLastSyncTime() async {
    try {
      final doc = await _db.collection('meta').doc('kap').get()
          .timeout(const Duration(seconds: 5));
      if (!doc.exists) return null;
      final ts = doc.data()?['lastSuccessfulSync'];
      if (ts is Timestamp) {
        _lastSyncTime = ts.toDate();
        return _lastSyncTime;
      }
    } catch (_) {}
    return _lastSyncTime;
  }

  // ── Tüm son bildirimleri al (ana KAP Bildirimleri sekmesi) ──────────────

  static Future<List<KapNewsItem>> fetchLatest({int limit = 60}) async {
    const cacheKey = '__latest__';
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.items;
    }

    try {
      final snapshot = await _db
          .collection('kap_disclosures')
          .orderBy('updated_at', descending: true)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 8));

      final items = snapshot.docs
          .map((doc) => _docToNewsItem(doc.data()))
          .where((item) => item.title.isNotEmpty)
          .toList();

      _cache[cacheKey] = _CachedDisclosures(
        items: items,
        fetchedAt: DateTime.now(),
      );
      return items;
    } catch (_) {
      return cached?.items ?? [];
    }
  }

  // ── Belirli bir hisse için bildirimleri al ────────────────────────────────

  static Future<List<KapNewsItem>> fetchByStockCode(
    String stockCode, {
    int limit = 20,
  }) async {
    final key = stockCode.toUpperCase();
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.items;
    }

    try {
      final snapshot = await _db
          .collection('kap_disclosures')
          .where('stock_code', isEqualTo: key)
          .orderBy('updated_at', descending: true)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 8));

      final items = snapshot.docs
          .map((doc) => _docToNewsItem(doc.data()))
          .where((item) => item.title.isNotEmpty)
          .toList();

      _cache[key] = _CachedDisclosures(
        items: items,
        fetchedAt: DateTime.now(),
      );
      return items;
    } catch (_) {
      // Firestore'dan çekilemezse cache'den dön
      return cached?.items ?? [];
    }
  }

  // ── Cache temizle (manuel yenileme) ─────────────────────────────────────

  static void clearCache([String? key]) {
    if (key != null) {
      _cache.remove(key);
    } else {
      _cache.clear();
    }
  }

  // ── Firestore belgesini KapNewsItem'a dönüştür ───────────────────────────

  static KapNewsItem _docToNewsItem(Map<String, dynamic> d) {
    final publishDate = d['publish_date']?.toString() ?? '';
    final publishTime = d['publish_time']?.toString() ?? '';
    final time = [publishDate, publishTime]
        .where((s) => s.isNotEmpty)
        .join(' ');

    // updated_at Timestamp → String
    String timeDisplay = time;
    if (timeDisplay.isEmpty) {
      final ts = d['updated_at'];
      if (ts is Timestamp) {
        final dt = ts.toDate().toLocal();
        timeDisplay =
            '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    // 72 saat kontrolü
    bool isWithin72h = true;
    final ts = d['updated_at'];
    if (ts is Timestamp) {
      final dt = ts.toDate();
      isWithin72h = DateTime.now().difference(dt).inHours < 72;
    }

    return KapNewsItem(
      title:       d['company_title']?.toString() ?? d['subject']?.toString() ?? 'KAP Bildirimi',
      summary:     d['subject']?.toString() ?? d['summary']?.toString() ?? '',
      source:      d['stock_code']?.toString() ?? 'KAP',
      time:        timeDisplay,
      url:         d['detail_url']?.toString() ?? '',
      isWithin72h: isWithin72h,
    );
  }
}

class _CachedDisclosures {
  final List<KapNewsItem> items;
  final DateTime fetchedAt;
  const _CachedDisclosures({required this.items, required this.fetchedAt});
}
