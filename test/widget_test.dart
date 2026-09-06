import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:teknik_bakis/models/ipo_item.dart';
import 'package:teknik_bakis/screens/premium_gate_screen.dart';
import 'package:teknik_bakis/screens/settings_screen.dart';
import 'package:teknik_bakis/services/app_navigation.dart';
import 'package:teknik_bakis/services/subscription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Hive.initFlutter();
  });

  test('IpoItem durumunu tarihlere gore belirler', () {
    final upcoming = IpoItem.fromJson({
      'companyName': 'Test Sirket',
      'symbol': 'TEST1',
      'requestStart': '2099-01-10',
      'requestEnd': '2099-01-12',
      'price': '10,00 TL',
      'lot': '100.000 lot',
      'distributionType': 'Esit Dagitim',
    });

    final trading = IpoItem.fromJson({
      'companyName': 'Eski Sirket',
      'symbol': 'TEST2',
      'requestStart': '2026-01-10',
      'requestEnd': '2026-01-12',
      'listingDate': '2026-01-20',
      'price': '12,50 TL',
      'lot': '80.000 lot',
      'distributionType': 'Oransal Dagitim',
    });

    expect(upcoming.status, IpoStatus.upcoming);
    expect(upcoming.requestDates, '10.01.2099 - 12.01.2099');

    expect(trading.status, IpoStatus.trading);
    expect(trading.statusLabel, 'Borsada İşlem Görüyor');
  });

  testWidgets('Settings ekranı başarıyla açılır', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Ayarlar'), findsOneWidget);
  });

  test('Yeni kullanıcıda trial otomatik başlar ve Premium erişim verir', () async {
    await SubscriptionService.reset();
    await SubscriptionService.init();

    expect(SubscriptionService.trialStart, isNotNull);
    expect(SubscriptionService.isInFreeTrial, isTrue);
    expect(SubscriptionService.hasPremiumAccess, isTrue);
  });

  test('Trial başlangıcı 10 günden eskiyse Premium erişim kapanır', () async {
    await SubscriptionService.reset();
    await SubscriptionService.init();
    await Hive.box<dynamic>('subscription').put(
      'trialStart',
      DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
    );

    expect(SubscriptionService.isInFreeTrial, isFalse);
    expect(SubscriptionService.hasPremiumAccess, isFalse);
  });

  test('Paid subscription trial başlangıcını değiştirmez', () async {
    await SubscriptionService.reset();
    await SubscriptionService.init();
    final originalTrialStart = SubscriptionService.trialStart;

    await SubscriptionService.startPaidSubscription('monthly');

    expect(SubscriptionService.trialStart, originalTrialStart);
    expect(SubscriptionService.isPaidSubscriber, isTrue);
  });

  test('Trial bitmiş olsa da aktif paid subscription Premium erişim verir',
      () async {
    await SubscriptionService.reset();
    await SubscriptionService.init();
    await Hive.box<dynamic>('subscription').put(
      'trialStart',
      DateTime.now().subtract(const Duration(days: 11)).toIso8601String(),
    );
    await SubscriptionService.startPaidSubscription('yearly');

    expect(SubscriptionService.isInFreeTrial, isFalse);
    expect(SubscriptionService.hasPremiumAccess, isTrue);
  });

  testWidgets('Ücretsiz plan seçildiğinde başarı mesajı gösterilir', (tester) async {
    await SubscriptionService.reset();
    await SubscriptionService.init();

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Planları Görüntüle'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Ücretsiz\'i Keşfet'));
    await tester.pumpAndSettle();

    expect(find.text('Ücretsiz plana geçildi.'), findsOneWidget);
  });

  testWidgets('Ücretsiz seçildiğinde ana sayfaya geçer', (tester) async {
    await SubscriptionService.reset();
    await SubscriptionService.init();

    int? selectedIndex;
    AppNavigation.registerTabSetter((index) => selectedIndex = index);

    await tester.pumpWidget(
      MaterialApp(
        home: PremiumGateScreen(
          embedded: true,
          nextScreen: const SizedBox(),
          goToHomeOnFreePlan: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Ücretsiz\'i Keşfet'));
    await tester.pumpAndSettle();

    expect(selectedIndex, 0);
  });
}
