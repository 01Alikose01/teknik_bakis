import 'package:flutter_test/flutter_test.dart';
import 'package:teknik_bakis/services/stock_service.dart';

void main() {
  group('sanitizeChangePercent', () {
    test('clamps BIST stock gains above daily limit to +10%', () {
      expect(StockService.sanitizeChangePercent('AKBNK', 11.0), 10.0);
      expect(StockService.sanitizeChangePercent('AKBNK', 10.39), 10.0);
      expect(StockService.sanitizeChangePercent('AKBNK', 9.8), 9.8);
    });

    test('clamps BIST stock losses below daily limit to -10%', () {
      expect(StockService.sanitizeChangePercent('TATEN', -11.0), -10.0);
      expect(StockService.sanitizeChangePercent('TATEN', -10.39), -10.0);
      expect(StockService.sanitizeChangePercent('TATEN', -9.8), -9.8);
    });

    test('leaves non-BIST assets unchanged', () {
      expect(StockService.sanitizeChangePercent('ALTIN', 11.0), 11.0);
    });
  });
}
