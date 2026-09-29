import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/asset_model.dart';

/// NVIDIA NIM Teknik Analiz Servisi
///
/// Mimari:
///   Flutter → Cloud Function proxy → NVIDIA NIM API
///
/// NVIDIA API key ASLA uygulama bundle'ına girmez — sadece Cloud Function'da yaşar.
///
/// Fallback davranışı:
///   - Cloud Function'a ulaşılamazsa, timeout olursa veya hata dönerse
///     [null] döner → çağıran lokal analiz metnini kullanır.
class AiAnalysisService {
  // Cloud Function URL — europe-west1 region, teknik-bakis projesi
  static const String _functionUrl =
      'https://europe-west1-teknik-bakis.cloudfunctions.net/getTeknikAnaliz';

  static const Duration _timeout = Duration(seconds: 20);

  /// Hisse için AI yorumu getirir.
  /// Hata/timeout durumunda [null] döner — çağıran lokal fallback kullanır.
  static Future<String?> fetchAnalysis({
    required AssetModel asset,
    required int emaAboveCount,
    required double rsiValue,
    required double? supportLevel,
    required double? resistanceLevel,
    required bool volumeIncreasing,
    required double periodChange,
    required String periodLabel,
  }) async {
    try {
      final body = _buildRequestBody(
        asset: asset,
        emaAboveCount: emaAboveCount,
        rsiValue: rsiValue,
        supportLevel: supportLevel,
        resistanceLevel: resistanceLevel,
        volumeIncreasing: volumeIncreasing,
        periodChange: periodChange,
        periodLabel: periodLabel,
      );

      final response = await http
          .post(
            Uri.parse(_functionUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final analysis = json['analysis'] as String?;
        if (analysis != null && analysis.isNotEmpty) return analysis;
      }

      // 429, 503 veya beklenmedik durum → fallback
      return null;
    } catch (_) {
      // Timeout, ağ hatası vb. → fallback
      return null;
    }
  }

  static Map<String, dynamic> _buildRequestBody({
    required AssetModel asset,
    required int emaAboveCount,
    required double rsiValue,
    required double? supportLevel,
    required double? resistanceLevel,
    required bool volumeIncreasing,
    required double periodChange,
    required String periodLabel,
  }) {
    return {
      'symbol': asset.symbol,
      'name': asset.name,
      'price': asset.price,
      'changePercent': asset.changePercent,
      'rsi': rsiValue,
      'emaAboveCount': emaAboveCount,
      'supportLevel': supportLevel,
      'resistanceLevel': resistanceLevel,
      'volumeIncreasing': volumeIncreasing,
      'periodChange': periodChange,
      'periodLabel': periodLabel,
      'fk': asset.fk,
      'pdDd': asset.pdDd,
      // Teknik sinyaller
      'isBullishDivergence': asset.isBullishDivergence,
      'isBearishDivergence': asset.isBearishDivergence,
      'isGoldenCross': asset.isGoldenCross,
      'isDeathCross': asset.isDeathCross,
      'isMacdBullish': asset.isMacdBullish,
      'isMacdBearish': asset.isMacdBearish,
      'isSupertrendBuy': asset.isSupertrendBuy,
      'isSupertrendSell': asset.isSupertrendSell,
      'isHammer': asset.isHammer,
      'isBullishEngulfing': asset.isBullishEngulfing,
      'isMorningStar': asset.isMorningStar,
      'isBearishEngulfing': asset.isBearishEngulfing,
      'isDoji': asset.isDoji,
    };
  }
}
