import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ipo_item.dart';
import '../services/ipo_service.dart';
import '../services/subscription_service.dart';
import '../services/app_navigation.dart';
import 'premium_gate_screen.dart';

class IpoScreen extends StatefulWidget {
  const IpoScreen({super.key});

  @override
  State<IpoScreen> createState() => _IpoScreenState();
}

class _IpoScreenState extends State<IpoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Timer? _refreshTimer;

  List<IpoItem> _items = [];
  DateTime? _lastSyncedAt;
  String _source = 'Yerel yedek veri';
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitial();
    _refreshTimer = Timer.periodic(
      IpoService.refreshInterval,
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final localFeed = await IpoService.loadCachedOrSeed();
    if (!mounted) return;

    setState(() {
      _items = localFeed.items;
      _lastSyncedAt = localFeed.lastSyncedAt;
      _source = localFeed.source;
      _loading = false;
    });

    if (IpoService.shouldRefresh(localFeed.lastSyncedAt)) {
      await _refresh(silent: _items.isNotEmpty);
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;

    setState(() {
      _refreshing = true;
      if (!silent) {
        _loading = _items.isEmpty;
      }
      _error = null;
    });

    try {
      final feed = await IpoService.refresh();
      if (!mounted) return;

      setState(() {
        _items = feed.items;
        _lastSyncedAt = feed.lastSyncedAt;
        _source = feed.source;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _groupedItems();

    // Halka Arz: 10 gün ücretsiz deneme sonrası yalnızca premium erişim.
    if (!SubscriptionService.canAccess('ipo')) {
      return PremiumGateScreen(
        embedded: true,
        nextScreen: const IpoScreen(),
        showGuestOption: !SubscriptionService.hasUsedTrialBefore,
        onBack: () => AppNavigation.goToHome(),
        onGuestContinue: () => AppNavigation.goToHome(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Halka Arzlar'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _refreshing ? null : () => _refresh(),
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Yaklaşan'),
            Tab(text: 'Talep Topluyor'),
            Tab(text: 'Borsada İşlem Görüyor'),
            Tab(text: 'Tümü'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildHeader(theme, grouped),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(
                        grouped.upcoming,
                        emptyText: 'Yaklaşan halka arz bulunmuyor.',
                      ),
                      _buildList(
                        grouped.collecting,
                        emptyText: 'Talep toplayan halka arz bulunmuyor.',
                      ),
                      _buildList(
                        grouped.latestTrading,
                        emptyText:
                            'Borsada işlem görmeye başlayan halka arz bulunmuyor.',
                        infoText:
                            'Bu bölümde yalnızca en güncel 10 halka arz yer alır; yeni kayıtlar geldikçe en eski olanlar otomatik olarak listeden çıkar.',
                      ),
                      _buildList(
                        grouped.latestAll,
                        emptyText: 'Genel halka arz listesi boş.',
                        infoText:
                            'Tümü sekmesinde en güncel 10 halka arzı toplu olarak görürsünüz; yeni kayıtlar eklendikçe liste kendini otomatik yeniler.',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, _IpoGroups grouped) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(
                icon: Icons.schedule_outlined,
                label: 'Yaklaşan',
                value: grouped.upcoming.length.toString(),
                color: const Color(0xFF007AFF),
              ),
              _summaryChip(
                icon: Icons.flash_on_outlined,
                label: 'Talep Topluyor',
                value: grouped.collecting.length.toString(),
                color: const Color(0xFFFF9500),
              ),
              _summaryChip(
                icon: Icons.candlestick_chart,
                label: 'Borsada',
                value: grouped.trading.length.toString(),
                color: const Color(0xFF34C759),
              ),
              _summaryChip(
                icon: Icons.list_alt_outlined,
                label: 'Genel Liste',
                value: grouped.all.length.toString(),
                color: const Color(0xFF5856D6),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Son senkron: ${_formatDateTime(_lastSyncedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Kaynak: $_source',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFFD92D20),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(
    List<IpoItem> items, {
    required String emptyText,
    String? infoText,
  }) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                if (infoText != null) ...[
                  _infoCard(infoText),
                  const SizedBox(height: 16),
                ],
                _emptyCard(emptyText),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: items.length + (infoText == null ? 0 : 1),
              itemBuilder: (context, index) {
                if (infoText != null && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _infoCard(infoText),
                  );
                }
                final itemIndex = infoText == null ? index : index - 1;
                final item = items[itemIndex];
                return _buildIpoCard(item, itemIndex);
              },
            ),
    );
  }

  Widget _buildIpoCard(IpoItem item, int index) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(item.status);
    final palette = _cardPalette(theme, index);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: palette.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      Text(
                        item.companyName.isEmpty
                            ? item.symbol
                            : item.companyName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.symbol.isEmpty ? 'Kod bekleniyor' : item.symbol,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _detailTile(
                  'Talep Tarihleri',
                  item.requestDates,
                  backgroundColor: palette.tileColor,
                  borderColor: palette.borderColor,
                ),
                _detailTile(
                  'Fiyat',
                  item.price,
                  backgroundColor: palette.tileColor,
                  borderColor: palette.borderColor,
                ),
                _detailTile(
                  'Lot',
                  item.lot,
                  backgroundColor: palette.tileColor,
                  borderColor: palette.borderColor,
                ),
                _detailTile(
                  'Dagitim Tipi',
                  item.distributionType,
                  backgroundColor: palette.tileColor,
                  borderColor: palette.borderColor,
                ),
                _detailTile(
                  'Borsa Kodu',
                  item.symbol,
                  backgroundColor: palette.tileColor,
                  borderColor: palette.borderColor,
                ),
                _detailTile(
                  'Durum',
                  item.statusLabel,
                  accentColor: statusColor,
                  backgroundColor: palette.tileColor,
                  borderColor: palette.borderColor,
                ),
              ],
            ),
            if (item.listingDate != null) ...[
              const SizedBox(height: 12),
              Text(
                'Islem tarihi: ${_formatDate(item.listingDate!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailTile(
    String label,
    String value, {
    Color? accentColor,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? '-' : value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accentColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String text) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _emptyCard(String text) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 38,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _IpoGroups _groupedItems() {
    final all = [..._items]
      ..sort((a, b) {
        final aDate = a.sortDate ?? DateTime(1970);
        final bDate = b.sortDate ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

    final upcoming = all
        .where((item) => item.status == IpoStatus.upcoming)
        .toList()
      ..sort((a, b) {
        final aDate = a.requestStart ?? a.sortDate ?? DateTime(2099);
        final bDate = b.requestStart ?? b.sortDate ?? DateTime(2099);
        return aDate.compareTo(bDate);
      });
      
    final collecting = all
        .where((item) => item.status == IpoStatus.collecting)
        .toList()
      ..sort((a, b) {
        final aDate = a.requestStart ?? a.sortDate ?? DateTime(2099);
        final bDate = b.requestStart ?? b.sortDate ?? DateTime(2099);
        return aDate.compareTo(bDate);
      });
      
    final trading = all
        .where((item) => item.status == IpoStatus.trading)
        .toList();

    return _IpoGroups(
      all: all,
      latestAll: all.take(10).toList(),
      upcoming: upcoming,
      collecting: collecting,
      trading: trading,
      latestTrading: trading.take(10).toList(),
    );
  }

  _IpoCardPalette _cardPalette(ThemeData theme, int index) {
    final baseBackground = theme.colorScheme.surface;
    final altBackground = theme.colorScheme.surfaceContainerHighest;
    final tileColor = theme.colorScheme.surfaceContainerHighest;
    final borderColor = theme.brightness == Brightness.light
        ? theme.colorScheme.outline
        : theme.colorScheme.onSurface.withValues(alpha: 0.12);

    return index.isEven
        ? _IpoCardPalette(
            backgroundColor: baseBackground,
            tileColor: tileColor,
            borderColor: borderColor,
          )
        : _IpoCardPalette(
            backgroundColor: altBackground,
            tileColor: tileColor,
            borderColor: borderColor,
          );
  }

  Color _statusColor(IpoStatus status) {
    switch (status) {
      case IpoStatus.upcoming:
        return const Color(0xFF007AFF);
      case IpoStatus.collecting:
        return const Color(0xFFFF9500);
      case IpoStatus.trading:
        return const Color(0xFF34C759);
    }
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.'
        '${value.month.toString().padLeft(2, '0')}.'
        '${value.year}';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    return '${_formatDate(value)} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}

class _IpoGroups {
  final List<IpoItem> all;
  final List<IpoItem> latestAll;
  final List<IpoItem> upcoming;
  final List<IpoItem> collecting;
  final List<IpoItem> trading;
  final List<IpoItem> latestTrading;

  const _IpoGroups({
    required this.all,
    required this.latestAll,
    required this.upcoming,
    required this.collecting,
    required this.trading,
    required this.latestTrading,
  });
}

class _IpoCardPalette {
  final Color backgroundColor;
  final Color tileColor;
  final Color borderColor;

  const _IpoCardPalette({
    required this.backgroundColor,
    required this.tileColor,
    required this.borderColor,
  });
}
