import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'alarm_overlay_service.dart';
import 'settings_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Uygulama içi overlay için BuildContext sağlayıcısı.
  // main.dart'taki navigatorKey üzerinden context alınır.
  static BuildContext? Function()? _contextProvider;

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
        AndroidNotificationChannel(
          'ipo_alerts',
          'Halka Arz Bildirimleri',
          description: 'Yeni yaklaşan halka arz bildirimleri',
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

  /// Uygulama içi overlay için context sağlayıcıyı kaydet.
  /// main.dart'ta NavigatorKey hazır olduktan sonra çağrılır.
  static void registerContextProvider(BuildContext? Function() provider) {
    _contextProvider = provider;
  }

  /// Bildirim izni var mı kontrol et (Android 13+ / iOS).
  static Future<bool> hasPermission() async {
    try {
      if (Platform.isAndroid) {
        final plugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await plugin?.areNotificationsEnabled();
        return granted ?? true;
      } else if (Platform.isIOS) {
        final plugin = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await plugin?.checkPermissions();
        return granted?.isEnabled ?? true;
      }
    } catch (_) {}
    return true; // belirsizse push dene
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
    // Push bildirimi (izin varsa)
    final permitted = await hasPermission();
    if (permitted) {
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

    // Uygulama içi overlay — ayar açıksa
    _showAlarmOverlay(symbol: symbol, price: price, isAbove: isAbove);
  }

  /// Overlay gösterimini senkron olarak tetikler (async gap uyarısını önler).
  static void _showAlarmOverlay({
    required String symbol,
    required double price,
    required bool isAbove,
  }) {
    if (!SettingsService.inAppAlarmNotification.value) return;
    final ctx = _contextProvider?.call();
    if (ctx == null) return;
    AlarmOverlayService.show(
      context: ctx,
      symbol: symbol,
      price: price,
      isAbove: isAbove,
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

  static Future<void> showIpoAlert({
    required String companyName,
    required String symbol,
    int count = 1,
  }) async {
    final ipoTitle = count == 1
        ? '🎉 Yeni Halka Arz!'
        : '🎉 $count Yeni Halka Arz!';
    final ipoPushBody = count == 1
        ? '$companyName${symbol.isNotEmpty ? ' ($symbol)' : ''} halka arz oluyor! Halka Arz bölümünden takip edebilirsiniz.'
        : '$companyName ve diğerleri halka arz oluyor! Halka Arz bölümünden takip edebilirsiniz.';
    final ipoOverlayBody = count == 1
        ? '$companyName${symbol.isNotEmpty ? ' ($symbol)' : ''} halka arz oluyor!'
        : '$companyName ve diğerleri halka arz oluyor!';

    // Push bildirimi (izin varsa)
    final permitted = await hasPermission();
    if (permitted) {
      const androidDetails = AndroidNotificationDetails(
        'ipo_alerts',
        'Halka Arz Bildirimleri',
        channelDescription: 'Yeni yaklaşan halka arz bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _plugin.show(
        'ipo_alert'.hashCode,
        ipoTitle,
        ipoPushBody,
        details,
      );
    }

    // Uygulama içi overlay — ayar açıksa
    _showIpoOverlay(title: ipoTitle, body: ipoOverlayBody);
  }

  /// IPO overlay gösterimini senkron olarak tetikler (async gap uyarısını önler).
  static void _showIpoOverlay({
    required String title,
    required String body,
  }) {
    if (!SettingsService.inAppIpoNotification.value) return;
    final ctx = _contextProvider?.call();
    if (ctx == null) return;
    AlarmOverlayService.showIpo(
      context: ctx,
      title: title,
      body: body,
    );
  }
}
