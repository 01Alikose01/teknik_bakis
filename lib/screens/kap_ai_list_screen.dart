import 'package:flutter/material.dart';
import '../models/kap_news_item.dart';
import '../kap_ai/kap_ai_service.dart';
import '../kap_ai/models/kap_analysis.dart';
import '../kap_ai/data/keyword_database.dart';
import 'kap_ai_detail_screen.dart';

class KapAiItem {
  final String title;
  final String rawText;
  final String source;
  final String time;
  final String url;
  final KapAnalysis analysis;

  const KapAiItem({
    required this.title,
    required this.rawText,
    required this.source,
    required this.time,
    required this.url,
    required this.analysis,
  });

  factory KapAiItem.fromKapNews(KapNewsItem news, KapAnalysis analysis) {
    return KapAiItem(
      title: news.cleanTitle,
      rawText: news.analysisText,
      source: news.source,
      time: news.time,
      url: news.url,
      analysis: analysis,
    );
  }
}

class KapAiListScreen extends StatefulWidget {
  final List<KapNewsItem> kapItems;
  final bool loading;
  final Future<void> Function() onRefresh;

  const KapAiListScreen({
    super.key,
    required this.kapItems,
    required this.loading,
    required this.onRefresh,
  });

  @override
  State<KapAiListScreen> createState() => _KapAiListScreenState();
}

class _KapAiListScreenState extends State<KapAiListScreen>
    with AutomaticKeepAliveClientMixin {
  final _service = KapAiService();
  List<KapAiItem> _items = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _analyze(widget.kapItems);
  }

  @override
  void didUpdateWidget(covariant KapAiListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.kapItems != oldWidget.kapItems) {
      setState(() => _analyze(widget.kapItems));
    }
  }

  void _analyze(List<KapNewsItem> news) {
    _items = news.map((item) {
      final analysis =
          _service.analyze(item.analysisText, symbol: item.source);
      return KapAiItem.fromKapNews(item, analysis);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.loading && _items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF34C759)),
            SizedBox(height: 12),
            Text('KAP bildirimleri analiz ediliyor...',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.psychology_outlined,
                color: Colors.grey, size: 40),
            const SizedBox(height: 8),
            const Text('Henüz KAP bildirimi yok',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onRefresh,
              child: const Text('Yenile',
                  style: TextStyle(color: Color(0xFF34C759))),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF34C759),
      onRefresh: widget.onRefresh,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 13, color: Color(0xFF34C759)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${_items.length} bildirim KAP AI ile analiz edildi',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _items.length,
              itemBuilder: (_, i) => _KapAiCard(item: _items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _KapAiCard extends StatelessWidget {
  final KapAiItem item;
  const _KapAiCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effect = item.analysis.effect;
    final effectColor = effect == KapEffect.positive
        ? const Color(0xFF34C759)
        : effect == KapEffect.negative
            ? const Color(0xFFFF3B30)
            : const Color(0xFFFF9500);
    final cardColor = theme.brightness == Brightness.dark ? Colors.black : Colors.white;
    final textColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black87;
    final mutedTextColor = theme.brightness == Brightness.dark ? Colors.white70 : Colors.black54;
    final subtleBg = theme.brightness == Brightness.dark ? Colors.white10 : Colors.grey[100];

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

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KapAiDetailScreen(item: item),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: effectColor.withValues(alpha: 0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C3A5E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(item.source,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.analysis.categoryName,
                        style: TextStyle(
                            color: effectColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: effectColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(item.analysis.effectScore,
                        style: TextStyle(
                            color: effectColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: subtleBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '%${item.analysis.confidence}',
                      style: TextStyle(
                        color: item.analysis.confidence >= 50
                            ? mutedTextColor
                            : const Color(0xFFFF3B30),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: textColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (item.analysis.hasContradiction) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 13, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Text('Çelişkili sinyal',
                            style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📢 ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Text(item.analysis.summary,
                            style: TextStyle(
                                color: mutedTextColor, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _Stars(count: item.analysis.stars),
                      const SizedBox(width: 8),
                      Text('$effectEmoji $effectLabel',
                          style: TextStyle(
                              color: effectColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      const Icon(Icons.access_time,
                          size: 11, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text(item.time,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          size: 16, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final int count;
  const _Stars({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < count ? Icons.star_rounded : Icons.star_outline_rounded,
          color: i < count ? const Color(0xFFFFCC00) : Colors.grey[300],
          size: 14,
        ),
      ),
    );
  }
}
