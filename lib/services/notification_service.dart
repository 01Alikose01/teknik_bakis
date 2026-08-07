import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static List<AndroidNotificationChannel> get androidChannels => const [
        AndroidNotificationChannel(
          'price_alerts',
          'Fiyat Alarmları',
          description: 'Hisse fiyat alarm bildirimleri',
          importance: Importance.high,
        ),
        AndroidNotificationChannel(
          'signals',
          'Teknik Sinyaller',
          description: 'Hisse teknik analiz sinyal bildirimleri',
          importance: Importance.high,
        ),
      ];

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      for (final channel in androidChannels) {
        await androidPlugin?.createNotificationChannel(channel);
      }
    }
  }

  static Future<void> requestPermission() async {
    if (!Platform.isAndroid) {
      return;
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showPriceAlert({
    required String symbol,
    required double price,
    required bool isAbove,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'price_alerts',
      'Fiyat Alarmları',
      channelDescription: 'Hisse fiyat alarm bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      symbol.hashCode,
      '$symbol Fiyat Alarmı',
      '$symbol ${isAbove ? 'hedef fiyata ulaştı' : 'alarm seviyesinin altına düştü'}: ${price.toStringAsFixed(2)} ₺',
      details,
    );
  }

  static Future<void> showSignalAlert({
    required String symbol,
    required String signal,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'signals',
      'Teknik Sinyaller',
      channelDescription: 'Hisse teknik analiz sinyal bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      '${symbol}_signal'.hashCode,
      '$symbol - $signal',
      '$symbol hissesi için $signal tespit edildi',
      details,
    );
  }
}
