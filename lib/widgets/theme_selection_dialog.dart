import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class ThemeSelectionDialog extends StatefulWidget {
  const ThemeSelectionDialog({super.key});

  @override
  State<ThemeSelectionDialog> createState() => _ThemeSelectionDialogState();
}

class _ThemeSelectionDialogState extends State<ThemeSelectionDialog> {
  // Varsayılan olarak Gündüz Modu (false) seçili
  bool _isDarkSelected = false;

  void _onComplete() async {
    // Seçimi kaydet
    await SettingsService.setDarkMode(_isDarkSelected);
    await SettingsService.markThemeSelected();
    
    if (!mounted) return;
    Navigator.of(context).pop();

    // İkazı göster (Tercih değiştirmek için...)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF34C759)),
            SizedBox(width: 10),
            Text('Bilgilendirme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Tema tercihinizi dilediğiniz zaman "Ayarlar" bölümünden değiştirebilirsiniz.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF34C759),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Modalın kendisi sabit olarak aydınlık temada görünsün ki 
    // kullanıcı seçim yaparken daha net bir kontrast görsün veya sistem temasına uysun.
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // İkon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.palette_outlined, size: 36, color: Color(0xFF34C759)),
            ),
            const SizedBox(height: 20),
            
            // Başlık
            const Text(
              'Uygulama Teması',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // Alt başlık
            const Text(
              'Teknik Bakış\'ı nasıl kullanmak istersiniz?',
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Seçenekler
            Row(
              children: [
                Expanded(
                  child: _ThemeOptionCard(
                    title: 'Gündüz',
                    icon: Icons.wb_sunny_rounded,
                    isSelected: !_isDarkSelected,
                    onTap: () => setState(() => _isDarkSelected = false),
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ThemeOptionCard(
                    title: 'Gece',
                    icon: Icons.nights_stay_rounded,
                    isSelected: _isDarkSelected,
                    onTap: () => setState(() => _isDarkSelected = true),
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Tamam Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34C759),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Tamam', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _ThemeOptionCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? color : Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
