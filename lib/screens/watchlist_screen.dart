import 'package:flutter/material.dart';
import '../models/asset_model.dart';
import '../models/portfolio_model.dart';
import '../services/portfolio_service.dart';
import '../services/stock_service.dart'; // kBistStocks de buradan export ediliyor
import '../services/notification_service.dart';
import '../widgets/stock_quote_panel.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<WatchlistItem> _items = [];
  Map<String, AssetModel> _assets = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    setState(() {
      _items = PortfolioService.getWatchlist();
      _loading = _items.isNotEmpty;
    });
    if (_items.isEmpty) return;

    for (final item in _items) {
      final asset = await StockService.fetchStock(item.symbol, period: '1mo');
      if (asset != null) {
        _checkAlert(item, asset.price);
        if (mounted) {
          setState(() => _assets[item.symbol] = asset);
        }
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _checkAlert(WatchlistItem item, double currentPrice) {
    if (item.alertPrice == null) return;
    if (item.alertAbove && currentPrice >= item.alertPrice!) {
      NotificationService.showPriceAlert(
        symbol: item.symbol,
        price: currentPrice,
        isAbove: true,
      );
    } else if (!item.alertAbove && currentPrice <= item.alertPrice!) {
      NotificationService.showPriceAlert(
        symbol: item.symbol,
        price: currentPrice,
        isAbove: false,
      );
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

  void _showAlertDialog(WatchlistItem item) {
    final priceCtrl = TextEditingController(
      text: item.alertPrice?.toStringAsFixed(2) ?? '',
    );
    // true = fiyat üstüne geçince (Satış Alarmı), false = altına düşünce (Alış Alarmı)
    bool above = item.alertAbove;
    final currentPrice = _assets[item.symbol]?.price ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1C3A5E),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(item.symbol,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            const Text('Fiyat Alarmı',
                style: TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bildirim izni uyarısı
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFFF9500).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFFFF9500), size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Alarmın çalışması için telefon bildirim ayarlarından '
                        '"Teknik Bakış" uygulamasına izin verdiğinden emin ol.',
                        style: TextStyle(
                            color: Color(0xFFFF9500),
                            fontSize: 11,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Alarm Tipi seçimi
              const Text('Alarm Türü',
                  style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                // Alış Alarmı — fiyat düşünce
                Expanded(
                  child: GestureDetector(
                    onTap: () => setDialogState(() => above = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 8),
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
                      child: Column(children: [
                        Icon(Icons.arrow_downward_rounded,
                            color: !above
                                ? const Color(0xFF34C759)
                                : Colors.grey,
                            size: 20),
                        const SizedBox(height: 4),
                        Text('Alış Alarmı',
                            style: TextStyle(
                                color: !above
                                    ? const Color(0xFF34C759)
                                    : Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        Text('Fiyat düşünce',
                            style: TextStyle(
                                color: !above
                                    ? const Color(0xFF34C759)
                                        .withValues(alpha: 0.7)
                                    : Colors.grey[400],
                                fontSize: 10)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Satış Alarmı — fiyat yükselince
                Expanded(
                  child: GestureDetector(
                    onTap: () => setDialogState(() => above = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 8),
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
                      child: Column(children: [
                        Icon(Icons.arrow_upward_rounded,
                            color:
                                above ? const Color(0xFFFF3B30) : Colors.grey,
                            size: 20),
                        const SizedBox(height: 4),
                        Text('Satış Alarmı',
                            style: TextStyle(
                                color: above
                                    ? const Color(0xFFFF3B30)
                                    : Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        Text('Fiyat yükselince',
                            style: TextStyle(
                                color: above
                                    ? const Color(0xFFFF3B30)
                                        .withValues(alpha: 0.7)
                                    : Colors.grey[400],
                                fontSize: 10)),
                      ]),
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 14),

              // Güncel fiyat
              Row(children: [
                const Text('Anlık Fiyat:',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(width: 6),
                Text('${currentPrice.toStringAsFixed(2)} ₺',
                    style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ]),
              const SizedBox(height: 8),

              // Alarm fiyatı
              const Text('Alarm Fiyatı (₺)',
                  style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              TextField(
                controller: priceCtrl,
                style: const TextStyle(color: Colors.black87),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: above
                      ? 'Hedef satış fiyatı gir...'
                      : 'Hedef alış fiyatı gir...',
                  hintStyle:
                      const TextStyle(color: Colors.grey, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
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

              // Açıklama notu
              const SizedBox(height: 8),
              Text(
                above
                    ? '📢 Fiyat girilen seviyeye ulaşırsa veya geçerse bildirim alırsın.'
                    : '📢 Fiyat girilen seviyeye düşerse veya altına inerse bildirim alırsın.',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),

              // Mevcut alarm varsa sil butonu
              if (item.alertPrice != null) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    await PortfolioService.updateWatchlistAlert(
                        item.symbol, null, true);
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadWatchlist();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFFF3B30)
                              .withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            color: Color(0xFFFF3B30), size: 16),
                        SizedBox(width: 6),
                        Text('Mevcut Alarmı Kaldır',
                            style: TextStyle(
                                color: Color(0xFFFF3B30),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: above
                    ? const Color(0xFFFF3B30)
                    : const Color(0xFF34C759),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final price =
                    double.tryParse(priceCtrl.text.replaceAll(',', '.'));
                if (price == null || price <= 0) return;
                await PortfolioService.updateWatchlistAlert(
                    item.symbol, price, above);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadWatchlist();
              },
              child: Text(above ? 'Satış Alarmı Kur' : 'Alış Alarmı Kur',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
                        ),
                        child: const Icon(Icons.arrow_back_ios, size: 16, color: Colors.black87),
                      ),
                    ),
                  const Expanded(
                    child: Text('Takip Listesi',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF34C759)),
                    ),
                  IconButton(
                    onPressed: _loadWatchlist,
                    icon: const Icon(Icons.refresh, color: Colors.grey),
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
                          const Icon(Icons.star_border, color: Colors.grey, size: 48),
                          const SizedBox(height: 12),
                          const Text('Takip listesi boş', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _showAddDialog,
                            child: const Text('Hisse Ekle', style: TextStyle(color: Color(0xFF34C759))),
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

                        return Dismissible(
                          key: Key(item.symbol),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            color: const Color(0xFFFF3B30),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) async {
                            await PortfolioService.removeFromWatchlist(item.symbol);
                            _loadWatchlist();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 6, offset: const Offset(0, 2))],
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
                                              fontWeight: FontWeight.bold),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.name,
                                              style: const TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis),
                                          Text(item.symbol,
                                              style: const TextStyle(
                                                  color: Colors.grey, fontSize: 12)),
                                          if (item.alertPrice != null) ...[
                                            const SizedBox(height: 2),
                                            Row(children: [
                                              Icon(
                                                item.alertAbove ? Icons.arrow_upward : Icons.arrow_downward,
                                                size: 11, color: const Color(0xFFFFB300)),
                                              const SizedBox(width: 3),
                                              Text('Alarm: ${item.alertPrice!.toStringAsFixed(2)} ₺',
                                                  style: const TextStyle(
                                                      color: Color(0xFFFFB300), fontSize: 11)),
                                            ]),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Değişim rozeti + alarm ikonu
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (asset == null && _loading)
                                          const SizedBox(
                                            width: 16, height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFF34C759)),
                                          )
                                        else if (asset != null)
                                          StockPriceHeader(asset: asset)
                                        else
                                          const Text('—',
                                              style: TextStyle(color: Colors.grey)),
                                        const SizedBox(height: 6),
                                        GestureDetector(
                                          onTap: () => _showAlertDialog(item),
                                          child: Icon(
                                            item.alertPrice != null
                                                ? Icons.notifications_active
                                                : Icons.notifications_none,
                                            color: item.alertPrice != null
                                                ? const Color(0xFFFFB300)
                                                : Colors.grey,
                                            size: 22,
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
        foregroundColor: Colors.black,
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
      results = kBistStocks.where((s) {
        return s['symbol']!.startsWith(q) ||
            s['name']!.toUpperCase().startsWith(q);
      }).take(10).toList();
    } else {
      // 2+ harf: önce sembolü q ile başlayanlar, sonra isim içinde geçenler
      final bySymbol = kBistStocks
          .where((s) => s['symbol']!.startsWith(q))
          .toList();
      final byName = kBistStocks
          .where((s) =>
              !s['symbol']!.startsWith(q) &&
              s['name']!.toUpperCase().contains(q))
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
    final preview = _previewAsset;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Takibe Ekle',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
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
              style: const TextStyle(color: Colors.black87),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Hisse kodu veya isim yazın...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.grey, size: 20),
                filled: true,
                fillColor: const Color(0xFFF2F2F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: _onChanged,
            ),

            // ── Seçilen hisse + anlık fiyat kartı ──
            if (_selected != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF34C759).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    // Hisse etiketi
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C3A5E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _selected!['symbol']!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Şirket adı
                    Expanded(
                      child: Text(
                        _selected!['name']!,
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
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
                      const Text('—',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 12)),
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
                            horizontal: 12, vertical: 9),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isChosen
                              ? const Color(0xFF34C759)
                                  .withValues(alpha: 0.10)
                              : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(8),
                          border: isChosen
                              ? Border.all(
                                  color: const Color(0xFF34C759)
                                      .withValues(alpha: 0.35))
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Sembol etiketi
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C3A5E),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(s['symbol']!,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 10),
                            // Şirket adı
                            Expanded(
                              child: Text(
                                s['name']!,
                                style: TextStyle(
                                    color: isChosen
                                        ? const Color(0xFF34C759)
                                        : Colors.black87,
                                    fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Seçili işareti
                            if (isChosen)
                              const Icon(Icons.check_circle,
                                  color: Color(0xFF34C759), size: 16)
                            else
                              const Icon(Icons.add,
                                  color: Colors.grey, size: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // ── Boş sonuç mesajı ──
            if (_ctrl.text.isNotEmpty &&
                _filtered.isEmpty &&
                _selected == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '"${_ctrl.text.toUpperCase()}" için sonuç bulunamadı.',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF34C759),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
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
          child: const Text('Ekle',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
