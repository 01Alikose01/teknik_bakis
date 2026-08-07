import 'package:flutter/material.dart';
import '../models/asset_model.dart';
import '../models/portfolio_model.dart';
import '../services/portfolio_service.dart';
import '../services/stock_service.dart';
import '../services/subscription_service.dart';
import 'premium_gate_screen.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  List<AlarmItem> _alarms = [];

  @override
  void initState() {
    super.initState();
    _loadAlarms();
  }

  void _loadAlarms() {
    setState(() {
      _alarms = PortfolioService.getAlarms()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Future<void> _removeAlarm(AlarmItem alarm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alarmı kaldır?'),
        content: const Text('Bu alarmı silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hayır'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await PortfolioService.removeAlarmItem(alarm);
    _loadAlarms();
  }

  void _showAlarmLimitSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
            const Text(
              'Ücretsiz Alarm Limitine Ulaştınız',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ücretsiz planda en fazla ${SubscriptionService.freeAlarmLimit} fiyat alarmı kurabilirsiniz.\nSınırsız alarm için Premium\'a geçin.',
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
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
                      builder: (_) =>
                          PremiumGateScreen(nextScreen: const AlarmScreen()),
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
          ],
        ),
      ),
    );
  }

  void _showSelectStockDialog() {
    if (!SubscriptionService.canCreateAlarm(_alarms.length)) {
      _showAlarmLimitSheet();
      return;
    }

    final searchCtrl = TextEditingController();
    List<Map<String, String>> filteredItems = List.from(kBistStocks);
    final theme = Theme.of(context);
    final inputFill = theme.brightness == Brightness.dark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF2F2F7);
    final inputBorder = theme.brightness == Brightness.dark
        ? Colors.white24
        : Colors.transparent;
    final textColor = theme.colorScheme.onSurface;
    final hintColor = theme.colorScheme.onSurface.withOpacity(0.6);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            'Alarm Ekle',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchCtrl,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Tüm hisseleri ara...',
                    hintStyle: TextStyle(color: hintColor),
                    prefixIcon: Icon(Icons.search, color: hintColor),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.2,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    final query = value.trim().toLowerCase();
                    setDialogState(() {
                      if (query.isEmpty) {
                        filteredItems = List.from(kBistStocks);
                      } else {
                        filteredItems = kBistStocks.where((item) {
                          final name = (item['name'] ?? '').toLowerCase();
                          final symbol = (item['symbol'] ?? '').toLowerCase();
                          return name.contains(query) || symbol.contains(query);
                        }).toList();
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return ListTile(
                        title: Text(
                          item['name'] ?? item['symbol'] ?? '',
                          style: TextStyle(color: textColor),
                        ),
                        subtitle: Text(
                          item['symbol'] ?? '',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showCreateAlarmDialog(
                            WatchlistItem(
                              symbol: item['symbol'] ?? '',
                              name: item['name'] ?? '',
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAlarmDialog(WatchlistItem item) {
    final priceCtrl = TextEditingController();
    bool above = true;
    AssetModel? selectedAsset;
    bool isLoadingPrice = true;
    bool didFetchPrice = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final theme = Theme.of(context);
          final textColor = theme.colorScheme.onSurface;
          final hintColor = theme.colorScheme.onSurface.withOpacity(0.6);
          final fieldFill = theme.brightness == Brightness.dark
              ? theme.colorScheme.surfaceVariant
              : const Color(0xFFF2F2F7);
          final borderColor = theme.brightness == Brightness.dark
              ? Colors.white12
              : Colors.transparent;
          final toggleBg = theme.brightness == Brightness.dark
              ? theme.colorScheme.surfaceVariant
              : const Color(0xFFF2F2F7);

          if (!didFetchPrice) {
            didFetchPrice = true;
            StockService.fetchStock(
              item.symbol,
              period: '1d',
              interval: '1d',
            ).then((asset) {
              if (!ctx.mounted) return;
              setDialogState(() {
                selectedAsset = asset;
                isLoadingPrice = false;
              });
            });
          }

          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yeni Alarm Kur',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.name,
                        style: TextStyle(
                          color: hintColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (isLoadingPrice)
                        Text(
                          'Fiyat yükleniyor...',
                          style: TextStyle(color: hintColor, fontSize: 12),
                        )
                      else if (selectedAsset != null)
                        Text(
                          '${selectedAsset!.price.toStringAsFixed(2)} ₺',
                          style: TextStyle(
                            color: selectedAsset!.changePercent >= 0
                                ? const Color(0xFF34C759)
                                : const Color(0xFFFF3B30),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        Text(
                          'Fiyat bilgisi bulunamadı',
                          style: TextStyle(color: hintColor, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                                ? const Color(
                                    0xFF34C759,
                                  ).withValues(alpha: 0.12)
                                : toggleBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: !above
                                  ? const Color(0xFF34C759)
                                  : borderColor,
                              width: !above ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                color: !above
                                    ? const Color(0xFF34C759)
                                    : hintColor,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Alış Alarmı',
                                style: TextStyle(
                                  color: !above
                                      ? const Color(0xFF34C759)
                                      : hintColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
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
                                ? const Color(
                                    0xFFFF3B30,
                                  ).withValues(alpha: 0.10)
                                : toggleBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: above
                                  ? const Color(0xFFFF3B30)
                                  : borderColor,
                              width: above ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.arrow_upward_rounded,
                                color: above
                                    ? const Color(0xFFFF3B30)
                                    : hintColor,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Satış Alarmı',
                                style: TextStyle(
                                  color: above
                                      ? const Color(0xFFFF3B30)
                                      : hintColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Alarm Fiyatı (₺)',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: priceCtrl,
                  style: TextStyle(color: textColor),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: above
                        ? 'Hedef satış fiyatı gir...'
                        : 'Hedef alış fiyatı gir...',
                    hintStyle: TextStyle(color: hintColor),
                    filled: true,
                    fillColor: fieldFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface.withOpacity(
                    0.75,
                  ),
                ),
                child: const Text('İptal'),
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

                  _loadAlarms();
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceSecondary = theme.colorScheme.onSurface.withOpacity(0.65);
    final shadowColor = theme.brightness == Brightness.light
        ? Colors.black.withOpacity(0.06)
        : Colors.white.withOpacity(0.06);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: onSurface),
        title: Text(
          'Tüm Alarmlar',
          style: TextStyle(color: onSurface, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _showSelectStockDialog,
            icon: const Text('🔔➕', style: TextStyle(fontSize: 20)),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: onSurfaceSecondary),
            onPressed: _loadAlarms,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_alarms.length} Alarm',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Takip listesine eklediğiniz hisseler için kurduğunuz tüm fiyat alarmlarını buradan yönetebilirsiniz.',
              style: TextStyle(
                color: onSurfaceSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _alarms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            color: onSurfaceSecondary,
                            size: 64,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Henüz alarm yok',
                            style: TextStyle(
                              color: onSurfaceSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Takip Listenizden bir hisse seçerek birden fazla alarm kurabilirsiniz.',
                            style: TextStyle(
                              color: onSurfaceSecondary,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _alarms.length,
                      itemBuilder: (context, index) {
                        final theme = Theme.of(context);
                        final alarm = _alarms[index];
                        final isSell = alarm.alertAbove;
                        final badgeColor = isSell
                            ? const Color(0xFFFF3B30)
                            : const Color(0xFF34C759);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor,
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 56,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        alarm.symbol,
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        softWrap: false,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            alarm.name,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: onSurface,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: badgeColor.withValues(
                                                alpha: 0.14,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              isSell ? 'Satış' : 'Alış',
                                              style: TextStyle(
                                                color: badgeColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${alarm.alertPrice.toStringAsFixed(2)} ₺',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            isSell
                                                ? Icons.arrow_upward
                                                : Icons.arrow_downward,
                                            size: 16,
                                            color: badgeColor,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${alarm.createdAt.day.toString().padLeft(2, '0')}.${alarm.createdAt.month.toString().padLeft(2, '0')}.${alarm.createdAt.year} ${alarm.createdAt.hour.toString().padLeft(2, '0')}:${alarm.createdAt.minute.toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                              color: onSurfaceSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removeAlarm(alarm),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: surface,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: onSurface.withOpacity(0.08),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      'çöp.png',
                                      width: 26,
                                      height: 26,
                                    ),
                                  ),
                                ),
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
    );
  }
}
