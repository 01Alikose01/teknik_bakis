import 'package:flutter_test/flutter_test.dart';
import 'package:teknik_bakis/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TeknikBakisApp());
    expect(find.byType(TeknikBakisApp), findsOneWidget);
  });
}
