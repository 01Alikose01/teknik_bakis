class AssetModel {
  final String symbol;
  final String name;
  double price;
  double changePercent;
  double previousClose;
  double open;
  double high;
  double low;
  List<double> prices;  // kapanış fiyatları
  List<double> opens;   // açılış fiyatları (OHLC)
  List<double> highs;   // yüksek fiyatlar
  List<double> lows;    // düşük fiyatlar
  List<double> volumes;

  AssetModel({
    required this.symbol,
    required this.name,
    this.price = 0,
    this.changePercent = 0,
    this.previousClose = 0,
    this.open = 0,
    this.high = 0,
    this.low = 0,
    this.prices = const [],
    this.opens = const [],
    this.highs = const [],
    this.lows = const [],
    this.volumes = const [],
  });

  // EMA hesaplama — sonuç prices ile aynı uzunlukta değil, period-1 kısa
  List<double> ema(int period) {
    if (prices.length < period) return [];
    final k = 2.0 / (period + 1);
    final result = <double>[];
    double emaVal = prices.take(period).reduce((a, b) => a + b) / period;
    result.add(emaVal);
    for (int i = period; i < prices.length; i++) {
      emaVal = prices[i] * k + emaVal * (1 - k);
      result.add(emaVal);
    }
    return result; // length = prices.length - period + 1
  }

  // SMA (Simple Moving Average) hesaplama
  List<double> sma(int period) {
    if (prices.length < period) return [];
    final result = <double>[];
    for (int i = period - 1; i < prices.length; i++) {
      double sum = 0;
      for (int j = 0; j < period; j++) {
        sum += prices[i - j];
      }
      result.add(sum / period);
    }
    return result; // length = prices.length - period + 1
  }

  // ATR hesaplama
  List<double> atr({int period = 14}) {
    if (prices.length < period + 1) return [];
    final trs = <double>[];
    for (int i = 1; i < prices.length; i++) {
      trs.add((prices[i] - prices[i - 1]).abs());
    }
    final result = <double>[];
    double atrVal = trs.take(period).reduce((a, b) => a + b) / period;
    result.add(atrVal);
    for (int i = period; i < trs.length; i++) {
      atrVal = (atrVal * (period - 1) + trs[i]) / period;
      result.add(atrVal);
    }
    return result;
  }

  // Supertrend (factor=3, period=14)
  Map<String, List<double>> supertrend({int period = 14, double factor = 3.0}) {
    final atrVals = atr(period: period);
    if (atrVals.isEmpty) {
      return {'upper': [], 'lower': [], 'trend': [], 'direction': []};
    }
    final offset = prices.length - atrVals.length;
    final upper = <double>[];
    final lower = <double>[];
    final trend = <double>[];
    final direction = <double>[];

    double prevUpper = 0, prevLower = 0, prevTrend = prices[offset];

    for (int i = 0; i < atrVals.length; i++) {
      final idx = i + offset;
      final hl2 = prices[idx];
      final band = factor * atrVals[i];
      double upperBand = hl2 + band;
      double lowerBand = hl2 - band;

      if (i > 0) {
        upperBand = (upperBand < prevUpper || prices[idx - 1] > prevUpper) ? upperBand : prevUpper;
        lowerBand = (lowerBand > prevLower || prices[idx - 1] < prevLower) ? lowerBand : prevLower;
      }

      double dir, trendVal;
      if (i == 0) {
        dir = 1;
        trendVal = lowerBand;
      } else if (prevTrend == prevUpper) {
        dir = prices[idx] > upperBand ? 1 : -1;
        trendVal = dir == 1 ? lowerBand : upperBand;
      } else {
        dir = prices[idx] < lowerBand ? -1 : 1;
        trendVal = dir == 1 ? lowerBand : upperBand;
      }

      upper.add(upperBand);
      lower.add(lowerBand);
      trend.add(trendVal);
      direction.add(dir);
      prevUpper = upperBand;
      prevLower = lowerBand;
      prevTrend = trendVal;
    }
    return {'upper': upper, 'lower': lower, 'trend': trend, 'direction': direction};
  }

  // RSI — Wilder's Smoothed RSI (endüstri standardı)
  List<double> rsi({int period = 14}) {
    if (prices.length < period + 1) return [];

    // İlk period bardan başlangıç ortalamalarını hesapla
    double avgGain = 0, avgLoss = 0;
    for (int i = 1; i <= period; i++) {
      final diff = prices[i] - prices[i - 1];
      if (diff > 0) { avgGain += diff; } else { avgLoss -= diff; }
    }
    avgGain /= period;
    avgLoss /= period;

    final result = <double>[];
    // İlk RSI değeri
    if (avgLoss == 0) {
      result.add(100);
    } else {
      result.add(100 - (100 / (1 + avgGain / avgLoss)));
    }

    // Wilder smoothing ile devam et
    for (int i = period + 1; i < prices.length; i++) {
      final diff = prices[i] - prices[i - 1];
      final gain = diff > 0 ? diff : 0.0;
      final loss = diff < 0 ? -diff : 0.0;
      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;
      if (avgLoss == 0) {
        result.add(100);
      } else {
        result.add(100 - (100 / (1 + avgGain / avgLoss)));
      }
    }
    return result;
  }

  // MACD (12, 26, 9)
  Map<String, List<double>> macd() {
    final ema12 = ema(12);
    final ema26 = ema(26);
    if (ema12.isEmpty || ema26.isEmpty) return {'macd': [], 'signal': [], 'hist': []};
    // ema12.length = prices.length - 11
    // ema26.length = prices.length - 25
    // ema12 daha uzun, hizalamak için ema12'nin sondan ema26.length kadarını al
    final alignedEma12 = ema12.sublist(ema12.length - ema26.length);
    final macdLine = List.generate(ema26.length, (i) => alignedEma12[i] - ema26[i]);

    if (macdLine.length < 9) return {'macd': macdLine, 'signal': [], 'hist': []};
    final k = 2.0 / 10;
    double sigVal = macdLine.take(9).reduce((a, b) => a + b) / 9;
    final signal = <double>[sigVal];
    for (int i = 9; i < macdLine.length; i++) {
      sigVal = macdLine[i] * k + sigVal * (1 - k);
      signal.add(sigVal);
    }
    // signal daha kısa, hizala
    final alignedMacd = macdLine.sublist(macdLine.length - signal.length);
    final hist = List.generate(signal.length, (i) => alignedMacd[i] - signal[i]);
    return {'macd': macdLine, 'signal': signal, 'hist': hist};
  }

  // ---- Sinyal özellikleri ----

  bool get isSupertrendBuy {
    final dir = supertrend()['direction'] ?? [];
    if (dir.length < 2) return false;
    return dir[dir.length - 2] == -1 && dir.last == 1;
  }

  bool get isSupertrendSell {
    final dir = supertrend()['direction'] ?? [];
    if (dir.length < 2) return false;
    return dir[dir.length - 2] == 1 && dir.last == -1;
  }

  double get supertrendDirection {
    final dir = supertrend()['direction'] ?? [];
    return dir.isEmpty ? 0 : dir.last;
  }

  // Golden Cross: EMA20, EMA50'yi bir önceki bar negatif, bu bar pozitif kesti
  bool get isGoldenCross {
    final e20 = ema(20); // length = prices.length - 19
    final e50 = ema(50); // length = prices.length - 49
    if (e20.length < 2 || e50.length < 2) return false;
    // Ortak son 2 değeri al
    final e20Prev = e20[e20.length - 2];
    final e20Curr = e20.last;
    final e50Prev = e50[e50.length - 2];
    final e50Curr = e50.last;
    return (e20Prev - e50Prev) < 0 && (e20Curr - e50Curr) >= 0;
  }

  // Death Cross: EMA20, EMA50'yi bir önceki bar pozitif, bu bar negatif kesti
  bool get isDeathCross {
    final e20 = ema(20);
    final e50 = ema(50);
    if (e20.length < 2 || e50.length < 2) return false;
    final e20Prev = e20[e20.length - 2];
    final e20Curr = e20.last;
    final e50Prev = e50[e50.length - 2];
    final e50Curr = e50.last;
    return (e20Prev - e50Prev) > 0 && (e20Curr - e50Curr) <= 0;
  }

  bool get isRsiBelow40 {
    final r = rsi();
    return r.isNotEmpty && r.last <= 40;
  }

  bool get isMacdBullish {
    final hist = macd()['hist'] ?? [];
    if (hist.length < 2) return false;
    return hist[hist.length - 2] < 0 && hist.last >= 0;
  }

  // EMA20'nin EMA50'yi yukarı kesip en az %0.20 üzerine çıkması
  bool get isEma20AboveEma50WithMargin {
    final e20 = ema(20);
    final e50 = ema(50);
    if (e20.isEmpty || e50.isEmpty) return false;
    final e20Curr = e20.last;
    final e50Curr = e50.last;
    return e20Curr >= e50Curr * 1.002;
  }

  // Fiyatın MA50 ve MA200'ün üzerinde kapanış yapması
  bool get isPriceAboveMa50AndMa200 {
    final ma50 = sma(50);
    final ma200 = sma(200);
    if (ma50.isEmpty || ma200.isEmpty) return false;
    return price > ma50.last && price > ma200.last;
  }

  // EMA durumu (fiyat ile karşılaştırma)
  bool emaAbovePrice(int period) {
    final e = ema(period);
    return e.isNotEmpty && price > e.last;
  }

  // 52 hafta yüksek/düşük (yaklaşık — son 252 günlük veri)
  double get high52w => prices.isEmpty ? 0 : prices.reduce((a, b) => a > b ? a : b);
  double get low52w  => prices.isEmpty ? 0 : prices.reduce((a, b) => a < b ? a : b);

  // Toplam hacim ortalaması
  double get avgVolume {
    if (volumes.isEmpty) return 0;
    return volumes.reduce((a, b) => a + b) / volumes.length;
  }

  // ─────────────────────────────────────────────
  // MUM FORMASYONU ALGORİTMALARI
  // ─────────────────────────────────────────────

  // Yeterli OHLC verisi var mı?
  bool get _hasOhlc =>
      opens.isNotEmpty &&
      highs.isNotEmpty &&
      lows.isNotEmpty &&
      prices.isNotEmpty &&
      opens.length == prices.length;

  // Son N mumun OHLC değerleri
  double _o(int i) => opens.isNotEmpty && i < opens.length ? opens[i] : prices[i];
  double _h(int i) => highs.isNotEmpty && i < highs.length ? highs[i] : prices[i];
  double _l(int i) => lows.isNotEmpty && i < lows.length ? lows[i] : prices[i];
  double _c(int i) => prices[i];

  // ── Hammer ────────────────────────────────────────────────────────────────
  // Koşullar:
  //  - Alt gölge ≥ gövdenin 2 katı
  //  - Üst gölge ≤ gövdenin %30'u
  //  - Küçük bir gerçek gövde var
  //  - Son 5 mumda düşüş eğilimi mevcut
  bool get isHammer {
    if (!_hasOhlc || prices.length < 6) return false;
    final i = prices.length - 1;
    final o = _o(i), c = _c(i), h = _h(i), l = _l(i);
    final body     = (c - o).abs();
    final upperShadow = h - (c > o ? c : o);
    final lowerShadow = (c > o ? o : c) - l;
    final totalRange  = h - l;
    if (totalRange <= 0 || body <= 0) return false;
    final isHammerShape = lowerShadow >= body * 2.0 &&
        upperShadow <= body * 0.3;
    // Son 5 mumda düşüş
    final trend = prices[i - 1] < prices[i - 5];
    return isHammerShape && trend;
  }

  // ── Doji ──────────────────────────────────────────────────────────────────
  // Koşul: |kapanış - açılış| ≤ toplam aralığın %10'u
  bool get isDoji {
    if (!_hasOhlc || prices.isEmpty) return false;
    final i = prices.length - 1;
    final o = _o(i), c = _c(i), h = _h(i), l = _l(i);
    final body      = (c - o).abs();
    final totalRange = h - l;
    if (totalRange <= 0) return false;
    return body / totalRange <= 0.10;
  }

  // ── Morning Star (Sabah Yıldızı) ─────────────────────────────────────────
  // 3 mum formasyonu:
  //  1. Büyük kırmızı mum (bearish)
  //  2. Küçük gövdeli mum (doji/spinning top) — gap down
  //  3. Büyük yeşil mum (bullish), ilk mumun ortasını geçiyor
  bool get isMorningStar {
    if (!_hasOhlc || prices.length < 4) return false;
    final n = prices.length - 1;
    // 3. mum (son)
    final o3 = _o(n), c3 = _c(n);
    // 2. mum (orta)
    final o2 = _o(n - 1), c2 = _c(n - 1);
    // 1. mum (ilk)
    final o1 = _o(n - 2), c1 = _c(n - 2);

    final body1 = (c1 - o1).abs();
    final body2 = (c2 - o2).abs();
    final body3 = (c3 - o3).abs();

    final isBearish1 = c1 < o1;          // 1. mum kırmızı
    final isSmall2   = body2 < body1 * 0.4; // 2. mum küçük
    final isBullish3 = c3 > o3;          // 3. mum yeşil
    final closes3    = c3 > (o1 + c1) / 2; // 3. mum 1. mumun ortasını geçiyor

    return isBearish1 && isSmall2 && isBullish3 && closes3 && body1 > 0 && body3 > 0;
  }

  // ── Bullish Engulfing (Boğa Yutan) ───────────────────────────────────────
  // Önceki mum kırmızı (bearish), sonraki mum yeşil (bullish) ve tamamen yutar
  bool get isBullishEngulfing {
    if (!_hasOhlc || prices.length < 3) return false;
    final i = prices.length - 1;
    final prevO = _o(i - 1), prevC = _c(i - 1);
    final currO = _o(i),     currC = _c(i);

    final prevBearish = prevC < prevO;
    final currBullish = currC > currO;
    // Yeşil mum kırmızıyı tamamen yutuyor
    final engulfs = currO <= prevC && currC >= prevO;

    // Son 5 mumda düşüş eğilimi
    final downtrend = prices.length >= 6 && prices[i - 1] < prices[i - 5];

    return prevBearish && currBullish && engulfs && downtrend;
  }

  // ── Bearish Engulfing (Ayı Yutan) ────────────────────────────────────────
  // Önceki mum yeşil (bullish), sonraki mum kırmızı (bearish) ve tamamen yutar
  bool get isBearishEngulfing {
    if (!_hasOhlc || prices.length < 3) return false;
    final i = prices.length - 1;
    final prevO = _o(i - 1), prevC = _c(i - 1);
    final currO = _o(i),     currC = _c(i);

    final prevBullish = prevC > prevO;
    final currBearish = currC < currO;
    // Kırmızı mum yeşili tamamen yutuyor
    final engulfs = currO >= prevC && currC <= prevO;

    // Son 5 mumda yükseliş eğilimi
    final uptrend = prices.length >= 6 && prices[i - 1] > prices[i - 5];

    return prevBullish && currBearish && engulfs && uptrend;
  }
}
