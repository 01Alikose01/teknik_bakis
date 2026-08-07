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

  test('Ücretsiz plan seçildiğinde premium erişim kapanır', () async {
    await SubscriptionService.reset();
    await SubscriptionService.init();
    await SubscriptionService.startGuestTrial();

    await SubscriptionService.selectFreePlan();

    expect(SubscriptionService.hasPremiumAccess, isFalse);
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
