import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../kap_ai/kap_ai_service.dart';
import '../kap_ai/models/kap_analysis.dart';
import '../kap_ai/data/keyword_database.dart';
import 'kap_ai_detail_screen.dart';

// ─────────────────────────────────────────────
// Model: KAP haberi + AI analizi birlikte
// ─────────────────────────────────────────────

class KapAiItem {
  final String title;
  final String rawText;
  final String source;
  final String time;
  final KapAnalysis analysis;

  const KapAiItem({
    required this.title,
    required this.rawText,
    required this.source,
    required this.time,
    required this.analysis,
  });
}

// ─────────────────────────────────────────────
// Ekran — NewsScreen'in KAP AI sekmesi içinde
// kullanılır (kendi Scaffold'u YOK)
// ─────────────────────────────────────────────

class KapAiListScreen extends StatefulWidget {
  const KapAiListScreen({super.key});

  @override
  State<KapAiListScreen> createState() => _KapAiListScreenState();
}

class _KapAiListScreenState extends State<KapAiListScreen>
    with AutomaticKeepAliveClientMixin {
  final _service = KapAiService();
  List<KapAiItem> _items = [];
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true; // sekme değişince yeniden yüklenmez

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });

    try {
      final resp = await http
          .get(
            Uri.parse(
                'https://www.kap.org.tr/tr/api/disclosures?type=ozel&orderBy=&orderDir=&pageSize=30&pageIndex=0'),
            headers: {'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is List && data.isNotEmpty) {
          final items = <KapAiItem>[];
          for (final d in data.take(30)) {
            final title = d['title']?.toString() ??
                d['companyName']?.toString() ??
                'KAP Bildirimi';
            final subject = d['subject']?.toString() ?? '';
            final source = d['companyCode']?.toString() ?? 'KAP';
            final time = _parseDate(
                d['publishDate']?.toString() ??
                    d['releaseDate']?.toString() ??
                    '');
            // Analiz için title + subject birleştir
            final rawText = '$title\n$subject';
            final analysis = _service.analyze(rawText);
            items.add(KapAiItem(
              title: title,
              rawText: rawText,
              source: source,
              time: time,
              analysis: analysis,
            ));
          }
          if (mounted) {
            setState(() { _items = items; _loading = false; });
          }
          return;
        }
      }
    } catch (_) {}

    // Fallback: demo veriler
    _loadFallback();
  }

  void _loadFallback() {
    final demos = [
      {
        'source': 'THYAO',
        'title': 'THYAO — Yeni İş İlişkisi',
        'text':
            'THYAO\nTürk Hava Yolları ile Lufthansa arasında 500 milyon TL tutarında yeni iş ilişkisi kapsamında sözleşme imzalandı.',
      },
      {
        'source': 'GARAN',
        'title': 'GARAN — Temettü Duyurusu',
        'text':
            'GARAN\nGaranti BBVA genel kurul kararı ile hisse başına 2.50 TL nakit kar payı dağıtımı yapılacağını duyurdu.',
      },
      {
        'source': 'AKBNK',
        'title': 'AKBNK — Sermaye Artırımı',
        'text':
            'AKBNK\nAkbank bedelli sermaye artırımı kararı açıkladı. Rüçhan hakkı kullanım fiyatı 18 TL olarak belirlendi.',
      },
      {
        'source': 'EREGL',
        'title': 'EREGL — İhale Kazanımı',
        'text':
            'EREGL\nEreğli Demir Çelik, 1.2 milyar TL tutarında kamu ihalesi kazandığını duyurdu.',
      },
      {
        'source': 'BIMAS',
        'title': 'BIMAS — Yatırım Planı',
        'text':
            'BIMAS\nBİM Mağazalar 200 milyon TL yatırım kararı açıkladı. Yeni dönemde 150 mağaza açılış hedefi belirlendi.',
      },
      {
        'source': 'KCHOL',
        'title': 'KCHOL — Pay Geri Alımı',
        'text':
            'KCHOL\nKoç Holding pay geri alım programı kapsamında 300 milyon TL tutarında hisse geri alımı kararı aldı.',
      },
      {
        'source': 'TUPRS',
        'title': 'TUPRS — İdari Ceza',
        'text':
            'TUPRS\nTüpraş hakkında EPDK tarafından 45 milyon TL idari para cezası uygulandı.',
      },
      {
        'source': 'SISE',
        'title': 'SISE — Genel Kurul',
        'text':
            'SISE\nŞişe Cam olağan genel kurul toplantısı 15 Ağustos 2026 tarihinde yapılacaktır.',
      },
    ];

    final now = DateTime.now();
    final timeStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    if (mounted) {
      setState(() {
        _items = demos.map((d) {
          final analysis = _service.analyze(d['text']!);
          return KapAiItem(
            title: d['title']!,
            rawText: d['text']!,
            source: d['source']!,
            time: timeStr,
            analysis: analysis,
          );
        }).toList();
        _loading = false;
      });
    }
  }

  String _parseDate(String raw) {
    if (raw.isEmpty) {
      final n = DateTime.now();
      return '${n.day.toString().padLeft(2, '0')}.${n.month.toString().padLeft(2, '0')}.${n.year} '
          '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
    }
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.length > 16 ? raw.substring(0, 16) : raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF34C759)),
            SizedBox(height: 12),
            Text('KAP haberleri analiz ediliyor...',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.grey, size: 40),
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _load,
              child: const Text('Tekrar Dene',
                  style: TextStyle(color: Color(0xFF34C759))),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF34C759),
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _items.length,
        itemBuilder: (_, i) => _KapAiCard(item: _items[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// KAP AI Liste Kartı
// ─────────────────────────────────────────────

class _KapAiCard extends StatelessWidget {
  final KapAiItem item;
  const _KapAiCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final effect = item.analysis.effect;
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
            // Üst bar: renk şeridi + hisse + skor
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
                  // Hisse etiketi
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
                  // Kategori
                  Expanded(
                    child: Text(item.analysis.categoryName,
                        style: TextStyle(
                            color: effectColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                  // Etki skoru
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
                ],
              ),
            ),

            // İçerik
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Text(item.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),

                  // AI Özeti
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📢 ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Text(item.analysis.summary,
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Alt satır: yıldız + etki + saat
                  Row(
                    children: [
                      // Yıldızlar
                      _Stars(count: item.analysis.stars),
                      const SizedBox(width: 8),
                      // Etki rozeti
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

// ─────────────────────────────────────────────
// Yıldız widget
// ─────────────────────────────────────────────

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
