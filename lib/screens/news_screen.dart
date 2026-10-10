import 'package:flutter/material.dart';
import 'dart:async';
import '../models/borsa_news_item.dart';
import '../models/kap_news_item.dart';
import '../services/borsa_news_service.dart';
import '../services/kap_disclosure_service.dart';
import '../services/kap_news_service.dart';
import '../services/subscription_service.dart';
import 'news_detail_screen.dart';
import 'kap_ai_list_screen.dart';
import 'premium_gate_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<KapNewsItem> _kapNews = [];
  List<BorsaNewsItem> _borsaNews = [];
  bool _loadingKap = false;
  bool _loadingBorsa = false;
  Timer? _refreshTimer;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 90), (_) => _loadAll());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadKap(), _loadBorsa()]);
    if (mounted) setState(() => _lastUpdated = DateTime.now());
  }

  /// GitHub veya yerel saati Türkiye saatiyle (UTC+3) "Güncelleme HH:mm" olarak döndürür.
  String _formatUpdateTime() {
    if (KapNewsService.lastUpdated.isNotEmpty) {
      try {
        // KapNewsService.lastUpdated → "2026-10-10T14:15:50.000Z" formatında UTC
        final utc = DateTime.parse(KapNewsService.lastUpdated).toUtc();
        final tr = utc.add(const Duration(hours: 3));
        return 'Güncelleme ${tr.hour.toString().padLeft(2, '0')}:${tr.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    if (_lastUpdated != null) {
      // Cihaz saati zaten yerel — Türkiye'de çalışan kullanıcılar için doğrudan kullan
      final tr = _lastUpdated!;
      return 'Güncelleme ${tr.hour.toString().padLeft(2, '0')}:${tr.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  Future<void> _loadKap() async {
    if (mounted) setState(() => _loadingKap = true);
    try {
      var items = await KapDisclosureService.fetchLatest();
      if (items.isEmpty) {
        items = await KapNewsService.fetch();
      }
      final deduped = KapNewsService.dedupe(items);
      if (mounted) {
        setState(() {
          _kapNews = deduped;
          _loadingKap = false;
        });
      }
    } catch (_) {
      try {
        final deduped = KapNewsService.dedupe(await KapNewsService.fetch());
        if (mounted) {
          setState(() {
            _kapNews = deduped;
            _loadingKap = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loadingKap = false);
      }
    }
  }

  Future<void> _loadBorsa() async {
    if (mounted) setState(() => _loadingBorsa = true);
    try {
      final items = await BorsaNewsService.fetchLatest();
      if (mounted) {
        setState(() {
          _borsaNews = items;
          _loadingBorsa = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBorsa = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SubscriptionService.canAccess('news')) {
      return PremiumGateScreen(
        embedded: true,
        nextScreen: const NewsScreen(),
        showGuestOption: !SubscriptionService.hasUsedTrialBefore,
        goToHomeOnFreePlan: true,
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  Text('Haberler',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_lastUpdated != null)
                    Text(
                      _formatUpdateTime(),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 11),
                    ),
                  IconButton(
                    icon: Icon(Icons.refresh,
                        color: theme.colorScheme.onSurface.withOpacity(0.7), size: 20),
                    onPressed: _loadAll,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: Color(0xFF34C759), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('Son 72 saat • Otomatik güncelleme',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 11)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(10)),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: theme.colorScheme.onPrimary,
                  unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.65),
                  labelStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: const [
                    Tab(text: 'KAP Bildirimleri'),
                    Tab(text: 'Borsa Haberleri'),
                    Tab(text: 'KAP AI'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildKapList(),
                  _buildBorsaList(),
                  KapAiListScreen(
                    kapItems: _kapNews,
                    loading: _loadingKap,
                    onRefresh: _loadKap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKapList() {
    final theme = Theme.of(context);
    if (_loadingKap && _kapNews.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF34C759)),
            const SizedBox(height: 12),
            Text('KAP bildirimleri yükleniyor...',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF34C759),
      onRefresh: _loadKap,
      child: Column(
        children: [
          if (_kapNews.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  Icon(Icons.history, size: 13, color: theme.colorScheme.onSurface.withOpacity(0.65)),
                  const SizedBox(width: 4),
                  Text(
                      'Son ${_kapNews.length} bildirimi gösteriliyor (72 saat)',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 11)),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _kapNews.length,
              itemBuilder: (_, i) {
                final item = _kapNews[i];
                return _KapNewsCard(item: item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorsaList() {
    final theme = Theme.of(context);
    if (_loadingBorsa && _borsaNews.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF34C759)),
            const SizedBox(height: 12),
            Text('Haberler yükleniyor...',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF34C759),
      onRefresh: _loadBorsa,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _borsaNews.length,
        itemBuilder: (_, i) => _BorsaNewsCard(item: _borsaNews[i]),
      ),
    );
  }
}

class _KapNewsCard extends StatelessWidget {
  final KapNewsItem item;
  const _KapNewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewsDetailScreen(
            title: item.cleanTitle,
            summary: item.summary,
            source: item.source,
            time: item.time,
            url: item.url,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C3A5E).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(item.source,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF1C3A5E),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                if (item.isWithin72h) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Yeni',
                        style: TextStyle(
                            color: Color(0xFF34C759),
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
                const Spacer(),
                Icon(Icons.access_time, size: 11, color: theme.colorScheme.onSurface.withOpacity(0.65)),
                const SizedBox(width: 3),
                Text(item.time,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 11)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.65)),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.cleanTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

class _BorsaNewsCard extends StatelessWidget {
  final BorsaNewsItem item;
  const _BorsaNewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewsDetailScreen(
            title: item.title,
            summary: item.summary,
            source: item.source,
            time: item.time,
            url: item.url,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(item.source,
                      style: const TextStyle(
                          color: Color(0xFF34C759),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Icon(Icons.access_time, size: 11, color: theme.colorScheme.onSurface.withOpacity(0.65)),
                const SizedBox(width: 3),
                Text(item.time,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 11)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.65)),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.65), fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}
