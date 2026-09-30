import '../../services/bist_stocks.dart';
import '../models/kap_entities.dart';

class KapEntityExtractor {
  const KapEntityExtractor();

  KapEntities extract(String text, {String? hintSymbol}) {
    final normalized = text.replaceAll('\n', ' ');

    final amountResult = _extractAmount(normalized);
    final dates = _extractDates(normalized);
    final percentages = _extractPercentages(normalized);
    final symbols = _extractSymbols(normalized, hintSymbol);
    final institution = _extractInstitution(normalized);
    final shareCount = _extractShareCount(normalized);
    final dividendPerShare = _extractDividendPerShare(normalized);
    final capitalRatio = _extractCapitalRatio(normalized, percentages);
    final projectScope = _extractProjectScope(normalized);

    return KapEntities(
      amount: amountResult?.$1,
      amountTl: amountResult?.$2,
      currency: amountResult?.$3,
      dates: dates,
      percentages: percentages,
      symbols: symbols,
      institution: institution,
      shareCount: shareCount,
      dividendPerShare: dividendPerShare,
      capitalRatio: capitalRatio,
      projectScope: projectScope,
    );
  }

  (String, double, String)? _extractAmount(String text) {
    // 1. Standart "10 milyon TL", "250.000 USD", "1.5 milyar ₺"
    final suffixRegex = RegExp(
      r'([\d.,]+)\s*(milyar|milyon|bin)?\s*(tl|₺|usd|eur|dolar|euro|sterlin|gbp)',
      caseSensitive: false,
    );
    final suffixMatch = suffixRegex.firstMatch(text);
    if (suffixMatch != null) {
      final raw = suffixMatch.group(0)!.trim();
      final numStr = suffixMatch.group(1)!;
      final unit = suffixMatch.group(2)?.toLowerCase() ?? '';
      final currRaw = suffixMatch.group(3)?.toLowerCase() ?? 'tl';

      final amount = _parseFormattedNumber(numStr, unit);
      if (amount > 0) {
        final (amountTl, currLabel) = _toTl(amount, currRaw);
        return (raw, amountTl, currLabel);
      }
    }

    // 2. Ön ekli para birimi: "$50.000.000", "€10M", "₺500.000"
    final prefixRegex = RegExp(
      r'(\$|€|£|₺)\s*([\d.,]+)\s*(milyar|milyon|bin)?',
      caseSensitive: false,
    );
    final prefixMatch = prefixRegex.firstMatch(text);
    if (prefixMatch != null) {
      final raw = prefixMatch.group(0)!.trim();
      final symbol = prefixMatch.group(1)!;
      final numStr = prefixMatch.group(2)!;
      final unit = prefixMatch.group(3)?.toLowerCase() ?? '';

      final currRaw = switch (symbol) {
        '\$' => 'usd',
        '€' => 'eur',
        '£' => 'gbp',
        _ => 'tl',
      };

      final amount = _parseFormattedNumber(numStr, unit);
      if (amount > 0) {
        final (amountTl, currLabel) = _toTl(amount, currRaw);
        return (raw, amountTl, currLabel);
      }
    }

    return null;
  }

  double _parseFormattedNumber(String numStr, String unit) {
    // Türkçe format (1.250.000,50) veya İngilizce (1,250,000.50)
    var cleaned = numStr.trim();
    if (cleaned.contains('.') && cleaned.contains(',')) {
      // 1.250.000,50 -> 1250000.50
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else if (cleaned.contains('.')) {
      final parts = cleaned.split('.');
      if (parts.length > 2 || (parts.length == 2 && parts[1].length == 3)) {
        // Binlik ayracı olarak nokta (1.250.000)
        cleaned = cleaned.replaceAll('.', '');
      }
    } else if (cleaned.contains(',')) {
      final parts = cleaned.split(',');
      if (parts.length == 2 && parts[1].length <= 2) {
        // Ondalık virgül (250,50)
        cleaned = cleaned.replaceAll(',', '.');
      } else {
        cleaned = cleaned.replaceAll(',', '');
      }
    }

    var val = double.tryParse(cleaned) ?? 0.0;
    if (unit == 'bin') val *= 1000;
    if (unit == 'milyon') val *= 1000000;
    if (unit == 'milyar') val *= 1000000000;
    return val;
  }

  (double, String) _toTl(double amount, String currencyRaw) {
    final lower = currencyRaw.toLowerCase();
    if (lower.contains('usd') || lower.contains('dolar') || lower == '\$') {
      return (amount * 38.0, 'USD');
    }
    if (lower.contains('eur') || lower.contains('euro') || lower == '€') {
      return (amount * 41.0, 'EUR');
    }
    if (lower.contains('gbp') || lower.contains('sterlin') || lower == '£') {
      return (amount * 48.0, 'GBP');
    }
    return (amount, 'TL');
  }

  List<String> _extractDates(String text) {
    final results = <String>[];
    final patterns = [
      RegExp(r'\d{2}\.\d{2}\.\d{4}'),
      RegExp(r'\d{2}/\d{2}/\d{4}'),
      RegExp(
        r'\d{1,2}\s+(ocak|şubat|mart|nisan|mayıs|haziran|temmuz|ağustos|eylül|ekim|kasım|aralık)\s+\d{4}',
        caseSensitive: false,
      ),
    ];
    for (final p in patterns) {
      for (final m in p.allMatches(text)) {
        final v = m.group(0)!;
        if (!results.contains(v)) results.add(v);
      }
    }
    return results.take(3).toList();
  }

  List<String> _extractPercentages(String text) {
    final results = <String>[];
    for (final m in RegExp(r'%[\d.,]+').allMatches(text)) {
      final v = m.group(0)!;
      if (!results.contains(v)) results.add(v);
    }
    for (final m in RegExp(r'[\d.,]+\s*%\s*oranında', caseSensitive: false)
        .allMatches(text)) {
      final v = m
          .group(0)!
          .replaceAll(RegExp(r'\s*oranında', caseSensitive: false), '')
          .trim();
      if (!results.contains(v)) results.add(v);
    }
    return results.take(3).toList();
  }

  List<String> _extractSymbols(String text, String? hint) {
    final upper = text.toUpperCase();
    final found = <String>{};

    if (hint != null && hint.length >= 3 && hint != 'KAP') {
      found.add(hint.toUpperCase());
    }

    for (final m in RegExp(r'\b[A-Z]{4,5}\b').allMatches(upper)) {
      final sym = m.group(0)!;
      if (kBistStocks.any((s) => s['symbol'] == sym)) {
        found.add(sym);
      }
    }

    return found.take(4).toList();
  }

  String? _extractInstitution(String text) {
    const institutions = [
      'Savunma Sanayii Başkanlığı',
      'Milli Savunma Bakanlığı',
      'Enerji ve Tabii Kaynaklar Bakanlığı',
      'Sağlık Bakanlığı',
      'Tarım ve Orman Bakanlığı',
      'Ulaştırma ve Altyapı Bakanlığı',
      'Çevre, Şehircilik ve İklim Değişikliği Bakanlığı',
      'ASELSAN',
      'TUSAŞ',
      'ROKETSAN',
      'HAVELSAN',
      'TEİAŞ',
      'TCDD',
      'BOTAŞ',
      'TOKİ',
      'Emlak Konut',
      'DSİ',
      'Karayolları Genel Müdürlüğü',
      'Türk Silahlı Kuvvetleri',
      'Turkcell',
      'Türk Telekom',
      'EPDK',
      'SPK',
      'BDDK',
      'TCMB',
      'Rekabet Kurumu',
    ];
    final lower = text.toLowerCase();
    for (final item in institutions) {
      if (lower.contains(item.toLowerCase())) return item;
    }
    return null;
  }

  String? _extractShareCount(String text) {
    final regex = RegExp(
      r'([\d.,]+)\s*(adet|lot)\s*(?:pay|hisse)?',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      return match.group(0)!.trim();
    }
    return null;
  }

  String? _extractDividendPerShare(String text) {
    final regex = RegExp(
      r'(?:hisse\s+başına|pay\s+başına)?\s*(?:net|brüt)?\s*([\d.,]+)\s*(?:tl|₺)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null &&
        (text.toLowerCase().contains('temettü') ||
            text.toLowerCase().contains('kar payı') ||
            text.toLowerCase().contains('kâr payı'))) {
      return match.group(0)!.trim();
    }
    return null;
  }

  String? _extractCapitalRatio(String text, List<String> percentages) {
    if (percentages.isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower.contains('bedelsiz') ||
        lower.contains('bedelli') ||
        lower.contains('sermaye')) {
      return percentages.first;
    }
    return null;
  }

  String? _extractProjectScope(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('güneş enerjisi') ||
        lower.contains('ges') ||
        lower.contains('çatı ges')) {
      return 'Güneş Enerjisi Santrali (GES) Yatırımı';
    }
    if (lower.contains('rüzgar enerjisi') || lower.contains('res')) {
      return 'Rüzgar Enerjisi Santrali (RES) Yatırımı';
    }
    if (lower.contains('savunma sanayi') ||
        lower.contains('askeri') ||
        lower.contains('mühimmat')) {
      return 'Savunma Sanayii Tedarik ve Üretim Projesi';
    }
    if (lower.contains('yazılım') ||
        lower.contains('bilişim') ||
        lower.contains('yapay zeka') ||
        lower.contains('dijitalleşme')) {
      return 'Bilişim ve Yazılım Çözümleri Projesi';
    }
    if (lower.contains('inşaat') ||
        lower.contains('taahhüt') ||
        lower.contains('konut') ||
        lower.contains('hastane')) {
      return 'İnşaat ve Taahhüt İşi';
    }
    if (lower.contains('ihracat') || lower.contains('yurtdışı')) {
      return 'Uluslararası İhracat Sözleşmesi';
    }
    return null;
  }
}
