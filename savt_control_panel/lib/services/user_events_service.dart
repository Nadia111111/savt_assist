import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';
import 'token_storage.dart';
import 'db_service.dart';

class UserEventsService {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isIntentionallyClosed = false;
  void Function()? onCabinetCreated;

  WebSocketChannel? _telemetryChannel;
  Timer? _telemetryReconnectTimer;
  Timer? _telemetryPingTimer;
  bool _isTelemetryIntentionallyClosed = false;
  int? _telemetryCabinetId;
  void Function(int cabinetId)? onTelemetryCreated;

  UserEventsService(this._apiClient, this._tokenStorage);

  Future<String?> _fetchTicket() async {
    try {
      final response = await _apiClient.dio.post('/user-events/ticket');
      final data = response.data as Map<String, dynamic>;
      return data['ticket']?.toString();
    } on Exception catch (e) {
      debugPrint('❌ [UserEvents] Failed to fetch ticket: $e');
      return null;
    }
  }

  Future<void> start() async {
    await stop();
    _isIntentionallyClosed = false;
    await _connect();
  }

  Future<void> stop() async {
    _isIntentionallyClosed = true;
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> _connect() async {
    if (_isIntentionallyClosed) return;

    final token = await _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('⚠️ [UserEvents] No access token, skip WS connect');
      return;
    }

    final ticket = await _fetchTicket();
    if (ticket == null || ticket.isEmpty) {
      debugPrint('⚠️ [UserEvents] Ticket is empty');
      _scheduleReconnect();
      return;
    }

    try {
      final wsUrl = '${ApiClient.baseUrl}/user-events/cabinets'
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl).replace(queryParameters: {'ticket': ticket}));
      _channel = channel;
      _pingTimer?.cancel();
      _pingTimer = Timer(const Duration(seconds: 25), () {
        if (_channel != null) {
          debugPrint('⏱️ [UserEvents] No ping for 25s, reconnect');
          _channel?.sink.close();
          _channel = null;
          _scheduleReconnect();
        }
      });

      channel.stream.listen(
        (raw) {
          _pingTimer?.cancel();
          _pingTimer = Timer(const Duration(seconds: 25), () {
            if (_channel != null) {
              debugPrint('⏱️ [UserEvents] No ping for 25s, reconnect');
              _channel?.sink.close();
              _channel = null;
              _scheduleReconnect();
            }
          });

          try {
            final event = jsonDecode(raw as String) as Map<String, dynamic>;
            final type = event['type']?.toString();
            if (type == 'ping') {
              debugPrint('🏓 [UserEvents] ping');
              return;
            }
            if (type == 'connected') {
              debugPrint('✅ [UserEvents] connected');
              return;
            }
            if (type == 'cabinet.created') {
              debugPrint('🆕 [UserEvents] cabinet.created: ${event['cabinet_id']}');
              DbService.instance.clearCabinetCache().catchError((_) {});
              onCabinetCreated?.call();
            }
          } on Exception catch (e) {
            debugPrint('❌ [UserEvents] parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ [UserEvents] stream error: $error');
          if (!_isIntentionallyClosed) {
            _scheduleReconnect();
          }
        },
        onDone: () {
          debugPrint('ℹ️ [UserEvents] stream closed');
          if (!_isIntentionallyClosed) {
            _scheduleReconnect();
          }
        },
      );
    } on Exception catch (e) {
      debugPrint('❌ [UserEvents] connect error: $e');
      if (!_isIntentionallyClosed) {
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _connect();
    });
  }

  Future<void> startTelemetry(int cabinetId) async {
    await stopTelemetry();
    _isTelemetryIntentionallyClosed = false;
    _telemetryCabinetId = cabinetId;
    await _connectTelemetry(cabinetId);
  }

  Future<void> stopTelemetry() async {
    _isTelemetryIntentionallyClosed = true;
    _telemetryCabinetId = null;
    _telemetryPingTimer?.cancel();
    _telemetryPingTimer = null;
    _telemetryReconnectTimer?.cancel();
    _telemetryReconnectTimer = null;
    await _telemetryChannel?.sink.close();
    _telemetryChannel = null;
  }

  Future<void> _connectTelemetry(int cabinetId) async {
    if (_isTelemetryIntentionallyClosed) return;

    final token = await _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('⚠️ [UserEvents] No access token, skip telemetry WS connect');
      return;
    }

    final ticket = await _fetchTicket();
    if (ticket == null || ticket.isEmpty) {
      debugPrint('⚠️ [UserEvents] Ticket is empty for telemetry');
      _scheduleTelemetryReconnect();
      return;
    }

    try {
      final wsUrl = '${ApiClient.baseUrl}/user-events/cabinets/$cabinetId/telemetry'
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl).replace(queryParameters: {'ticket': ticket}));
      _telemetryChannel = channel;
      _telemetryPingTimer?.cancel();
      _telemetryPingTimer = Timer(const Duration(seconds: 25), () {
        if (_telemetryChannel != null) {
          debugPrint('⏱️ [UserEvents] No telemetry ping for 25s, reconnect');
          _telemetryChannel?.sink.close();
          _telemetryChannel = null;
          _scheduleTelemetryReconnect();
        }
      });

      channel.stream.listen(
        (raw) {
          _telemetryPingTimer?.cancel();
          _telemetryPingTimer = Timer(const Duration(seconds: 25), () {
            if (_telemetryChannel != null) {
              debugPrint('⏱️ [UserEvents] No telemetry ping for 25s, reconnect');
              _telemetryChannel?.sink.close();
              _telemetryChannel = null;
              _scheduleTelemetryReconnect();
            }
          });

          try {
            final event = jsonDecode(raw as String) as Map<String, dynamic>;
            final type = event['type']?.toString();
            if (type == 'ping') {
              debugPrint('🏓 [UserEvents] telemetry ping');
              return;
            }
            if (type == 'connected') {
              debugPrint('✅ [UserEvents] telemetry connected');
              return;
            }
            if (type == 'telemetry.created') {
              debugPrint('🆕 [UserEvents] telemetry.created: ${event['cabinet_id']}');
              onTelemetryCreated?.call(cabinetId);
            }
          } on Exception catch (e) {
            debugPrint('❌ [UserEvents] telemetry parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ [UserEvents] telemetry stream error: $error');
          if (!_isTelemetryIntentionallyClosed) {
            _scheduleTelemetryReconnect();
          }
        },
        onDone: () {
          debugPrint('ℹ️ [UserEvents] telemetry stream closed');
          if (!_isTelemetryIntentionallyClosed) {
            _scheduleTelemetryReconnect();
          }
        },
      );
    } on Exception catch (e) {
      debugPrint('❌ [UserEvents] telemetry connect error: $e');
      if (!_isTelemetryIntentionallyClosed) {
        _scheduleTelemetryReconnect();
      }
    }
  }

  void _scheduleTelemetryReconnect() {
    _telemetryReconnectTimer?.cancel();
    _telemetryReconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_telemetryCabinetId != null && !_isTelemetryIntentionallyClosed) {
        _connectTelemetry(_telemetryCabinetId!);
      }
    });
  }
}
