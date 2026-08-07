import 'package:flutter_test/flutter_test.dart';
import 'package:teknik_bakis/services/notification_service.dart';

void main() {
  test('Android bildirim kanalları fiyat ve sinyal alarmı için tanımlı olmalı', () {
    final channels = NotificationService.androidChannels;

    expect(channels, hasLength(2));
    expect(channels.any((channel) => channel.id == 'price_alerts'), isTrue);
    expect(channels.any((channel) => channel.id == 'signals'), isTrue);
    expect(channels.first.name, 'Fiyat Alarmları');
  });
}
