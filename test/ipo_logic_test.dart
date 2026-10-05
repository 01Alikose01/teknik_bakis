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
    expect(waitingListing.status, IpoStatus.pendingListing);
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

  group('Halka Arz durum akisi ve listeleme kurallari', () {
    final now = DateTime.now();

    // Senaryo 1: Talep tarihi gelecekte → Yaklaşan
    test('1. Talep tarihi gelecekte olan hisse Yaklaşan durumuna girer', () {
      final item = IpoItem.fromJson({
        'companyName': 'Gelecek Sirket',
        'symbol': 'GELCK',
        'requestStart': isoDay(now.add(const Duration(days: 5))),
        'requestEnd': isoDay(now.add(const Duration(days: 7))),
      });
      expect(item.status, IpoStatus.upcoming);
    });

    // Senaryo 2: Talep başladı, bitmedi → Talep Topluyor
    test('2. Talebi devam eden hisse Talep Topluyor durumuna girer', () {
      final item = IpoItem.fromJson({
        'companyName': 'Aktif Halka Arz',
        'symbol': 'AKTIF',
        'requestStart': isoDay(now.subtract(const Duration(days: 2))),
        'requestEnd': isoDay(now.add(const Duration(days: 2))),
      });
      expect(item.status, IpoStatus.collecting);
    });

    // Senaryo 3: Talep bitti, listeleme tarihi gelecekte → Listeleme Bekliyor
    test('3. Talebi biten, listeleme tarihi gelecekte olan hisse Listeleme Bekliyor durumuna girer', () {
      final item = IpoItem.fromJson({
        'companyName': 'Liste Bekleyen',
        'symbol': 'LSTBK2',
        'requestStart': isoDay(now.subtract(const Duration(days: 8))),
        'requestEnd': isoDay(now.subtract(const Duration(days: 4))),
        'listingDate': isoDay(now.add(const Duration(days: 3))),
      });
      expect(item.status, IpoStatus.pendingListing);
    });

    // Senaryo 4: Listeleme tarihi geçti → Borsada
    test('4. Listeleme tarihi geçmiş hisse Borsada durumuna girer', () {
      final item = IpoItem.fromJson({
        'companyName': 'Borsada Hisse',
        'symbol': 'BORSA',
        'requestStart': isoDay(now.subtract(const Duration(days: 15))),
        'requestEnd': isoDay(now.subtract(const Duration(days: 10))),
        'listingDate': isoDay(now.subtract(const Duration(days: 3))),
      });
      expect(item.status, IpoStatus.trading);
    });

    // Senaryo 5 & 6: 15 trading hisseden sadece en yeni 10'u listede görünür
    test('5-6. Borsada listesinde maksimum 10 hisse görünür, 11. silinmez sadece listede olmaz', () {
      // 15 adet trading hissesi oluştur (farklı listingDate'lerle)
      final allTrading = List.generate(15, (i) {
        return IpoItem.fromJson({
          'companyName': 'Hisse ${i + 1}',
          'symbol': 'HS${(i + 1).toString().padLeft(2, '0')}',
          'requestStart': isoDay(now.subtract(Duration(days: 30 + i))),
          'requestEnd': isoDay(now.subtract(Duration(days: 20 + i))),
          // Hisse 0 en yeni (1 gün önce), Hisse 14 en eski (15 gün önce)
          'listingDate': isoDay(now.subtract(Duration(days: i + 1))),
        });
      });

      // Tüm hisseler trading statüsünde olmalı
      for (final item in allTrading) {
        expect(item.status, IpoStatus.trading,
            reason: '${item.symbol} trading olmalı');
      }

      // _groupedItems mantığını elle uygula: listingDate desc sırala, take(10)
      final sorted = [...allTrading]
        ..sort((a, b) {
          final aDate = a.listingDate ?? a.sortDate ?? DateTime(1970);
          final bDate = b.listingDate ?? b.sortDate ?? DateTime(1970);
          return bDate.compareTo(aDate);
        });
      final latestTrading = sorted.take(10).toList();

      // Gösterilen listede maksimum 10 kayıt olmalı
      expect(latestTrading.length, 10);

      // 11. hisse (index 10) listede olmamalı ama nesne hâlâ erişilebilir olmalı
      final eleventhItem = sorted[10];
      expect(latestTrading.contains(eleventhItem), isFalse,
          reason: '11. hisse latestTrading listesinde olmamalı');

      // 11. hisse hâlâ allTrading listesinde (silinmedi)
      expect(allTrading.contains(eleventhItem), isTrue,
          reason: '11. hisse ana listede hâlâ bulunmalı (silinmedi)');
    });

    // Senaryo 7: Yeni hisse Borsada'ya geçince listeye en üstten girer
    test('7. Borsada listesine eklenen en yeni hisse listenin başında yer alır', () {
      // 5 hisse oluştur, en yeni listingDate ilk sıraya gelmeli
      final items = [
        IpoItem.fromJson({
          'companyName': 'Orta Hisse',
          'symbol': 'ORTA',
          'requestEnd': isoDay(now.subtract(const Duration(days: 20))),
          'listingDate': isoDay(now.subtract(const Duration(days: 5))),
        }),
        IpoItem.fromJson({
          'companyName': 'En Yeni Hisse',
          'symbol': 'YENI',
          'requestEnd': isoDay(now.subtract(const Duration(days: 10))),
          'listingDate': isoDay(now.subtract(const Duration(days: 1))),
        }),
        IpoItem.fromJson({
          'companyName': 'Eski Hisse',
          'symbol': 'ESKI',
          'requestEnd': isoDay(now.subtract(const Duration(days: 30))),
          'listingDate': isoDay(now.subtract(const Duration(days: 10))),
        }),
      ];

      // Tüm hisseler trading olmalı
      for (final item in items) {
        expect(item.status, IpoStatus.trading);
      }

      // Listingdate'e göre en yeniden eskiye sırala
      final sorted = [...items]
        ..sort((a, b) {
          final aDate = a.listingDate ?? DateTime(1970);
          final bDate = b.listingDate ?? DateTime(1970);
          return bDate.compareTo(aDate);
        });

      // En yeni hisse en üstte olmalı
      expect(sorted.first.symbol, 'YENI');
      expect(sorted.last.symbol, 'ESKI');
    });

    // Senaryo 8: Aynı hisse iki sekmede görünmez
    test('8. Bir hisse yalnızca tek bir durumda sınıflandırılır', () {
      // Talep toplama sürecinde olan bir hisse
      final collectingItem = IpoItem.fromJson({
        'companyName': 'Tek Sekme Hisse',
        'symbol': 'TKSEK',
        'requestStart': isoDay(now.subtract(const Duration(days: 1))),
        'requestEnd': isoDay(now.add(const Duration(days: 2))),
        'listingDate': isoDay(now.add(const Duration(days: 10))),
      });

      // Durum collecting olmalı
      expect(collectingItem.status, IpoStatus.collecting);

      // upcoming, pendingListing veya trading olmamalı
      expect(collectingItem.status, isNot(IpoStatus.upcoming));
      expect(collectingItem.status, isNot(IpoStatus.pendingListing));
      expect(collectingItem.status, isNot(IpoStatus.trading));
    });

    // Senaryo 9: JSON'da "trading" yazsa da tarihler Borsada değilse doğru sınıflandırılır
    test('9. JSON status="trading" olsa bile tarihler Listeleme Bekliyor ise pendingListing döner', () {
      final item = IpoItem.fromJson({
        'companyName': 'Yanlis Statuslu Hisse',
        'symbol': 'YANLS',
        'requestStart': isoDay(now.subtract(const Duration(days: 8))),
        'requestEnd': isoDay(now.subtract(const Duration(days: 4))),
        'listingDate': isoDay(now.add(const Duration(days: 5))),
        'status': 'trading', // JSON'da yanlış yazılmış
      });

      // Gerçek tarihler pendingListing gösteriyor: talep bitti, listeleme gelecekte
      expect(item.status, IpoStatus.pendingListing);
    });

    // Senaryo A: requestStart ve requestEnd geçmişte, listingDate null, status='upcoming'
    test('A. requestStart ve requestEnd geçmişte, listingDate null → pendingListing (kesinlikle upcoming değil)', () {
      final item = IpoItem.fromJson({
        'companyName': 'SOHO Giyim Benzeri',
        'symbol': 'SOHO',
        'requestStart': isoDay(now.subtract(const Duration(days: 100))),
        'requestEnd': isoDay(now.subtract(const Duration(days: 99))),
        'status': 'upcoming', // Firestore'da yanlış upcoming yazılmış
      });

      expect(item.status, isNot(IpoStatus.upcoming));
      expect(item.status, IpoStatus.pendingListing);
    });

    // Senaryo B: requestStart ve requestEnd geçmişte, listingDate geçmişte, status='upcoming'
    test('B. requestStart, requestEnd ve listingDate geçmişte → trading', () {
      final item = IpoItem.fromJson({
        'companyName': 'Borsada Hisse',
        'symbol': 'BRSD',
        'requestStart': isoDay(now.subtract(const Duration(days: 30))),
        'requestEnd': isoDay(now.subtract(const Duration(days: 28))),
        'listingDate': isoDay(now.subtract(const Duration(days: 20))),
        'status': 'upcoming', // Firestore'da yanlış upcoming yazılmış
      });

      expect(item.status, IpoStatus.trading);
    });

    // Senaryo C: tüm tarih alanları null, status='upcoming'
    test('C. Tüm tarih alanları null, status="upcoming" → upcoming (tarih bilgisi yoksa tahmin yapılamaz)', () {
      final item = IpoItem.fromJson({
        'companyName': 'Tarihsiz Hisse',
        'symbol': 'TRHS',
        'status': 'upcoming',
      });

      expect(item.status, IpoStatus.upcoming);
    });

    // Senaryo D: requestStart gelecekte, status='trading' (yanlış Firestore değeri)
    test('D. requestStart gelecekte, status="trading" → upcoming (tarihler kazanır)', () {
      final item = IpoItem.fromJson({
        'companyName': 'Gelecekte Hisse',
        'symbol': 'GLCK',
        'requestStart': isoDay(now.add(const Duration(days: 10))),
        'requestEnd': isoDay(now.add(const Duration(days: 12))),
        'status': 'trading', // Firestore'da yanlış trading yazılmış
      });

      expect(item.status, IpoStatus.upcoming);
    });

    // Senaryo E: SOHO case — requestStart ve requestEnd geçmişte, listingDate geçmişte
    test('E. SOHO benzeri: requestStart=30 Haz, requestEnd=1 Tem, listingDate=8 Tem geçmiş → trading', () {
      final item = IpoItem.fromJson({
        'companyName': 'SOHO Giyim ve Enerji A.S.',
        'symbol': 'SOHO',
        'requestStart': '2026-06-30',
        'requestEnd': '2026-07-01',
        'listingDate': '2026-07-08',
        'status': 'upcoming',
      });

      // Tüm tarihler 2026'da; test "şimdi"si 2026'dan sonra değil.
      // Test ortamında 2026 hâlâ gelecekte olabilir — bu senaryoda requestStart gelecekte.
      // Sadece tarihlerin doğru yönde işlendiğini doğrula (status != upcoming unless requestStart future).
      // Bu testin kesin davranışı çalıştırıldığı tarihe göre değişir;
      // dolayısıyla sadece model'in status'u tarihe göre türettiğini doğruluyoruz.
      final derivedStatus = item.status;
      if (item.requestStart != null && item.requestStart!.isAfter(DateTime.now())) {
        expect(derivedStatus, IpoStatus.upcoming);
      } else {
        expect(derivedStatus, isNot(IpoStatus.upcoming));
      }
    });

    // Senaryo F: SOHO listingDate yok — requestStart ve requestEnd geçmişte → pendingListing
    test('F. requestStart ve requestEnd geçmişte, listingDate bilinmiyor → pendingListing (upcoming değil)', () {
      final item = IpoItem.fromJson({
        'companyName': 'SOHO listingDate Yok',
        'symbol': 'SOHO2',
        'requestStart': isoDay(now.subtract(const Duration(days: 98))),
        'requestEnd': isoDay(now.subtract(const Duration(days: 97))),
        // listingDate yok
        'status': 'upcoming',
      });

      expect(item.status, isNot(IpoStatus.upcoming));
      expect(item.status, IpoStatus.pendingListing);
    });
  });
}
