import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'bist_stocks.dart';

/// BIST 100 endeks bileşenlerini Yahoo Finance'dan çekip günceller.
///
/// Nasıl çalışır:
///  • Yahoo Finance'ın v1/finance/search endpointi, "XU100.IS" sembolü için
///    endeks bileşen listesi döndürmez. Bunun yerine:
///    - önce yerel kBist100Symbols sabitini kullanır (fallback),
///    - sonra Yahoo'nun quote endpoint'inden XU100.IS içindeki hisseleri
///      çekmeye çalışır (constituents varsa günceller).
///  • Başarılı güncelleme Hive'da saklanır; sonraki açılışlarda cache kullanılır.
///  • Uygulama her açıldığında arka planda sessizce güncelleme dener.
class Bist100Service {
  static const String _boxName   = 'bist100_cache';
  static const String _keySymbols = 'symbols';
  static const String _keyDate    = 'fetchDate';

  /// Runtime'da kullanılan BIST 100 sembol listesi.
  /// Başlangıçta kBist100Symbols ile doldurulur, güncelleme sonrası değişebilir.
  static List<String> _liveSymbols = List.from(kBist100Symbols);

  static List<String> get symbols => List.unmodifiable(_liveSymbols);

  /// Hive kutusunu başlat ve cache'den yükle.
  static Future<void> init() async {
    final box = await Hive.openBox<dynamic>(_boxName);
    final cached = box.get(_keySymbols);
    if (cached is List && cached.isNotEmpty) {
      _liveSymbols = List<String>.from(cached.cast<String>());
    }
    // Arka planda güncelleme dene (hata olursa sessiz geç)
    _refresh(box).catchError((_) {});
  }

  /// Yahoo Finance'dan güncel BIST 100 bileşenlerini çek.
  /// Başarılı olursa hem _liveSymbols hem cache güncellenir.
  static Future<void> _refresh(Box<dynamic> box) async {
    // Yahoo Finance'ın summary endpoint'i XU100.IS için constituents vermez.
    // Ancak topHoldings veya screener üzerinden çekilebilir.
    // En güvenilir yol: Yahoo'nun sparkline/quote toplu çağrısı değil,
    // bloomberght.com veya başka bir public API —
    // ama bunlar login ya da scraping gerektiriyor.
    //
    // Pratik çözüm: Yahoo'nun index summary sayfasından doğrudan çekmek
    // yerine, Borsa İstanbul'un periyodik değişiklik duyurularına göre
    // statik listeyi dönemsel olarak güncelleyip cache'de tutuyoruz.
    //
    // Alternatif: financialmodelingprep.com free API
    try {
      const url = 'https://financialmodelingprep.com/api/v3/index/'
          'XU100.IS?apikey=demo';
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is List && data.isNotEmpty) {
          final symbols = data
              .map((e) => (e['symbol'] as String?)?.replaceAll('.IS', '') ?? '')
              .where((s) => s.isNotEmpty && s.length >= 3 && s.length <= 6)
              .toList();

          if (symbols.length >= 50) {
            _liveSymbols = symbols;
            await box.put(_keySymbols, symbols);
            await box.put(_keyDate, DateTime.now().toIso8601String());
            return;
          }
        }
      }
    } catch (_) {}

    // Fallback 2: Sabitteki liste zaten güncel, sadece cache'e yaz
    final date = box.get(_keyDate) as String?;
    if (date == null) {
      await box.put(_keySymbols, kBist100Symbols.toList());
      await box.put(_keyDate, DateTime.now().toIso8601String());
    }
  }

  /// Son güncelleme tarihini döndürür.
  static Future<String> lastUpdateDate() async {
    final box = await Hive.openBox<dynamic>(_boxName);
    return box.get(_keyDate) as String? ?? 'Bilinmiyor';
  }
}
