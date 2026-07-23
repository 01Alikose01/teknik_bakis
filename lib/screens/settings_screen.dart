import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık + profil görseli
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ayarlar',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 16),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image.asset(
                        'assets/tek.png',
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text('Teknik Bakış',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  ),
                  const Center(
                    child: Text('v1.0.0',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _SectionLabel('Hakkında'),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      title: 'Uygulama Hakkında',
                      onTap: () => _showAbout(context),
                    ),
                    _SettingsItem(
                      title: 'Sürüm',
                      trailing: const Text('1.0.0', style: TextStyle(color: Colors.grey)),
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _SectionLabel('Bildirimler'),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      title: 'Bildirim İzinlerini Yönet',
                      leadingIcon: Icons.notifications_outlined,
                      leadingColor: const Color(0xFF34C759),
                      trailingIcon: Icons.open_in_new,
                      onTap: () async {
                        await SystemNavigator.pop();
                      },
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _SectionLabel('Yardım & Destek'),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      title: 'SSS',
                      onTap: () => _showSss(context),
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _SectionLabel('Teknik Bakış Partneri'),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      title: 'Partnerlik Programı',
                      onTap: () {},
                    ),
                  ]),

                  const SizedBox(height: 20),
                  _SectionLabel('Abonelik'),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      title: 'Planları Görüntüle',
                      onTap: () => _showPlans(context),
                    ),
                    _SettingsItem(
                      title: 'Yasal Uyarı',
                      onTap: () => _showLegal(context),
                    ),
                  ]),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Teknik Bakış Hakkında'),
        content: const Text(
            'Teknik Bakış, BIST hisselerini teknik analiz göstergeleriyle tarayan ve yatırım kararlarınızı destekleyen bir mobil uygulamadır.\n\n'
            'Sürüm: 1.0.0\n'
            'Bu uygulama yatırım tavsiyesi niteliği taşımaz.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))],
      ),
    );
  }

  void _showSss(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Sık Sorulan Sorular', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            _FaqItem(q: 'Veriler güncel mi?', a: 'Evet, veriler Yahoo Finance üzerinden gerçek zamanlı çekilmektedir (15 dk gecikme).'),
            _FaqItem(q: 'Tarama nasıl çalışır?', a: 'BIST hisselerini seçili teknik göstergeye göre filtreler ve uygun hisseleri listeler.'),
            _FaqItem(q: 'RSI nasıl hesaplanır?', a: 'Wilder\'ın Smoothed RSI yöntemi kullanılır (14 periyot).'),
          ],
        ),
      ),
    );
  }

  void _showPlans(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Abonelik Planları'),
        content: const Text('Premium özellikler yakında kullanıma açılacaktır.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))],
      ),
    );
  }

  void _showLegal(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yasal Uyarı'),
        content: const Text(
            'Bu uygulama yalnızca bilgilendirme amaçlıdır. Yatırım tavsiyesi niteliği taşımaz. '
            'Yatırım kararlarınızdan doğan her türlü sonuç kullanıcıya aittir.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anladım'))],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13)),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<_SettingsItem> items;
  const _SettingsGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return Column(
            children: [
              item,
              if (i < items.length - 1)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final IconData? leadingIcon;
  final Color? leadingColor;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.title,
    this.trailing,
    this.leadingIcon,
    this.leadingColor,
    this.trailingIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: leadingIcon != null
          ? Icon(leadingIcon, color: leadingColor ?? Colors.grey, size: 20)
          : null,
      title: Text(title, style: const TextStyle(fontSize: 15, color: Colors.black87)),
      trailing: trailing ??
          (onTap != null
              ? Icon(trailingIcon ?? Icons.chevron_right, color: Colors.grey, size: 20)
              : null),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String q, a;
  const _FaqItem({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Text(a, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
