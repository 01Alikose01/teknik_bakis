// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'portfolio_model.dart';

class PortfolioItemAdapter extends TypeAdapter<PortfolioItem> {
  @override
  final int typeId = 0;

  @override
  PortfolioItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PortfolioItem(
      symbol: fields[0] as String,
      name: fields[1] as String,
      buyPrice: fields[2] as double,
      quantity: fields[3] as double,
      buyDate: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PortfolioItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.symbol)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.buyPrice)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.buyDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PortfolioItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WatchlistItemAdapter extends TypeAdapter<WatchlistItem> {
  @override
  final int typeId = 1;

  @override
  WatchlistItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WatchlistItem(
      symbol: fields[0] as String,
      name: fields[1] as String,
      alertPrice: fields[2] as double?,
      alertAbove: fields[3] as bool,
      alertType: fields[4] as String? ?? 'price',
    );
  }

  @override
  void write(BinaryWriter writer, WatchlistItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.symbol)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.alertPrice)
      ..writeByte(3)
      ..write(obj.alertAbove)
      ..writeByte(4)
      ..write(obj.alertType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchlistItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AlarmItemAdapter extends TypeAdapter<AlarmItem> {
  @override
  final int typeId = 2;

  @override
  AlarmItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AlarmItem(
      symbol: fields[0] as String,
      name: fields[1] as String,
      alertPrice: fields[2] as double,
      alertAbove: fields[3] as bool,
      alertType: fields[4] as String,
      createdAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AlarmItem obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.symbol)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.alertPrice)
      ..writeByte(3)
      ..write(obj.alertAbove)
      ..writeByte(4)
      ..write(obj.alertType)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlarmItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
