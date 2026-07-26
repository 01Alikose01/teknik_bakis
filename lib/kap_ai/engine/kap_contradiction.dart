import '../data/keyword_database.dart';
import 'kap_classifier.dart';

class KapContradictionResult {
  final bool hasContradiction;
  final String? message;
  final int positiveSignals;
  final int negativeSignals;

  const KapContradictionResult({
    required this.hasContradiction,
    this.message,
    this.positiveSignals = 0,
    this.negativeSignals = 0,
  });
}

class KapContradictionDetector {
  const KapContradictionDetector();

  static const _positiveWords = [
    'imzalandı',
    'kazanıldı',
    'onaylandı',
    'tamamlandı',
    'artış',
    'büyüme',
    'rekor',
    'başarı',
    'kâr',
    'kar',
    'temettü',
    'geri alım',
  ];

  static const _negativeWords = [
    'iptal',
    'fesih',
    'zarar',
    'durduruldu',
    'iflas',
    'konkordato',
    'ceza',
    'mahkeme',
    'kayıp',
    'düşüş',
    'ertelendi',
    'gecikme',
    'olumsuz',
    'red',
  ];

  KapContradictionResult detect(
    String text,
    KapClassificationResult classification,
  ) {
    final normalized = text.toLowerCase();
    var pos = 0;
    var neg = 0;

    for (final w in _positiveWords) {
      if (normalized.contains(w)) pos++;
    }
    for (final w in _negativeWords) {
      if (normalized.contains(w)) neg++;
    }

    final effect = classification.effect;

    if (effect == KapEffect.positive && neg >= 2 && neg > pos) {
      return KapContradictionResult(
        hasContradiction: true,
        message:
            'Olumlu kategori seçildi ancak metinde iptal, ceza veya fesih gibi olumsuz ifadeler tespit edildi.',
        positiveSignals: pos,
        negativeSignals: neg,
      );
    }

    if (effect == KapEffect.negative && pos >= 2 && pos > neg) {
      return KapContradictionResult(
        hasContradiction: true,
        message:
            'Olumsuz kategori seçildi ancak metinde imza, onay veya kazanım gibi olumlu ifadeler tespit edildi.',
        positiveSignals: pos,
        negativeSignals: neg,
      );
    }

    if (effect == KapEffect.positive && neg >= 3) {
      return KapContradictionResult(
        hasContradiction: true,
        message:
            'Pozitif etki beklenirken metinde güçlü olumsuz sinyaller bulunuyor.',
        positiveSignals: pos,
        negativeSignals: neg,
      );
    }

    return KapContradictionResult(
      hasContradiction: false,
      positiveSignals: pos,
      negativeSignals: neg,
    );
  }
}
