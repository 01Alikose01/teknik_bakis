import 'package:flutter/material.dart';

/// AI veya yerel analiz metnini paragraflara bölerek gösteren widget.
///
/// Metin içindeki çift yeni satırları (`\n\n`) paragraf ayracı olarak kullanır.
/// Tek blok metin gelirse cümleleri 3'lü gruplara bölerek okunabilirlik sağlar.
class FormattedAnalysisText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const FormattedAnalysisText({
    super.key,
    required this.text,
    required this.style,
  });

  List<String> _paragraphs() {
    // 1) Çift yeni satırla (\n\n) gelen blokları ayır
    final blocks = text
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();

    // Birden fazla blok varsa direkt paragraf olarak kullan
    if (blocks.length > 1) return blocks;

    // 2) Tek bloksa cümlelere ayırıp 3'lü grupla
    final single = blocks.isNotEmpty ? blocks.first : text.trim();
    if (single.isEmpty) return [text.trim()];

    final sentences = single
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (sentences.length <= 3) return [single];

    final paragraphs = <String>[];
    for (var i = 0; i < sentences.length; i += 3) {
      final end = (i + 3 < sentences.length) ? i + 3 : sentences.length;
      paragraphs.add(sentences.sublist(i, end).join(' '));
    }
    return paragraphs;
  }

  @override
  Widget build(BuildContext context) {
    final paragraphs = _paragraphs();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          Text(paragraphs[i], style: style),
          if (i < paragraphs.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}
