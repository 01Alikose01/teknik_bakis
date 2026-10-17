import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Bağlantı durumunu dinler ve değişimleri yayar.
class ConnectivityService {
  ConnectivityService._();

  static final ValueNotifier<bool> isOnline = ValueNotifier(true);
  static StreamSubscription? _sub;

  static Future<void> init() async {
    // İlk durumu belirle
    final result = await Connectivity().checkConnectivity();
    isOnline.value = _hasConnection(result);

    // Değişimleri dinle
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = _hasConnection(results);
      if (online != isOnline.value) {
        isOnline.value = online;
      }
    });
  }

  static bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
