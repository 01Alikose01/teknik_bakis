import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'bist_stocks.dart';

/// BIST 100 endeks bileşenlerini ve tam BIST hisse listesini yönetir.
///
/// Güncelleme öncelik sırası:
///  1. Firestore  → `bist_index_meta/bist100` dokümanı (BIST 100 semboller)
///                  `bist_stocks` collection (sembol + şirket adı tam liste)
///  2. Hive cache → son başarılı Firestore verisini saklar (offline çalışma)
///  3. Sabit kod  → `kBist100Symbols` / `_baseBistStocks` (nihai fallback)
///
/// `Bist100Service.init()` uygulama açılışında arka planda çağrılır;
/// veri hazır olunca `syncBistStocksFromFirestore()` ile global değişkenler
/// (`kBistStocks`, `kBist100SymbolsLive`) güncellenir.
class Bist100Service {
  static const String _boxName          = 'bist100_cache';
  static const String _keyBist100       = 'symbols';       // List<String>
  static const String _keyStocksMaps    = 'stocks_maps';   // List<Map>
  static const String _keyDate          = 'fetchDate';     // ISO 8601

  /// Runtime'da `Bist100Service.symbols` getter'ının döndürdüğü liste.
  /// Başlangıçta sabit `kBist100Symbols`'tan kopyalanır;
  /// Firestore veya cache'den güncellendikten sonra dinamik hale gelir.
  static List<String> _liveSymbols = List.from(kBist100Symbols);

  static List<String> get symbols => List.unmodifiable(_liveSymbols);

  /// BIST 100 listesinin kaç hisse içerdiğini döndürür.
  static int get symbolCount => _liveSymbols.length;

  // ── Başlatma ───────────────────────────────────────────────────────────────

  /// Hive'dan cache yükler, arka planda Firestore'dan taze veri çeker.
  /// `main.dart`'ta `await` edilmeden çağrılır; hata olursa sessiz geçer.
  static Future<void> init() async {
    final box = await Hive.openBox<dynamic>(_boxName);
    _loadFromCache(box);
    _refreshFromFirestore(box).catchError((Object e) {
      debugPrint('[Bist100Service] Firestore güncelleme başarısız: $e');
    });
  }

  // ── Cache yükleme ──────────────────────────────────────────────────────────

  static void _loadFromCache(Box<dynamic> box) {
    // BIST 100 sembol listesi
    final cachedSymbols = box.get(_keyBist100);
    if (cachedSymbols is List && cachedSymbols.length >= 50) {
      _liveSymbols = List<String>.from(cachedSymbols.cast<String>());
    }

    // Tam hisse listesi
    final cachedMaps = box.get(_keyStocksMaps);
    if (cachedMaps is List && cachedMaps.isNotEmpty) {
      final stocks = _parseCachedMaps(cachedMaps);
      if (stocks.isNotEmpty) {
        syncBistStocksFromFirestore(
          firestoreStocks: stocks,
          firestoreBist100: _liveSymbols,
        );
      }
    }
  }

  // ── Firestore güncelleme ───────────────────────────────────────────────────

  static Future<void> _refreshFromFirestore(Box<dynamic> box) async {
    final firestore = FirebaseFirestore.instance;

    // 1. BIST 100 sembol listesi — bist_index_meta/bist100 dokümanı ──────────
    //
    //    Firestore'da beklenen yapı:
    //    bist_index_meta / bist100 {
    //      symbols: ['AKBNK', 'GARAN', ...],   // ~100 eleman
    //      updatedAt: Timestamp,
    //      revision: 'Ekim 2026',
    //      added: ['XXXXX'],                   // bilgi amaçlı, zorunlu değil
    //      removed: ['YYYYY'],                 // bilgi amaçlı, zorunlu değil
    //    }
    List<String> bist100Symbols = [];
    try {
      final metaDoc = await firestore
          .collection('bist_index_meta')
          .doc('bist100')
          .get()
          .timeout(const Duration(seconds: 12));

      if (metaDoc.exists) {
        final raw = metaDoc.data()?['symbols'];
        if (raw is List) {
          bist100Symbols = raw
              .map((s) => s.toString().trim().toUpperCase())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[Bist100Service] bist_index_meta/bist100 çekilemedi: $e');
    }

    // 2. Tam BIST hisse listesi — bist_stocks collection ─────────────────────
    //
    //    Firestore'da beklenen yapı (her doküman bir hisse):
    //    bist_stocks / AKBNK {
    //      symbol: 'AKBNK',          // zorunlu; yoksa doc.id kullanılır
    //      name: 'Akbank T.A.Ş.',    // zorunlu
    //      active: true,             // false ise BİST'ten çıkarılmış sayılır
    //    }
    List<Map<String, String>> bistStocks = [];
    try {
      // Sadece aktif hisseleri çek (active == false olanlar listeden dışlanır)
      final snapshot = await firestore
          .collection('bist_stocks')
          .where('active', isNotEqualTo: false)
          .get()
          .timeout(const Duration(seconds: 20));

      if (snapshot.docs.isNotEmpty) {
        bistStocks = snapshot.docs
            .map((doc) {
              final data = doc.data();
              final symbol = (data['symbol'] as String? ?? doc.id)
                  .trim()
                  .toUpperCase();
              final name = (data['name'] as String? ?? symbol).trim();
              if (symbol.isEmpty) return null;
              return {'symbol': symbol, 'name': name.isNotEmpty ? name : symbol};
            })
            .whereType<Map<String, String>>()
            .toList();
      }
    } catch (e) {
      debugPrint('[Bist100Service] bist_stocks collection çekilemedi: $e');
    }

    // 3. Her iki kaynak da boşsa işlem yapma ──────────────────────────────────
    if (bist100Symbols.isEmpty && bistStocks.isEmpty) return;

    // 4. Global değişkenleri güncelle ─────────────────────────────────────────
    syncBistStocksFromFirestore(
      firestoreStocks: bistStocks,
      firestoreBist100: bist100Symbols,
    );

    // _liveSymbols'ı da güncelle (Bist100Service.symbols getter'ı için)
    if (bist100Symbols.length >= 50) {
      _liveSymbols = bist100Symbols;
    }

    // 5. Başarılı veriyi cache'e kaydet ────────────────────────────────────────
    try {
      if (bist100Symbols.length >= 50) {
        await box.put(_keyBist100, bist100Symbols);
      }
      if (bistStocks.isNotEmpty) {
        await box.put(_keyStocksMaps, bistStocks);
      }
      await box.put(_keyDate, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[Bist100Service] Cache yazma hatası: $e');
    }
  }

  // ── Yardımcılar ────────────────────────────────────────────────────────────

  static List<Map<String, String>> _parseCachedMaps(List<dynamic> raw) {
    return raw
        .whereType<Map>()
        .map((e) => Map<String, String>.from(
              e.map((k, v) => MapEntry(k.toString(), v.toString())),
            ))
        .where((m) => (m['symbol'] ?? '').isNotEmpty)
        .toList();
  }

  /// Son başarılı Firestore güncellemesinin tarihini döndürür.
  static Future<String> lastUpdateDate() async {
    final box = await Hive.openBox<dynamic>(_boxName);
    return box.get(_keyDate) as String? ?? 'Bilinmiyor';
  }
}
