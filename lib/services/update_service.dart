import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Google Play In-App Update API ile güncelleme kontrolü yapar.
/// 
/// Kullanım:
///   await UpdateService.checkForUpdate(context);
///
/// - Güncelleme varsa kullanıcıya dialog gösterir.
/// - Güncelleme zorunluysa (immediateUpdate) uygulama kapanana kadar bekler.
/// - Sadece Android'de çalışır; iOS ve diğerlerinde sessizce atlar.
class UpdateService {
  UpdateService._();

  /// Güncelleme kontrolü yapar. context, dialog göstermek için gerekli.
  static Future<void> checkForUpdate(BuildContext context) async {
    // Sadece Android'de çalıştır
    if (!Platform.isAndroid) return;

    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          // Zorunlu güncelleme — tam ekran indirme akışı başlatılır
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          // İsteğe bağlı güncelleme — arka planda indirilir
          if (context.mounted) {
            _showFlexibleUpdateDialog(context);
          }
        }
      }
    } catch (_) {
      // Play Store erişilemiyor veya uygulama geliştirici modunda —
      // sessizce geç, kullanıcıyı rahatsız etme
    }
  }

  /// Flexible (isteğe bağlı) güncelleme için kullanıcıya dialog gösterir.
  static void _showFlexibleUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: Color(0xFF34C759), size: 24),
            SizedBox(width: 10),
            Text(
              'Güncelleme Mevcut',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: const Text(
          'Teknik Bakış\'ın yeni bir sürümü yayınlandı.\n\n'
          'En iyi deneyim için lütfen uygulamayı güncelleyin.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          // Sonra hatırlat
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Sonra',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          // Güncelle
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF34C759),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await InAppUpdate.startFlexibleUpdate();
                await InAppUpdate.completeFlexibleUpdate();
              } catch (_) {}
            },
            child: const Text(
              'Güncelle',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
