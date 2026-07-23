import 'package:flutter/material.dart';

class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedThreshold = 1; // %1, %3, %5, %10

  final List<int> _thresholds = [1, 3, 5, 10];

  final List<_SignalEntry> _entries = [
    _SignalEntry(symbol: 'THYAO', status: SignalStatus.buySignal, detail: 'Bugün 10:14', change: null, notification: null),
    _SignalEntry(symbol: 'ASELS', status: SignalStatus.inPosition, detail: '30.06 09:15', entryPrice: 45.20, change: 1.99, notification: '%1 bildirimi gitti'),
    _SignalEntry(symbol: 'EREGL', status: SignalStatus.inPosition, detail: '28.06 11:02', entryPrice: 38.90, change: 5.01, notification: '%5 bildirimi gitti'),
    _SignalEntry(symbol: 'SİSE', status: SignalStatus.buySignal, detail: 'Bugün 09:40', change: null, notification: null),
    _SignalEntry(symbol: 'KCHOL', status: SignalStatus.inPosition, detail: '25.06 13:40', entryPrice: 152.30, change: -2.10, notification: 'Eşik altında'),
    _SignalEntry(symbol: 'TUPRS', status: SignalStatus.buySignal, detail: 'Bugün 08:55', change: null, notification: null),
    _SignalEntry(symbol: 'BIMAS', status: SignalStatus.inPosition, detail: '20.06 10:05', entryPrice: 210.00, change: 10.24, notification: '%10 bildirimi gitti'),
    _SignalEntry(symbol: 'AKBNK', status: SignalStatus.buySignal, detail: 'Bugün 07:30', change: null, notification: null),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.index = 2; // Sinyaller sekmesi aktif
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Text(
                'Sinyaller',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),

            // Tab: Grafik / KAP / Sinyaller
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF242438),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF333355),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'Grafik'),
                    Tab(text: 'KAP'),
                    Tab(text: 'Sinyaller'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const Center(child: Text('Grafik', style: TextStyle(color: Colors.grey))),
                  const Center(child: Text('KAP', style: TextStyle(color: Colors.grey))),
                  // Sinyaller içeriği
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kâr bildirim eşikleri',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        // Eşik seçici
                        Row(
                          children: _thresholds.map((t) {
                            final selected = t == _selectedThreshold;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedThreshold = t),
                                child: Container(
                                  margin: EdgeInsets.only(right: t != _thresholds.last ? 8 : 0),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selected ? const Color(0xFF333355) : const Color(0xFF242438),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '%$t',
                                      style: TextStyle(
                                        color: selected ? Colors.white : Colors.grey,
                                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),
                        Text(
                          '${_entries.length} hisse takip listesinde',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 10),

                        // Sinyal kartları
                        ..._entries.map((entry) => _SignalCard(entry: entry)),
                        const SizedBox(height: 24),
                      ],
                    ),
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

enum SignalStatus { buySignal, inPosition }

class _SignalEntry {
  final String symbol;
  final SignalStatus status;
  final String detail;
  final double? entryPrice;
  final double? change;
  final String? notification;

  _SignalEntry({
    required this.symbol,
    required this.status,
    required this.detail,
    this.entryPrice,
    this.change,
    this.notification,
  });
}

class _SignalCard extends StatelessWidget {
  final _SignalEntry entry;

  const _SignalCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // Sembol badge
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                entry.symbol,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Orta: durum veya giriş bilgisi
          Expanded(
            child: entry.status == SignalStatus.buySignal
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AL sinyali',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(entry.detail, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Giriş: ${entry.entryPrice?.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(entry.detail, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
          ),

          // Sağ: Aldım butonu veya değişim
          if (entry.status == SignalStatus.buySignal)
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A2A45),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                elevation: 0,
              ),
              child: const Text('Aldım', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(entry.change ?? 0) >= 0 ? '+' : ''}${entry.change?.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: (entry.change ?? 0) >= 0 ? const Color(0xFF00C853) : const Color(0xFFE53935),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.alarm, color: Colors.grey, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      entry.notification ?? '',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
