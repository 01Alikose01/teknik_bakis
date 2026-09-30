import 'package:flutter/material.dart';
import '../kap_ai/models/kap_analysis.dart';
import '../kap_ai/data/keyword_database.dart';
import '../widgets/formatted_analysis_text.dart';
import 'kap_ai_list_screen.dart';

// ─────────────────────────────────────────────
// KAP AI Detay Ekranı — Profesyonel Finansal Analiz
// ─────────────────────────────────────────────

class KapAiDetailScreen extends StatelessWidget {
  final KapAiItem item;
  const KapAiDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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

    final displayCompany = analysis.companyName.isNotEmpty
        ? analysis.companyName
        : item.source;

    return Scaffold(
      backgroundColor:
          isDark ? theme.colorScheme.surface : const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor:
            isDark ? theme.colorScheme.surface : const Color(0xFFF2F2F7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: isDark ? theme.colorScheme.onSurface : Colors.black87,
              size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1C3A5E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(item.source,
                  style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('KAP AI Araştırma Raporu',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── 1. Başlık & Şirket Kartı ──
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayCompany,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: theme.colorScheme.onSurface)),
                          const SizedBox(height: 4),
                          Text(item.title,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.85),
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: effectColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: effectColor.withOpacity(0.3)),
                      ),
                      child: Text(analysis.categoryName,
                          style: TextStyle(
                              color: effectColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: effectColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$effectEmoji $effectLabel (${analysis.effectScore})',
                        style: TextStyle(
                            color: effectColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 11),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time,
                            size: 12,
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.65)),
                        const SizedBox(width: 4),
                        Text(item.time,
                            style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.65),
                                fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── 2. AI Yönetici Özeti ──
          _SectionCard(
            emoji: '📢',
            title: 'AI Yönetici Özeti',
            child: FormattedAnalysisText(
              text: analysis.executiveSummary.isNotEmpty
                  ? analysis.executiveSummary
                  : analysis.summary,
              style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                  height: 1.6),
            ),
          ),

          // ── 3. Şirket & Finansal Etki Analizi ──
          if (analysis.financialImpact.isNotEmpty)
            _SectionCard(
              emoji: '🏢',
              title: 'Finansal & Bilanço Etkisi',
              child: FormattedAnalysisText(
                text: analysis.financialImpact,
                style: TextStyle(
                    fontSize: 13.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.92),
                    height: 1.6),
              ),
            ),

          // ── 4. Piyasa & Fiyatlama Beklentisi ──
          if (analysis.marketOutlook.isNotEmpty)
            _SectionCard(
              emoji: '📈',
              title: 'Piyasa & Fiyatlama Dinamikleri',
              child: FormattedAnalysisText(
                text: analysis.marketOutlook,
                style: TextStyle(
                    fontSize: 13.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.92),
                    height: 1.6),
              ),
            ),

          // ── 5. Küçük Yatırımcı İçin Stratejik Aksiyon Rehberi ──
          _SectionCard(
            emoji: '👤',
            title: 'Küçük Yatırımcı İçin Aksiyon Rehberi',
            child: FormattedAnalysisText(
              text: analysis.retailInvestorGuidance.isNotEmpty
                  ? analysis.retailInvestorGuidance
                  : _retailInvestorNote(analysis),
              style: TextStyle(
                  fontSize: 13.5,
                  color: theme.colorScheme.onSurface.withOpacity(0.92),
                  height: 1.6),
            ),
          ),

          // ── 6. Takip Edilecek Kritik Katalizörler ──
          if (analysis.watchItems.isNotEmpty)
            _SectionCard(
              emoji: '🎯',
              title: 'Takip Edilecek Kritik Katalizörler',
              child: Column(
                children: analysis.watchItems
                    .map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('→  ',
                                  style: TextStyle(
                                      color: Color(0xFF34C759),
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Text(w,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.88),
                                        height: 1.4)),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),

          // ── 7. Çıkarılan Veriler ──
          if (analysis.entities.hasAny)
            _SectionCard(
              emoji: '🔍',
              title: 'Çıkarılan Kilit Veriler',
              child: Column(
                children: [
                  if (analysis.entities.amount != null)
                    _InfoRow(
                      label: 'Tutar / Değer',
                      value: analysis.entities.amount!,
                    ),
                  if (analysis.entities.shareCount != null) ...[
                    const Divider(height: 12),
                    _InfoRow(
                      label: 'Pay / Lot Adedi',
                      value: analysis.entities.shareCount!,
                    ),
                  ],
                  if (analysis.entities.dividendPerShare != null) ...[
                    const Divider(height: 12),
                    _InfoRow(
                      label: 'Hisse Başı Temettü',
                      value: analysis.entities.dividendPerShare!,
                    ),
                  ],
                  if (analysis.entities.capitalRatio != null) ...[
                    const Divider(height: 12),
                    _InfoRow(
                      label: 'Sermaye Oranı',
                      value: analysis.entities.capitalRatio!,
                    ),
                  ],
                  if (analysis.entities.projectScope != null) ...[
                    const Divider(height: 12),
                    _InfoRow(
                      label: 'Proje / Konu',
                      value: analysis.entities.projectScope!,
                    ),
                  ],
                  if (analysis.entities.dates.isNotEmpty) ...[
                    const Divider(height: 12),
                    _InfoRow(
                      label: 'Tarih',
                      value: analysis.entities.dates.join(', '),
                    ),
                  ],
                  if (analysis.entities.percentages.isNotEmpty &&
                      analysis.entities.capitalRatio == null) ...[
                    const Divider(height: 12),
                    _InfoRow(
                      label: 'Oran',
                      value: analysis.entities.percentages.join(', '),
                    ),
                  ],
                  if (analysis.entities.institution != null) ...[
                    const Divider(height: 12),
                    _InfoRow(
                      label: 'Karşı Kurum',
                      value: analysis.entities.institution!,
                    ),
                  ],
                ],
              ),
            ),

          // ── 8. Riskler ve Belirsizlikler ──
          _SectionCard(
            emoji: '⚠️',
            title: 'Riskler ve Belirsizlikler',
            child: analysis.risks.isEmpty
                ? Text('Belirgin bir risk unsuru tespit edilmedi.',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.65),
                        fontSize: 13))
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
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.88),
                                            height: 1.4)),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
          ),

          // ── 9. Çelişki Tespiti ──
          if (analysis.hasContradiction)
            _SectionCard(
              emoji: '⚡',
              title: 'Çelişki Sinyali',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFFFF9500).withOpacity(0.3)),
                ),
                child: Text(
                  analysis.contradiction.message ??
                      'Metin içinde çelişkili sinyaller var.',
                  style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                      height: 1.4),
                ),
              ),
            ),

          // ── 10. AI Puanlama ve Güven Metrikleri ──
          _SectionCard(
            emoji: '📊',
            title: 'AI Değerlendirme & Güven Metrikleri',
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
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Etki Skoru: ${analysis.score}/100',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface)),
                              Text('Güven: %${analysis.confidence}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.65))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: analysis.score / 100,
                              backgroundColor: isDark
                                  ? theme.colorScheme.surfaceContainerHighest
                                  : Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(effectColor),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Önem Seviyesi:',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.65))),
                    const SizedBox(width: 8),
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < analysis.stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: i < analysis.stars
                            ? const Color(0xFFFFCC00)
                            : Colors.grey[300],
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: effectColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${analysis.confidenceLabel} Güven',
                          style: TextStyle(
                              color: effectColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 11. Orijinal KAP Metni ──
          _SectionCard(
            emoji: '📄',
            title: 'Orijinal KAP Metni',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainerHighest
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? theme.colorScheme.outlineVariant
                      : Colors.grey[200]!,
                ),
              ),
              child: Text(
                item.rawText.isEmpty ? 'Metin bulunamadı.' : item.rawText,
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.78),
                    height: 1.6,
                    fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _retailInvestorNote(KapAnalysis analysis) {
    switch (analysis.effect) {
      case KapEffect.positive:
        return 'Bu bildirim hisse için olumlu bir katalizördür. Kısa vadeli fiyat sıçramalarında fomo ile alım yapmak yerine hacimli geri çekilmeleri izlemek ve iz süren stop kullanmak önerilir.';
      case KapEffect.negative:
        return 'Bu bildirim hisse üzerinde kısa süreli satış baskısı oluşturabilir. Stop-loss seviyelerinizi gözden geçirmeniz ve haberin bilanço hasarını değerlendirmeniz önerilir.';
      case KapEffect.neutral:
        return 'Bu bildirim hisse fiyatı üzerinde doğrudan belirgin bir dalgalanma yaratması beklenmeyen rutin bir bilgilendirmedir.';
    }
  }
}

// ─────────────────────────────────────────────
// Yardımcı Widget'lar
// ─────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.16 : 0.04),
              blurRadius: 6)
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.16 : 0.04),
              blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: theme.colorScheme.onSurface)),
              ),
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
              style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                  fontSize: 12)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 12,
                  color: valueColor ??
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
