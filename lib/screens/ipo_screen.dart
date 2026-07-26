import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ipo_item.dart';
import '../services/ipo_service.dart';

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
                            'Bu bölüm sadece en yeni 10 halka arz kaydını gösterir.',
                      ),
                      _buildList(
                        grouped.all,
                        emptyText: 'Genel halka arz listesi boş.',
                        infoText:
                            'Bu liste geçmiş kayıtları silmez; yeni halka arzlar geldikçe büyür.',
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
      color: Colors.white,
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
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(
            'Kaynak: $_source',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
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
                final item = items[infoText == null ? index : index - 1];
                return _buildIpoCard(item);
              },
            ),
    );
  }

  Widget _buildIpoCard(IpoItem item) {
    final statusColor = _statusColor(item.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.symbol.isEmpty ? 'Kod bekleniyor' : item.symbol,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
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
                _detailTile('Talep Tarihleri', item.requestDates),
                _detailTile('Fiyat', item.price),
                _detailTile('Lot', item.lot),
                _detailTile('Dagitim Tipi', item.distributionType),
                _detailTile('Borsa Kodu', item.symbol),
                _detailTile(
                  'Durum',
                  item.statusLabel,
                  accentColor: statusColor,
                ),
              ],
            ),
            if (item.listingDate != null) ...[
              const SizedBox(height: 12),
              Text(
                'Islem tarihi: ${_formatDate(item.listingDate!)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailTile(String label, String value, {Color? accentColor}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? '-' : value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accentColor ?? Colors.black87,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF1D4ED8),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 38, color: Colors.black38),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
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
        .toList();
    final collecting = all
        .where((item) => item.status == IpoStatus.collecting)
        .toList();
    final trading = all
        .where((item) => item.status == IpoStatus.trading)
        .toList();

    return _IpoGroups(
      all: all,
      upcoming: upcoming,
      collecting: collecting,
      trading: trading,
      latestTrading: trading.take(10).toList(),
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
  final List<IpoItem> upcoming;
  final List<IpoItem> collecting;
  final List<IpoItem> trading;
  final List<IpoItem> latestTrading;

  const _IpoGroups({
    required this.all,
    required this.upcoming,
    required this.collecting,
    required this.trading,
    required this.latestTrading,
  });
}
