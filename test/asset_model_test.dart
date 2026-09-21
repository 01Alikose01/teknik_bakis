import 'package:flutter_test/flutter_test.dart';
import 'package:teknik_bakis/models/asset_model.dart';

void main() {
  group('AssetModel chart alignment', () {
    test('appendLatestQuote keeps prices and OHLC lengths aligned', () {
      final asset = AssetModel(
        symbol: 'ARCLK',
        name: 'Arçelik',
        prices: [100.0, 101.0],
        opens: [99.0, 100.5],
        highs: [102.0, 103.0],
        lows: [98.0, 99.5],
        volumes: [1000.0, 1200.0],
      );

      asset.appendLatestQuote(
        price: 102.0,
        open: 101.0,
        high: 103.5,
        low: 100.0,
        volume: 1400.0,
      );

      expect(asset.prices.length, 3);
      expect(asset.opens.length, 3);
      expect(asset.highs.length, 3);
      expect(asset.lows.length, 3);
      expect(asset.volumes.length, 3);
      expect(asset.prices.last, 102.0);
      expect(asset.opens.last, 101.0);
      expect(asset.highs.last, 103.5);
      expect(asset.lows.last, 100.0);
      expect(asset.volumes.last, 1400.0);
    });
  });
}
