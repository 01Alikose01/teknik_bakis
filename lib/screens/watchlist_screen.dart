import 'package:flutter/material.dart';
import '../models/asset_model.dart';
import '../models/portfolio_model.dart';
import '../services/portfolio_service.dart';
import '../services/stock_service.dart'; // kBistStocks de buradan export ediliyor
import '../services/notification_service.dart';
import '../services/subscription_service.dart';
import '../widgets/stock_quote_panel.dart';
import 'premium_gate_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<WatchlistItem> _items = [];
  Map<String, AssetModel> _assets = {};
  List<AlarmItem> _alarms = [];
  Map<String, List<AlarmItem>> _alarmMap = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    final watchlist = PortfolioService.getWatchlist();
    final alarms = PortfolioService.getAlarms();
    final alarmMap = <String, List<AlarmItem>>{};
    for (final alarm in alarms) {
      alarmMap.putIfAbsent(alarm.symbol, () => []).add(alarm);
    }

    setState(() {
      _items = watchlist;
      _alarms = alarms;
      _alarmMap = alarmMap;
      _loading = _items.isNotEmpty;
    });
    if (_items.isEmpty) return;

    for (final item in _items) {
      final asset = await StockService.fetchStock(item.symbol, period: '1mo');
      if (asset != null) {
        _checkAlertsForSymbol(item, asset.price);
        if (mounted) {
          setState(() => _assets[item.symbol] = asset);
        }
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _checkAlertsForSymbol(WatchlistItem item, double currentPrice) {
    final alarms = _alarmMap[item.symbol] ?? [];
    for (final alarm in alarms) {
      if (alarm.alertAbove && currentPrice >= alarm.alertPrice) {
        NotificationService.showPriceAlert(
          symbol: item.symbol,
          price: currentPrice,
          isAbove: true,
        );
      } else if (!alarm.alertAbove && currentPrice <= alarm.alertPrice) {
        NotificationService.showPriceAlert(
          symbol: item.symbol,
          price: currentPrice,
          isAbove: false,
        );
      }
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AddStockDialog(
        onAdd: (sym, name) async {
          await PortfolioService.addToWatchlist(
            WatchlistItem(symbol: sym, name: name),
          );
          _loadWatchlist();
        },
      ),
    );
  }

  void _showAlarmLimitSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🔔', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ücretsiz Alarm Limitine Ulaştınız',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ücretsiz planda en fazla ${SubscriptionService.freeAlarmLimit} fiyat alarmı kurabilirsiniz.\nSınırsız alarm için Premium\'a geçin.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PremiumGateScreen(
                        nextScreen: const WatchlistScreen(),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34C759),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '👑  Premium\'a Geç',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Vazgeç',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlertDialog(WatchlistItem item) {
    final existingAlarms = _alarms.length;
    if (!SubscriptionService.canCreateAlarm(existingAlarms)) {
      _showAlarmLimitSheet();
      return;
    }

    final priceCtrl = TextEditingController();
    bool above = true;
    final currentPrice = _assets[item.symbol]?.price ?? 0.0;

    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C3A5E),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  item.symbol,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Yeni Alarm Kur',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFFFF9500),
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Alarmın çalışması için telefon bildirim ayarlarından '
                        '"Teknik Bakış" uygulamasına izin verdiğinden emin ol.',
                        style: TextStyle(
                          color: Color(0xFFFF9500),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Alarm Türü',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setDialogState(() => above = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: !above
                              ? const Color(0xFF34C759).withValues(alpha: 0.12)
                              : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !above
                                ? const Color(0xFF34C759)
                                : Colors.grey.shade300,
                            width: !above ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.arrow_downward_rounded,
                              color: !above
                                  ? const Color(0xFF34C759)
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Alış Alarmı',
                              style: TextStyle(
                                color: !above
                                    ? const Color(0xFF34C759)
                                    : Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Fiyat düşünce',
                              style: TextStyle(
                                color: !above
                                    ? const Color(
                                        0xFF34C759,
                                      ).withValues(alpha: 0.7)
                                    : Colors.grey[400],
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setDialogState(() => above = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: above
                              ? const Color(0xFFFF3B30).withValues(alpha: 0.10)
                              : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: above
                                ? const Color(0xFFFF3B30)
                                : Colors.grey.shade300,
                            width: above ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.arrow_upward_rounded,
                              color: above
                                  ? const Color(0xFFFF3B30)
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Satış Alarmı',
                              style: TextStyle(
                                color: above
                                    ? const Color(0xFFFF3B30)
                                    : Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Fiyat yükselince',
                              style: TextStyle(
                                color: above
                                    ? const Color(
                                        0xFFFF3B30,
                                      ).withValues(alpha: 0.7)
                                    : Colors.grey[400],
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Anlık Fiyat:',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${currentPrice.toStringAsFixed(2)} ₺',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Alarm Fiyatı (₺)',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: priceCtrl,
                style: TextStyle(color: theme.colorScheme.onSurface),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: above
                      ? 'Hedef satış fiyatı gir...'
                      : 'Hedef alış fiyatı gir...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  prefixIcon: Icon(
                    above
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: above
                        ? const Color(0xFFFF3B30)
                        : const Color(0xFF34C759),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                above
                    ? '📢 Fiyat girilen seviyeye ulaşırsa veya geçerse bildirim alırsın.'
                    : '📢 Fiyat girilen seviyeye düşerse veya altına inerse bildirim alırsın.',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'İptal',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: above
                    ? const Color(0xFFFF3B30)
                    : const Color(0xFF34C759),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final price = double.tryParse(
                  priceCtrl.text.replaceAll(',', '.'),
                );
                if (price == null || price <= 0) return;
                if (!SubscriptionService.canCreateAlarm(_alarms.length)) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showAlarmLimitSheet();
                  return;
                }
                await PortfolioService.addAlarm(
                  AlarmItem(
                    symbol: item.symbol,
                    name: item.name,
                    alertPrice: price,
                    alertAbove: above,
                    alertType: above ? 'sell' : 'buy',
                  ),
                );
                _loadWatchlist();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Alarm kuruldu.'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text(
                above ? 'Satış Alarmı Kur' : 'Alış Alarmı Kur',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final secondary = onSurface.withValues(alpha: 0.72);
    final cardColor = theme.colorScheme.surfaceContainerHighest;
    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  if (Navigator.canPop(context))
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow.withValues(
                                alpha: 0.08,
                              ),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_ios,
                          size: 16,
                          color: onSurface,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      'Takip Listesi',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF34C759),
                      ),
                    ),
                  IconButton(
                    onPressed: _loadWatchlist,
                    icon: Icon(Icons.refresh, color: secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_border, color: secondary, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Takip listesi boş',
                            style: TextStyle(color: secondary),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _showAddDialog,
                            child: const Text(
                              'Hisse Ekle',
                              style: TextStyle(color: Color(0xFF34C759)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final item = _items[i];
                        final asset = _assets[item.symbol];
                        final alarms = _alarmMap[item.symbol] ?? [];
                        final alarmCount = alarms.length;

                        return Dismissible(
                          key: Key(item.symbol),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            color: const Color(0xFFFF3B30),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) async {
                            await PortfolioService.removeFromWatchlist(
                              item.symbol,
                            );
                            _loadWatchlist();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.shadow.withValues(
                                    alpha: 0.05,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Üst satır: rozet + isim + değişim rozeti ──
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E3A5F),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          item.symbol.length > 5
                                              ? item.symbol.substring(0, 5)
                                              : item.symbol,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: TextStyle(
                                              color: onSurface,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            item.symbol,
                                            style: TextStyle(
                                              color: secondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (alarmCount > 0) ...[
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.notifications_active,
                                                  size: 11,
                                                  color: Color(0xFFFFB300),
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  '$alarmCount alarm',
                                                  style: const TextStyle(
                                                    color: Color(0xFFFFB300),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Değişim rozeti + alarm ikonu
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (asset == null && _loading)
                                          const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF34C759),
                                            ),
                                          )
                                        else if (asset != null)
                                          StockPriceHeader(asset: asset)
                                        else
                                          Text(
                                            '—',
                                            style: TextStyle(color: secondary),
                                          ),
                                        const SizedBox(height: 6),
                                        GestureDetector(
                                          onTap: () => _showAlertDialog(item),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                alarmCount > 0
                                                    ? Icons.notifications_active
                                                    : Icons.notifications_none,
                                                color: alarmCount > 0
                                                    ? const Color(0xFFFFB300)
                                                    : secondary,
                                                size: 22,
                                              ),
                                              if (alarmCount > 0) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFFFB300,
                                                    ).withValues(alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '$alarmCount',
                                                    style: const TextStyle(
                                                      color: Color(0xFF8A6000),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                // ── Alt satır: Açılış / Yüksek / Düşük / Anlık ──
                                if (asset != null) ...[
                                  const SizedBox(height: 12),
                                  StockQuotePanel(asset: asset),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF34C759),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Canlı arama + anlık fiyat gösterimi dialog
// ─────────────────────────────────────────────

class _AddStockDialog extends StatefulWidget {
  final void Function(String symbol, String name) onAdd;
  const _AddStockDialog({required this.onAdd});

  @override
  State<_AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<_AddStockDialog> {
  final _ctrl = TextEditingController();
  List<Map<String, String>> _filtered = [];
  Map<String, String>? _selected;

  // Seçilen hissenin fiyat bilgisi
  AssetModel? _previewAsset;
  bool _loadingPrice = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final q = value.trim().toUpperCase();
    if (q.isEmpty) {
      setState(() {
        _filtered = [];
        _selected = null;
        _previewAsset = null;
      });
      return;
    }

    List<Map<String, String>> results;
    if (q.length == 1) {
      // Tek harf: sembol VEYA isim o harfle BAŞLAMALI
      results = kBistStocks
          .where((s) {
            return s['symbol']!.startsWith(q) ||
                s['name']!.toUpperCase().startsWith(q);
          })
          .take(10)
          .toList();
    } else {
      // 2+ harf: önce sembolü q ile başlayanlar, sonra isim içinde geçenler
      final bySymbol = kBistStocks
          .where((s) => s['symbol']!.startsWith(q))
          .toList();
      final byName = kBistStocks
          .where(
            (s) =>
                !s['symbol']!.startsWith(q) &&
                s['name']!.toUpperCase().contains(q),
          )
          .toList();
      results = [...bySymbol, ...byName].take(10).toList();
    }

    // Tam eşleşme varsa otomatik seç ve fiyatını çek
    final exact = results.where((s) => s['symbol'] == q).toList();
    if (exact.isNotEmpty && _selected?['symbol'] != q) {
      setState(() {
        _filtered = results;
        _selected = exact.first;
        _previewAsset = null;
      });
      _fetchPrice(q);
    } else {
      setState(() {
        _filtered = results;
        if (exact.isEmpty) {
          _selected = null;
          _previewAsset = null;
        }
      });
    }
  }

  void _pick(Map<String, String> stock) {
    final sym = stock['symbol']!;
    setState(() {
      _selected = stock;
      _ctrl.text = sym;
      _filtered = [];
      _previewAsset = null;
    });
    _fetchPrice(sym);
  }

  Future<void> _fetchPrice(String symbol) async {
    if (!mounted) return;
    setState(() => _loadingPrice = true);
    final asset = await StockService.fetchStock(symbol, period: '5d');
    if (!mounted) return;
    setState(() {
      _loadingPrice = false;
      _previewAsset = asset;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _previewAsset;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Takibe Ekle',
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Arama kutusu ──
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: TextStyle(color: theme.colorScheme.onSurface),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Hisse kodu veya isim yazın...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  size: 20,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: _onChanged,
            ),

            // ── Seçilen hisse + anlık fiyat kartı ──
            if (_selected != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF34C759).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    // Hisse etiketi
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C3A5E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _selected!['symbol']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Şirket adı
                    Expanded(
                      child: Text(
                        _selected!['name']!,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Fiyat bölümü
                    if (_loadingPrice)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF34C759),
                        ),
                      )
                    else if (preview != null)
                      StockPriceHeader(asset: preview)
                    else
                      Text(
                        '—',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (preview != null) ...[
                const SizedBox(height: 8),
                StockQuotePanel(asset: preview, showDivider: false),
              ],
            ],

            // ── Sonuç listesi ──
            if (_filtered.isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final s = _filtered[i];
                    final isChosen = _selected?['symbol'] == s['symbol'];
                    return GestureDetector(
                      onTap: () => _pick(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isChosen
                              ? const Color(0xFF34C759).withValues(alpha: 0.10)
                              : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(8),
                          border: isChosen
                              ? Border.all(
                                  color: const Color(
                                    0xFF34C759,
                                  ).withValues(alpha: 0.35),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Sembol etiketi
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C3A5E),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                s['symbol']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Şirket adı
                            Expanded(
                              child: Text(
                                s['name']!,
                                style: TextStyle(
                                  color: isChosen
                                      ? const Color(0xFF34C759)
                                      : theme.colorScheme.onSurface,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Seçili işareti
                            if (isChosen)
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF34C759),
                                size: 16,
                              )
                            else
                              Icon(
                                Icons.add,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                                size: 16,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // ── Boş sonuç mesajı ──
            if (_ctrl.text.isNotEmpty && _filtered.isEmpty && _selected == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '"${_ctrl.text.toUpperCase()}" için sonuç bulunamadı.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'İptal',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF34C759),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            // _selected null ise (listeden seçilmemiş) ekleme yapma
            if (_selected == null) {
              // Yazan metni göster, uyar
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lütfen listeden bir hisse seçin'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Color(0xFFFF3B30),
                ),
              );
              return;
            }
            Navigator.pop(context);
            widget.onAdd(_selected!['symbol']!, _selected!['name']!);
          },
          child: const Text(
            'Ekle',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
