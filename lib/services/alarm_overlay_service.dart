import 'dart:async';
import 'package:flutter/material.dart';

/// Uygulama içi alarm overlay servisi.
///
/// Kullanıcı bildirim iznini kapatmışsa sistem push bildirimi gönderilemez.
/// Bu servis, push yerine ekranın ortasına animasyonlu bir banner gösterir.
///
/// Kullanım:
///   AlarmOverlayService.show(
///     context: context,
///     symbol: 'THYAO',
///     price: 234.50,
///     isAbove: true,   // true = Satış Alarmı, false = Alış Alarmı
///   );
class AlarmOverlayService {
  AlarmOverlayService._();

  static OverlayEntry? _currentEntry;
  static Timer? _autoHideTimer;

  /// Overlay'i göster. Zaten açık bir overlay varsa önce kapatır.
  static void show({
    required BuildContext context,
    required String symbol,
    required double price,
    required bool isAbove, // true = fiyat çıktı (Satış Alarmı), false = fiyat düştü (Alış Alarmı)
    Duration duration = const Duration(seconds: 5),
  }) {
    // Mevcut varsa temizle
    dismiss();

    final overlay = Overlay.of(context, rootOverlay: true);

    _currentEntry = OverlayEntry(
      builder: (_) => _AlarmOverlayBanner(
        symbol: symbol,
        price: price,
        isAbove: isAbove,
        onDismiss: dismiss,
      ),
    );

    overlay.insert(_currentEntry!);

    // Otomatik kapat
    _autoHideTimer = Timer(duration, dismiss);
  }

  /// Halka arz overlay'i göster.
  static void showIpo({
    required BuildContext context,
    required String title,
    required String body,
    Duration duration = const Duration(seconds: 5),
  }) {
    dismiss();

    final overlay = Overlay.of(context, rootOverlay: true);

    _currentEntry = OverlayEntry(
      builder: (_) => _IpoOverlayBanner(
        title: title,
        body: body,
        onDismiss: dismiss,
      ),
    );

    overlay.insert(_currentEntry!);
    _autoHideTimer = Timer(duration, dismiss);
  }

  /// Overlay'i kapat ve kaynakları temizle.
  static void dismiss() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner Widget
// ─────────────────────────────────────────────────────────────────────────────

class _AlarmOverlayBanner extends StatefulWidget {
  final String symbol;
  final double price;
  final bool isAbove;
  final VoidCallback onDismiss;

  const _AlarmOverlayBanner({
    required this.symbol,
    required this.price,
    required this.isAbove,
    required this.onDismiss,
  });

  @override
  State<_AlarmOverlayBanner> createState() => _AlarmOverlayBannerState();
}

class _AlarmOverlayBannerState extends State<_AlarmOverlayBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _scaleAnim = Tween<double>(begin: 0.84, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.55)),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    final isBuy = !widget.isAbove; // Alış Alarmı = fiyat düştü
    final accent = isBuy ? const Color(0xFF34C759) : const Color(0xFFFF3B30);
    final accentSoft = isBuy ? const Color(0xFF30D158) : const Color(0xFFFF453A);

    // Gündüz/Gece kart renkleri — alarm için doygun, net renkler
    final cardBg = isDark
        ? (isBuy ? const Color(0xFF0D2B1A) : const Color(0xFF2B0D0D))
        : (isBuy ? const Color(0xFFF0FFF4) : const Color(0xFFFFF0F0));
    final topGradStart = isDark
        ? (isBuy ? const Color(0xFF0A2416) : const Color(0xFF240A0A))
        : (isBuy ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E4));
    final topGradEnd = isDark
        ? (isBuy ? const Color(0xFF102E1E) : const Color(0xFF2E1010))
        : (isBuy ? const Color(0xFFBBF7D0) : const Color(0xFFFFCDD2));

    final priceTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final bodyTextColor = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : const Color(0xFF3A3A3C);
    final captionColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFFAEAEB2);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : accent.withValues(alpha: 0.15);
    final infoBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.7);
    final infoBorder = isDark
        ? accent.withValues(alpha: 0.2)
        : accent.withValues(alpha: 0.25);

    final typeLabel = isBuy ? 'Alış Alarmı' : 'Satış Alarmı';
    final typeEmoji = isBuy ? '📈' : '📉';
    final arrowIcon = isBuy ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    final actionText = isBuy
        ? 'Hedef fiyata düştü'
        : 'Hedef fiyata ulaştı';

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _handleDismiss,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // ── Dim overlay ───────────────────────────────────────────────
            Container(
              color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.35),
            ),

            // ── Kart ─────────────────────────────────────────────────────
            Center(
              child: ScaleTransition(
                scale: _scaleAnim,
                child: FadeTransition(
                  opacity: _opacityAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(
                                alpha: isDark ? 0.28 : 0.18),
                            blurRadius: 48,
                            spreadRadius: 4,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.5 : 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Renkli üst şerit ──────────────────────
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [topGradStart, topGradEnd],
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Kapat butonu
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: GestureDetector(
                                      onTap: _handleDismiss,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: (isDark
                                                  ? Colors.white
                                                  : Colors.black)
                                              .withValues(alpha: 0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 15,
                                          color: (isDark
                                                  ? Colors.white
                                                  : Colors.black)
                                              .withValues(alpha: 0.45),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // İkon + ok — alarm kimliği
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: 68,
                                        height: 68,
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: accent.withValues(alpha: 0.35),
                                            width: 2,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            typeEmoji,
                                            style: const TextStyle(fontSize: 30),
                                          ),
                                        ),
                                      ),
                                      // Küçük ok rozeti
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: accent,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: cardBg,
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            arrowIcon,
                                            size: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Etiket
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Text(
                                      typeLabel,
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ── Gövde ─────────────────────────────────
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 16, 20, 20),
                              child: Column(
                                children: [
                                  // Sembol + eylem satırı
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: infoBg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: infoBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        // Sembol rozeti
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: accent.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            widget.symbol,
                                            style: TextStyle(
                                              color: accentSoft,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            actionText,
                                            style: TextStyle(
                                              color: bodyTextColor,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // Ayırıcı
                                  Divider(color: dividerColor, height: 1),

                                  const SizedBox(height: 12),

                                  // Fiyat — ana odak noktası
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        widget.price.toStringAsFixed(2),
                                        style: TextStyle(
                                          color: priceTextColor,
                                          fontSize: 36,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -1,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '₺',
                                        style: TextStyle(
                                          color: accent,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 14),

                                  // Hint
                                  Text(
                                    'Devam etmek için ekrana dokun',
                                    style: TextStyle(
                                      color: captionColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Halka Arz Overlay Banner
// ─────────────────────────────────────────────────────────────────────────────

class _IpoOverlayBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onDismiss;

  const _IpoOverlayBanner({
    required this.title,
    required this.body,
    required this.onDismiss,
  });

  @override
  State<_IpoOverlayBanner> createState() => _IpoOverlayBannerState();
}

class _IpoOverlayBannerState extends State<_IpoOverlayBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _scaleAnim = Tween<double>(begin: 0.84, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.55)),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    // Tema bilgisini mediaQuery üzerinden al (overlay context'inde theme çalışır)
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    const accentGreen = Color(0xFF34C759);
    final cardBg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final topGradStart = isDark ? const Color(0xFF0D3320) : const Color(0xFFECFDF3);
    final topGradEnd = isDark ? const Color(0xFF143D28) : const Color(0xFFD1FAE5);
    final bodyTextColor = isDark
        ? Colors.white.withValues(alpha: 0.8)
        : const Color(0xFF3A3A3C);
    final captionColor = isDark
        ? Colors.white.withValues(alpha: 0.38)
        : const Color(0xFFAEAEB2);
    final infoBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFF5F5F5);
    final infoBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE5E5EA);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _handleDismiss,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // ── Dim overlay ───────────────────────────────────────────────
            Container(
              color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.4),
            ),

            // ── Kart ─────────────────────────────────────────────────────
            Center(
              child: ScaleTransition(
                scale: _scaleAnim,
                child: FadeTransition(
                  opacity: _opacityAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: accentGreen.withValues(
                                alpha: isDark ? 0.22 : 0.12),
                            blurRadius: 48,
                            spreadRadius: 4,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.5 : 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Renkli üst alan ───────────────────────
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.fromLTRB(20, 20, 20, 20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [topGradStart, topGradEnd],
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Kapat butonu
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: GestureDetector(
                                      onTap: _handleDismiss,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: (isDark
                                                  ? Colors.white
                                                  : Colors.black)
                                              .withValues(alpha: 0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 15,
                                          color: (isDark
                                                  ? Colors.white
                                                  : Colors.black)
                                              .withValues(alpha: 0.45),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Emoji
                                  const Text(
                                    '🎉',
                                    style: TextStyle(fontSize: 48),
                                  ),
                                  const SizedBox(height: 10),

                                  // Başlık
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      color: accentGreen,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            // ── Gövde ─────────────────────────────────
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 16, 20, 20),
                              child: Column(
                                children: [
                                  // Bilgi kutusu
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: infoBg,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: infoBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text(
                                          '⭐',
                                          style: TextStyle(fontSize: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            widget.body,
                                            style: TextStyle(
                                              color: bodyTextColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // Hint
                                  Text(
                                    'Devam etmek için ekrana dokun',
                                    style: TextStyle(
                                      color: captionColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
