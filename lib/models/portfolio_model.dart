import 'package:hive/hive.dart';

part 'portfolio_model.g.dart';

@HiveType(typeId: 0)
class PortfolioItem extends HiveObject {
  @HiveField(0)
  String symbol;

  @HiveField(1)
  String name;

  @HiveField(2)
  double buyPrice;

  @HiveField(3)
  double quantity;

  @HiveField(4)
  DateTime buyDate;

  PortfolioItem({
    required this.symbol,
    required this.name,
    required this.buyPrice,
    required this.quantity,
    required this.buyDate,
  });

  double profit(double currentPrice) => (currentPrice - buyPrice) * quantity;
  double profitPercent(double currentPrice) =>
      buyPrice > 0 ? ((currentPrice - buyPrice) / buyPrice) * 100 : 0;
  double totalCost() => buyPrice * quantity;
  double totalValue(double currentPrice) => currentPrice * quantity;
}

@HiveType(typeId: 1)
class WatchlistItem extends HiveObject {
  @HiveField(0)
  String symbol;

  @HiveField(1)
  String name;

  @HiveField(2)
  double? alertPrice;

  @HiveField(3)
  bool alertAbove; // true = fiyat üstüne geçince, false = altına düşünce

  @HiveField(4)
  String alertType; // 'buy' = Alış Alarmı, 'sell' = Satış Alarmı, 'price' = Fiyat Alarmı

  WatchlistItem({
    required this.symbol,
    required this.name,
    this.alertPrice,
    this.alertAbove = true,
    this.alertType = 'price',
  });
}

@HiveType(typeId: 2)
class AlarmItem extends HiveObject {
  @HiveField(0)
  String symbol;

  @HiveField(1)
  String name;

  @HiveField(2)
  double alertPrice;

  @HiveField(3)
  bool alertAbove;

  @HiveField(4)
  String alertType; // 'buy' = Alış Alarmı, 'sell' = Satış Alarmı, 'price' = Fiyat Alarmı

  @HiveField(5)
  DateTime createdAt;

  AlarmItem({
    required this.symbol,
    required this.name,
    required this.alertPrice,
    this.alertAbove = true,
    this.alertType = 'price',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
