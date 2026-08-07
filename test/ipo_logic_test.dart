import 'package:flutter_test/flutter_test.dart';
import 'package:teknik_bakis/models/ipo_item.dart';
import 'package:teknik_bakis/services/bist_stocks.dart';

void main() {
  String isoDay(DateTime value) => value.toIso8601String().split('T').first;

  test('IpoItem durumunu tarihlere gore belirler', () {
    final now = DateTime.now();

    final upcoming = IpoItem.fromJson({
      'companyName': 'Test Sirket',
      'symbol': 'TEST1',
      'requestStart': isoDay(now.add(const Duration(days: 3))),
      'requestEnd': isoDay(now.add(const Duration(days: 5))),
      'price': '10,00 TL',
      'lot': '100.000 lot',
      'distributionType': 'Esit Dagitim',
    });

    final trading = IpoItem.fromJson({
      'companyName': 'Eski Sirket',
      'symbol': 'TEST2',
      'requestStart': isoDay(now.subtract(const Duration(days: 10))),
      'requestEnd': isoDay(now.subtract(const Duration(days: 8))),
      'listingDate': isoDay(now.subtract(const Duration(days: 2))),
      'price': '12,50 TL',
      'lot': '80.000 lot',
      'distributionType': 'Oransal Dagitim',
    });

    expect(upcoming.status, IpoStatus.upcoming);
    expect(trading.status, IpoStatus.trading);
    expect(trading.statusLabel, 'Borsada İşlem Görüyor');
  });

  test('Sabit status olsa bile halka arz durumu tarihe gore guncellenir', () {
    final now = DateTime.now();

    final collecting = IpoItem.fromJson({
      'companyName': 'Aktif Sirket',
      'symbol': 'AKTF1',
      'requestStart': isoDay(now.subtract(const Duration(days: 1))),
      'requestEnd': isoDay(now.add(const Duration(days: 1))),
      'status': 'upcoming',
    });

    final waitingListing = IpoItem.fromJson({
      'companyName': 'Liste Bekleyen Sirket',
      'symbol': 'LSTBK',
      'requestStart': isoDay(now.subtract(const Duration(days: 6))),
      'requestEnd': isoDay(now.subtract(const Duration(days: 4))),
      'listingDate': isoDay(now.add(const Duration(days: 3))),
      'status': 'trading',
    });

    expect(collecting.status, IpoStatus.collecting);
    expect(waitingListing.status, IpoStatus.collecting);
  });

  test('Borsada islem gormeye baslayan halka arz genel hisse listesine eklenir', () {
    final originalStocks = List<Map<String, String>>.from(kBistStocks);
    final now = DateTime.now();

    final tradingItem = IpoItem.fromJson({
      'companyName': 'Yeni Halka Arz',
      'symbol': 'YNHAL',
      'requestStart': isoDay(now.subtract(const Duration(days: 6))),
      'requestEnd': isoDay(now.subtract(const Duration(days: 4))),
      'listingDate': isoDay(now.subtract(const Duration(days: 1))),
      'status': 'upcoming',
    });

    syncBistStocksWithIpoItems([tradingItem]);

    expect(kBistStocks.any((item) => item['symbol'] == 'YNHAL'), isTrue);

    kBistStocks = originalStocks;
  });
}
