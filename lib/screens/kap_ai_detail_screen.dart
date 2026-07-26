import 'package:flutter/material.dart';
import '../kap_ai/models/kap_analysis.dart';
import '../kap_ai/data/keyword_database.dart';
import 'kap_ai_list_screen.dart';

// ─────────────────────────────────────────────
// KAP AI Detay Ekranı
// ─────────────────────────────────────────────

class KapAiDetailScreen extends StatelessWidget {
  final KapAiItem item;
  const KapAiDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final analysis = item.analysis;
    final effect = analysis.effect;

    final effectColor = effect == KapEffect.positive
        ? const Color(0xFF34C759)
        : effect == KapEffect.negative
            ? const Color(0xFFFF3B30)
            : const Color(0xFFFF9500);

    final effectEmoji = effect == KapEffect.positive
        ? '🟢'
        : effect == KapEffect.negative
            ? '🔴'
            : '🟠';

    final effectLabel = effect == KapEffect.positive
        ? 'Pozitif'
        : effect == KapEffect.negative
            ? 'Negatif'
            : 'Nötr';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black87, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1C3A5E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(item.source,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('KAP AI Analizi',
                  style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Başlık kartı ──
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(item.time,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── AI Özeti ──
          _SectionCard(
            emoji: '📢',
            title: 'AI Özeti',
            child: Text(analysis.summary,
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5)),
          ),

          // ── AI Güveni ──
          _SectionCard(
            emoji: '🎯',
            title: 'AI Güveni',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '%${analysis.confidence}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: analysis.confidence >= 80
                            ? const Color(0xFF34C759)
                            : analysis.confidence >= 50
                                ? const Color(0xFFFF9500)
                                : const Color(0xFFFF3B30),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (analysis.confidence >= 80
                                ? const Color(0xFF34C759)
                                : analysis.confidence >= 50
                                    ? const Color(0xFFFF9500)
                                    : const Color(0xFFFF3B30))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(analysis.confidenceLabel,
                          style: TextStyle(
                              color: analysis.confidence >= 80
                                  ? const Color(0xFF34C759)
                                  : analysis.confidence >= 50
                                      ? const Color(0xFFFF9500)
                                      : const Color(0xFFFF3B30),
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: analysis.confidence / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(
                      analysis.confidence >= 80
                          ? const Color(0xFF34C759)
                          : analysis.confidence >= 50
                              ? const Color(0xFFFF9500)
                              : const Color(0xFFFF3B30),
                    ),
                    minHeight: 6,
                  ),
                ),
                if (analysis.confidence < 50) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Sınıflandırma belirsiz — orijinal KAP metnini kontrol edin.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),

          // ── Çelişki Uyarısı ──
          if (analysis.hasContradiction)
            _SectionCard(
              emoji: '⚡',
              title: 'Çelişki Tespiti',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFFF9500).withValues(alpha: 0.3)),
                ),
                child: Text(
                  analysis.contradiction.message ?? 'Metin içinde çelişkili sinyaller var.',
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black87, height: 1.4),
                ),
              ),
            ),

          // ── Çıkarılan Veriler ──
          if (analysis.entities.hasAny)
            _SectionCard(
              emoji: '🔍',
              title: 'Çıkarılan Veriler',
              child: Column(
                children: [
                  if (analysis.entities.amount != null)
                    _InfoRow(
                      label: 'Tutar',
                      value: analysis.entities.amount!,
                    ),
                  if (analysis.entities.dates.isNotEmpty) ...[
                    const Divider(height: 12),
                    _InfoRow(
                      label: 'Tarih',
                      value: analysis.entities.dates.join(', '),
                    ),
                  ],
                  if (analysis.entities.percentages.isNotEmpty) ...[
                    const Divider(height: 12),
                    _InfoRow(
                      label: 'Oran',
                      value: analysis.entities.percentages.join(', '),
                    ),
                  ],
                  if (analysis.entities.symbols.isNotEmpty) ...[
                    const Divider(height: 12),
                    _InfoRow(
                      label: 'Hisse',
                      value: analysis.entities.symbols.join(', '),
                    ),
                  ],
                  if (analysis.entities.institution != null) ...[
                    const Divider(height: 12),
                    _InfoRow(
                      label: 'Kurum',
                      value: analysis.entities.institution!,
                    ),
                  ],
                ],
              ),
            ),

          // ── Haber Türü ──
          _SectionCard(
            emoji: '🏷',
            title: 'Haber Türü',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: effectColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: effectColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(analysis.categoryName,
                          style: TextStyle(
                              color: effectColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ],
                ),
                if (analysis.secondaryCategories.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Ek kategoriler',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: analysis.secondaryCategories
                        .map((c) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Text(c.categoryName,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.black54)),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),

          // ── Etki Analizi ──
          _SectionCard(
            emoji: '📈',
            title: 'Etki Analizi',
            child: Column(
              children: [
                _InfoRow(
                  label: 'Yön',
                  value: '$effectEmoji $effectLabel',
                  valueColor: effectColor,
                ),
                const Divider(height: 16),
                _InfoRow(
                  label: 'Eşleşen Anahtar Kelimeler',
                  value: analysis.matchedKeywords.isEmpty
                      ? 'Tespit edilemedi'
                      : analysis.matchedKeywords.join(', '),
                  valueColor: Colors.black54,
                ),
              ],
            ),
          ),

          // ── Etki Skoru ──
          _SectionCard(
            emoji: '📊',
            title: 'Etki Skoru',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      analysis.effectScore,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: effectColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: analysis.score / 100,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(effectColor),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${analysis.score} / 100',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Önem Derecesi ──
          _SectionCard(
            emoji: '⭐',
            title: 'Önem Derecesi',
            child: Row(
              children: [
                ...List.generate(
                  5,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      i < analysis.stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: i < analysis.stars
                          ? const Color(0xFFFFCC00)
                          : Colors.grey[300],
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${analysis.stars} / 5',
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          // ── Küçük Yatırımcı İçin ──
          _SectionCard(
            emoji: '👤',
            title: 'Küçük Yatırımcı İçin',
            child: Text(
              _retailInvestorNote(analysis),
              style: const TextStyle(
                  fontSize: 14, color: Colors.black87, height: 1.5),
            ),
          ),

          // ── Riskler ──
          _SectionCard(
            emoji: '⚠',
            title: 'Riskler',
            child: analysis.risks.isEmpty
                ? const Text('Risk tespit edilmedi.',
                    style: TextStyle(color: Colors.grey, fontSize: 13))
                : Column(
                    children: analysis.risks
                        .map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('•  ',
                                      style: TextStyle(
                                          color: Color(0xFFFF9500),
                                          fontSize: 16)),
                                  Expanded(
                                    child: Text(r,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black87,
                                            height: 1.4)),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
          ),

          // ── Yön Rozeti ──
          _SectionCard(
            emoji: effectEmoji,
            title: 'Genel Değerlendirme',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: effectColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: effectColor.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  Text(effectEmoji, style: const TextStyle(fontSize: 36)),
                  const SizedBox(height: 6),
                  Text(effectLabel,
                      style: TextStyle(
                          color: effectColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(
                    _effectDescription(effect),
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // ── Orijinal KAP Metni ──
          _SectionCard(
            emoji: '📄',
            title: 'Orijinal KAP Metni',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                item.rawText.isEmpty ? 'Metin bulunamadı.' : item.rawText,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.6,
                    fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Küçük yatırımcı notu üret
  String _retailInvestorNote(KapAnalysis analysis) {
    switch (analysis.effect) {
      case KapEffect.positive:
        return 'Bu haber hisse için olumlu bir gelişmedir. '
            'Kısa vadede yukarı yönlü hareket görülebilir. '
            'Ancak mevcut piyasa koşullarını ve teknik seviyeleri '
            'göz önünde bulundurarak karar vermeniz önerilir.';
      case KapEffect.negative:
        return 'Bu haber hisse için olumsuz bir gelişmedir. '
            'Kısa vadede satış baskısı oluşabilir. '
            'Varsa stop-loss seviyelerinizi kontrol etmeniz '
            've aceleci kararlardan kaçınmanız önerilir.';
      case KapEffect.neutral:
        return 'Bu haber hisse fiyatı üzerinde doğrudan '
            'bir etki oluşturması beklenmiyor. '
            'Uzun vadeli yatırımcılar için bilgilendirme '
            'niteliğindedir.';
    }
  }

  String _effectDescription(KapEffect effect) {
    switch (effect) {
      case KapEffect.positive:
        return 'Haber hisse senedi için olumlu sinyaller içeriyor.';
      case KapEffect.negative:
        return 'Haber hisse senedi üzerinde olumsuz baskı yaratabilir.';
      case KapEffect.neutral:
        return 'Haberin hisse fiyatı üzerinde belirgin bir etkisi beklenmez.';
    }
  }
}

// ─────────────────────────────────────────────
// Yardımcı widget'lar
// ─────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: child,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.emoji,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 12,
                  color: valueColor ?? Colors.black87,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
