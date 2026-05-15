// lib/services/network_service.dart
import 'package:flutter/material.dart';

class NetworkService {
  static final ValueNotifier<bool> isOnlineNotifier = ValueNotifier(true);

  static bool get isOnline => isOnlineNotifier.value;
}
