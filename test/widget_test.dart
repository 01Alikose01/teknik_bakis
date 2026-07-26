import 'package:flutter_test/flutter_test.dart';
import 'package:teknik_bakis/models/ipo_item.dart';

void main() {
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
}
