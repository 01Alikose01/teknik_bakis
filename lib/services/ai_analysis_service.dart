import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/asset_model.dart';

/// NVIDIA NIM Dual AI Teknik Analiz Servisi
///
/// Mimari:
///   Flutter → Cloud Function proxy → NVIDIA NIM API
///   1. Ana AI:    NVIDIA Nemotron 3 Super 120B (nvidia/nemotron-3-super-120b-a12b)
///   2. Yedek AI:  OpenAI GPT-OSS 20B (openai/gpt-oss-20b)
///
/// NVIDIA API key ASLA uygulama bundle'ına girmez — sadece Cloud Function'da yaşar.
///
/// Fallback davranışı:
///   - Cloud Function'a ulaşılamazsa, timeout olursa veya hata (503) dönerse
///     [null] döner → çağıran analiz_screen.dart lokal analiz metnini (_buildGenel) kullanır.
class AiAnalysisService {
  // Cloud Function URL — europe-west1 region, teknik-bakis projesi
  static const String _functionUrl =
      'https://europe-west1-teknik-bakis.cloudfunctions.net/getTeknikAnaliz';

  static const Duration _timeout = Duration(seconds: 35);

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
        final cleaned = cleanAndValidate(analysis);
        if (cleaned != null && cleaned.isNotEmpty) return cleaned;
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

  /// AI yanıtını doğrular ve düşünce süreci / İngilizce sızıntılarını temizler.
  /// Temiz Türkçe analiz bulunamazsa `null` döner (bu durumda lokal Türkçe analize dönülür).
  static String? cleanAndValidate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var text = raw.trim();

    // 1. <think>...</think> etiketlerini ayıkla
    text = text.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '').trim();

    // 2. Eğer modelin İngilizce düşünme süreci sızdıysa ("Here's a thinking process" vb.)
    if (text.toLowerCase().contains("here's a thinking process") ||
        text.toLowerCase().contains("thinking process:") ||
        text.toLowerCase().contains("**analyze user request:**")) {
      final lines = text.split('\n');
      final turkishLines = <String>[];

      for (final line in lines) {
        final trimmed = line.trim();
        // Taslak Türkçe cümle yakalama: Draft sentence 1: "..."
        final draftMatch = RegExp(r'Draft sentence \d+[^:]*:\s*"?([^"\n]+)"?', caseSensitive: false).firstMatch(trimmed);
        if (draftMatch != null) {
          final content = draftMatch.group(1)?.trim();
          if (content != null && content.isNotEmpty) {
            turkishLines.add(content);
          }
          continue;
        }

        // İngilizce düşünce adımlarını atla
        if (RegExp(r'^(1\.|2\.|3\.|-|\*)\s*\*\*(analyze|deconstruct|tone|role|mandatory|length|content|task|draft|fundamentals|general)', caseSensitive: false).hasMatch(trimmed)) {
          continue;
        }

        // Türkçe karakter veya borsa terimi içeren satırları al
        if (RegExp(r'[çğıöşüÇĞİÖŞÜ]', caseSensitive: false).hasMatch(trimmed) &&
            !trimmed.toLowerCase().contains("here's a thinking process")) {
          final cleanedLine = trimmed.replaceAll(RegExp(r'^"|"$'), '');
          if (cleanedLine.isNotEmpty) {
            turkishLines.add(cleanedLine);
          }
        }
      }

      if (turkishLines.isNotEmpty) {
        text = turkishLines.join(' ').trim();
      } else {
        // Temiz Türkçe metin çıkmadıysa lokal analize dön
        return null;
      }
    }

    // 3. Başlangıçta İngilizce düşünce başlığı kaldıysa reddet
    if (RegExp(r'^(here|analyze|deconstruct|draft)', caseSensitive: false).hasMatch(text.trim())) {
      return null;
    }

    // 4. Asgari Türkçe doğrulaması: Türkçe harf veya Türkçe borsa anahtar kelimeleri
    final hasTurkishChar = RegExp(r'[çğıöşüÇĞİÖŞÜ]').hasMatch(text);
    final hasTurkishWord = RegExp(r'(fiyat|hisse|seviye|ortalama|destek|direnç|yatırım|artış|düşüş|görünüm|tavsiye)', caseSensitive: false).hasMatch(text);

    if (!hasTurkishChar && !hasTurkishWord) {
      return null;
    }

    // 5. Asgari uzunluk kontrolü (yarım kalmış taslakları engellemek için)
    // 3 paragraf × 2 kısa cümle ≈ en az 200 karakter olmalı
    if (text.length < 200) {
      return null;
    }

    return text;
  }
}

