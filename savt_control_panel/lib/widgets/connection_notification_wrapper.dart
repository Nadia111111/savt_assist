// lib/widgets/connection_notification_wrapper.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/network_service.dart';
import '../services/offline_service.dart';

class ConnectionNotificationWrapper extends StatefulWidget {
  final Widget child;
  const ConnectionNotificationWrapper({super.key, required this.child});

  @override
  State<ConnectionNotificationWrapper> createState() =>
      _ConnectionNotificationWrapperState();
}

class _ConnectionNotificationWrapperState
    extends State<ConnectionNotificationWrapper> {
  bool _lastStatus = true;
  bool _showToast = false;
  bool _isToastOnline = true;
  bool _hasShownOffline = false;
  Timer? _dismissTimer;
  String? _syncMessage;
  Timer? _syncDismissTimer;

  @override
  void initState() {
    super.initState();
    _lastStatus = NetworkService.isOnline;
    NetworkService.isOnlineNotifier.addListener(_onConnectionChanged);
    OfflineService.syncConflictNotifier.addListener(_onSyncConflict);
    OfflineService.queueLimitNotifier.addListener(_onQueueLimit);
    OfflineService.syncedCountNotifier.addListener(_onSynced);
  }

  @override
  void dispose() {
    NetworkService.isOnlineNotifier.removeListener(_onConnectionChanged);
    OfflineService.syncConflictNotifier.removeListener(_onSyncConflict);
    OfflineService.queueLimitNotifier.removeListener(_onQueueLimit);
    OfflineService.syncedCountNotifier.removeListener(_onSynced);
    _dismissTimer?.cancel();
    _syncDismissTimer?.cancel();
    super.dispose();
  }

  void _onSyncConflict() {
    final msg = OfflineService.syncConflictNotifier.value;
    if (msg != null && mounted) {
      setState(() {
        _syncMessage = msg;
      });
      _syncDismissTimer?.cancel();
      _syncDismissTimer = Timer(const Duration(milliseconds: 4000), () {
        if (mounted) {
          setState(() {
            _syncMessage = null;
          });
        }
      });
    }
  }

  void _onQueueLimit() {
    final msg = OfflineService.queueLimitNotifier.value;
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Очистить',
            textColor: Colors.white,
            onPressed: () async {
              await OfflineService().clearAllQueues();
            },
          ),
        ),
      );
    }
  }

  void _onSynced() {
    final count = OfflineService.syncedCountNotifier.value;
    if (count > 0 && mounted) {
      setState(() {
        _syncMessage = 'Отправлено $count отложенных действий';
      });
      _syncDismissTimer?.cancel();
      _syncDismissTimer = Timer(const Duration(milliseconds: 4000), () {
        if (mounted) {
          setState(() {
            _syncMessage = null;
          });
          OfflineService.syncedCountNotifier.value = 0;
        }
      });
    }
  }

  void _onConnectionChanged() {
    final newStatus = NetworkService.isOnline;
    if (newStatus != _lastStatus) {
      _dismissTimer?.cancel();

      bool shouldShow = true;
      if (newStatus) {
        // We went online. Only show toast if we previously showed the offline toast.
        shouldShow = _hasShownOffline;
        _hasShownOffline = false;
      } else {
        // We went offline. Mark that we've shown offline.
        _hasShownOffline = true;
      }

      setState(() {
        _lastStatus = newStatus;
        _isToastOnline = newStatus;
        _showToast = shouldShow;
      });

      if (shouldShow) {
        // Dismiss toast after 3.5 seconds
        _dismissTimer = Timer(const Duration(milliseconds: 3500), () {
          if (mounted) {
            setState(() {
              _showToast = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Toast для синхронизации и конфликтов
        if (_syncMessage != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 40,
            child: Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.horizontal,
              onDismissed: (_) {
                _syncDismissTimer?.cancel();
                setState(() {
                  _syncMessage = null;
                });
                OfflineService.syncedCountNotifier.value = 0;
              },
              child: Material(
                color: Colors.transparent,
                child: AnimatedOpacity(
                  opacity: _syncMessage != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade800,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _syncMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Toast для online/offline статуса (убирается свайпом влево или вправо)
        if (_showToast)
          Positioned(
            left: 16,
            right: 16,
            bottom: 40,
            child: Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.horizontal,
              onDismissed: (_) {
                _dismissTimer?.cancel();
                setState(() {
                  _showToast = false;
                });
              },
              child: Material(
                color: Colors.transparent,
                child: AnimatedOpacity(
                  opacity: _showToast ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isToastOnline
                          ? const Color(0xFF10B981)
                          : Colors.orange.shade800,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isToastOnline ? Icons.wifi : Icons.wifi_off,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isToastOnline
                                ? 'Подключение восстановлено. Вы снова в сети!'
                                : 'Соединение потеряно. Переход в оффлайн-режим.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
