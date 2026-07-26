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

    return KapEntities(
      amount: amountResult?.$1,
      amountTl: amountResult?.$2,
      dates: dates,
      percentages: percentages,
      symbols: symbols,
      institution: institution,
    );
  }

  (String, double)? _extractAmount(String text) {
    final regex = RegExp(
      r'([\d.,]+)\s*(milyar|milyon|bin)?\s*(tl|₺|usd|eur|dolar|euro)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match == null) return null;

    final raw = match.group(0)!.trim();
    final value =
        double.tryParse(match.group(1)!.replaceAll('.', '').replaceAll(',', '.')) ??
            0;
    final unit = match.group(2)?.toLowerCase() ?? '';
    final currency = match.group(3)?.toLowerCase() ?? 'tl';

    double amount = value;
    if (unit == 'bin') amount *= 1000;
    if (unit == 'milyon') amount *= 1000000;
    if (unit == 'milyar') amount *= 1000000000;

    // TL karşılığı (yaklaşık kur — materyalite için)
    double amountTl = amount;
    if (currency.contains('usd') || currency.contains('dolar')) {
      amountTl = amount * 38;
    } else if (currency.contains('eur') || currency.contains('euro')) {
      amountTl = amount * 41;
    }

    return (raw, amountTl);
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
    for (final m
        in RegExp(r'[\d.,]+\s*%\s*oranında', caseSensitive: false).allMatches(text)) {
      final v = m.group(0)!.replaceAll(RegExp(r'\s*oranında', caseSensitive: false), '').trim();
      if (!results.contains(v)) results.add(v);
    }
    return results.take(3).toList();
  }

  List<String> _extractSymbols(String text, String? hint) {
    final upper = text.toUpperCase();
    final found = <String>{};

    if (hint != null && hint.length >= 4 && hint != 'KAP') {
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
      'ASELSAN',
      'TUSAŞ',
      'TEİAŞ',
      'TCDD',
      'Enerji ve Tabii Kaynaklar Bakanlığı',
      'Milli Savunma Bakanlığı',
      'Sağlık Bakanlığı',
      'Tarım ve Orman Bakanlığı',
      'BOTAŞ',
      'TOKİ',
      'DSİ',
      'Türk Silahlı Kuvvetleri',
      'EPDK',
      'SPK',
      'BDDK',
      'TCMB',
    ];
    final lower = text.toLowerCase();
    for (final item in institutions) {
      if (lower.contains(item.toLowerCase())) return item;
    }
    return null;
  }
}
