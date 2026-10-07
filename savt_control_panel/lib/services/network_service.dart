// lib/services/network_service.dart
import 'package:flutter/material.dart';

class NetworkService {
  static final ValueNotifier<bool> isOnlineNotifier = ValueNotifier(true);

  static bool get isOnline => isOnlineNotifier.value;

  static void setOnline(bool online) {
    if (isOnlineNotifier.value != online) {
      isOnlineNotifier.value = online;
    }
  }
}
