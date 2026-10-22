// lib/services/user_events_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';
import 'token_storage.dart';
import 'db_service.dart';

enum TicketStatus {
  success,
  forbidden, // HTTP 403: права отозваны -> прекратить переподключение
  error,     // Ошибка сети или сервера -> повторить попытку
}

class TicketResponse {
  final TicketStatus status;
  final String? ticket;
  final String? error;

  const TicketResponse.success(this.ticket)
      : status = TicketStatus.success,
        error = null;
  const TicketResponse.forbidden([this.error])
      : status = TicketStatus.forbidden,
        ticket = null;
  const TicketResponse.error([this.error])
      : status = TicketStatus.error,
        ticket = null;

  bool get isSuccess =>
      status == TicketStatus.success && ticket != null && ticket!.isNotEmpty;
  bool get isForbidden => status == TicketStatus.forbidden;
}

class UserEventsService {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isIntentionallyClosed = false;
  bool _isAccessRevoked = false;
  bool get isAccessRevoked => _isAccessRevoked;

  void Function()? onCabinetCreated;
  void Function()? onAccessRevoked;

  WebSocketChannel? _telemetryChannel;
  Timer? _telemetryReconnectTimer;
  Timer? _telemetryPingTimer;
  bool _isTelemetryIntentionallyClosed = false;
  bool _isTelemetryAccessRevoked = false;
  bool get isTelemetryAccessRevoked => _isTelemetryAccessRevoked;
  int? _telemetryCabinetId;

  void Function(int cabinetId)? onTelemetryCreated;
  void Function(int cabinetId)? onTelemetryAccessRevoked;

  UserEventsService(this._apiClient, this._tokenStorage);

  /// Запрос тикета для подключения к сокету/SSE.
  /// При статусе 403 возвращает TicketResponse.forbidden, сигнализируя об отзыве прав.
  Future<TicketResponse> fetchTicket({String endpoint = '/user-events/ticket'}) async {
    try {
      final response = await _apiClient.dio.post(endpoint);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final ticket = data['ticket']?.toString();
        if (ticket != null && ticket.isNotEmpty) {
          return TicketResponse.success(ticket);
        }
      }
      return const TicketResponse.error('Получен пустой билет');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      debugPrint('❌ [UserEvents] Ошибка получения билета ($statusCode): ${e.message}');
      if (statusCode == 403) {
        return TicketResponse.forbidden(
            e.response?.data?.toString() ?? 'Доступ запрещен (403)');
      }
      return TicketResponse.error(e.message ?? 'Ошибка сети');
    } catch (e) {
      debugPrint('❌ [UserEvents] Неизвестная ошибка получения билета: $e');
      return TicketResponse.error(e.toString());
    }
  }

  Future<void> start() async {
    await stop();
    _isIntentionallyClosed = false;
    _isAccessRevoked = false;
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

  void _resetPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer(const Duration(seconds: 25), () {
      if (_channel != null) {
        debugPrint('⏱️ [UserEvents] Нет ping 25с, переподключение');
        _channel?.sink.close();
        _channel = null;
        _scheduleReconnect();
      }
    });
  }

  Future<void> _connect() async {
    if (_isIntentionallyClosed || _isAccessRevoked) return;

    final token = await _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('⚠️ [UserEvents] Нет access token, пропуск подключения к сокету');
      return;
    }

    final ticketRes = await fetchTicket();
    if (ticketRes.isForbidden) {
      debugPrint('🚫 [UserEvents] 403 при получении билета. Права отозваны: прекращаем переподключение.');
      _isAccessRevoked = true;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      onAccessRevoked?.call();
      return;
    }

    if (!ticketRes.isSuccess) {
      debugPrint('⚠️ [UserEvents] Билет не получен (${ticketRes.error}), планируем переподключение');
      _scheduleReconnect();
      return;
    }

    final ticket = ticketRes.ticket!;
    try {
      final wsUrl = '${ApiClient.baseUrl}/user-events/cabinets'
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final channel = WebSocketChannel.connect(
          Uri.parse(wsUrl).replace(queryParameters: {'ticket': ticket}));
      _channel = channel;
      _resetPingTimer();

      channel.stream.listen(
        (raw) {
          _resetPingTimer();
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
          if (!_isIntentionallyClosed && !_isAccessRevoked) {
            _handleDisconnection(channel);
          }
        },
        onDone: () {
          final closeCode = channel.closeCode;
          final closeReason = channel.closeReason;
          debugPrint('ℹ️ [UserEvents] stream closed: code=$closeCode, reason=$closeReason');
          if (!_isIntentionallyClosed && !_isAccessRevoked) {
            _handleDisconnection(channel);
          }
        },
      );
    } on Exception catch (e) {
      debugPrint('❌ [UserEvents] connect error: $e');
      if (!_isIntentionallyClosed && !_isAccessRevoked) {
        _scheduleReconnect();
      }
    }
  }

  void _handleDisconnection(WebSocketChannel channel) async {
    final closeCode = channel.closeCode;
    debugPrint('ℹ️ [UserEvents] Обработка разрыва соединения сокета (closeCode=$closeCode)');

    // При отзыве прав сокет закроется кодом 4401 или 4403.
    // Клиент должен запросить новый билет, а если тот вернёт 403, перестать переподключаться.
    if (closeCode == 4401 || closeCode == 4403) {
      debugPrint('⚠️ [UserEvents] Сокет закрыт кодом $closeCode (отзыв прав / недействительный билет). Запрашиваем новый билет...');
      final ticketRes = await fetchTicket();
      if (ticketRes.isForbidden) {
        debugPrint('🚫 [UserEvents] Запрос нового билета вернул 403 (Forbidden). Прекращаем переподключение.');
        _isAccessRevoked = true;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        onAccessRevoked?.call();
        return;
      }
      if (ticketRes.isSuccess) {
        debugPrint('🔄 [UserEvents] Новый билет успешно получен, переподключаемся...');
        _connect();
        return;
      }
      _scheduleReconnect();
      return;
    }

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isAccessRevoked || _isIntentionallyClosed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _connect();
    });
  }

  // === ТЕЛЕМЕТРИЯ ШКАФА ===

  Future<void> startTelemetry(int cabinetId) async {
    await stopTelemetry();
    _isTelemetryIntentionallyClosed = false;
    _isTelemetryAccessRevoked = false;
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

  void _resetTelemetryPingTimer() {
    _telemetryPingTimer?.cancel();
    _telemetryPingTimer = Timer(const Duration(seconds: 25), () {
      if (_telemetryChannel != null) {
        debugPrint('⏱️ [UserEvents] Нет telemetry ping 25с, переподключение');
        _telemetryChannel?.sink.close();
        _telemetryChannel = null;
        _scheduleTelemetryReconnect();
      }
    });
  }

  Future<void> _connectTelemetry(int cabinetId) async {
    if (_isTelemetryIntentionallyClosed || _isTelemetryAccessRevoked) return;

    final token = await _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('⚠️ [UserEvents] Нет access token, пропуск телеметрии WS');
      return;
    }

    final ticketRes = await fetchTicket();
    if (ticketRes.isForbidden) {
      debugPrint('🚫 [UserEvents] 403 Forbidden при запросе билета телеметрии (шкаф $cabinetId). Прекращаем переподключение.');
      _isTelemetryAccessRevoked = true;
      _telemetryReconnectTimer?.cancel();
      _telemetryReconnectTimer = null;
      onTelemetryAccessRevoked?.call(cabinetId);
      return;
    }

    if (!ticketRes.isSuccess) {
      debugPrint('⚠️ [UserEvents] Билет телеметрии не получен (${ticketRes.error}), планируем повтор');
      _scheduleTelemetryReconnect();
      return;
    }

    final ticket = ticketRes.ticket!;
    try {
      final wsUrl = '${ApiClient.baseUrl}/user-events/cabinets/$cabinetId/telemetry'
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final channel = WebSocketChannel.connect(
          Uri.parse(wsUrl).replace(queryParameters: {'ticket': ticket}));
      _telemetryChannel = channel;
      _resetTelemetryPingTimer();

      channel.stream.listen(
        (raw) {
          _resetTelemetryPingTimer();
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
          if (!_isTelemetryIntentionallyClosed && !_isTelemetryAccessRevoked) {
            _handleTelemetryDisconnection(channel, cabinetId);
          }
        },
        onDone: () {
          final closeCode = channel.closeCode;
          final closeReason = channel.closeReason;
          debugPrint('ℹ️ [UserEvents] telemetry stream closed: code=$closeCode, reason=$closeReason');
          if (!_isTelemetryIntentionallyClosed && !_isTelemetryAccessRevoked) {
            _handleTelemetryDisconnection(channel, cabinetId);
          }
        },
      );
    } on Exception catch (e) {
      debugPrint('❌ [UserEvents] telemetry connect error: $e');
      if (!_isTelemetryIntentionallyClosed && !_isTelemetryAccessRevoked) {
        _scheduleTelemetryReconnect();
      }
    }
  }

  void _handleTelemetryDisconnection(WebSocketChannel channel, int cabinetId) async {
    final closeCode = channel.closeCode;
    debugPrint('ℹ️ [UserEvents] Обработка разрыва телеметрии (closeCode=$closeCode, шкаф $cabinetId)');

    // При отзыве прав сокет закроется кодом 4401 или 4403.
    // Клиент должен запросить новый билет, а если тот вернёт 403, перестать переподключаться.
    if (closeCode == 4401 || closeCode == 4403) {
      debugPrint('⚠️ [UserEvents] Сокет телеметрии закрыт кодом $closeCode (шкаф $cabinetId). Запрашиваем новый билет...');
      final ticketRes = await fetchTicket();
      if (ticketRes.isForbidden) {
        debugPrint('🚫 [UserEvents] Запрос нового билета вернул 403. Отзыв прав на шкаф $cabinetId: прекращаем переподключение.');
        _isTelemetryAccessRevoked = true;
        _telemetryReconnectTimer?.cancel();
        _telemetryReconnectTimer = null;
        onTelemetryAccessRevoked?.call(cabinetId);
        return;
      }
      if (ticketRes.isSuccess) {
        debugPrint('🔄 [UserEvents] Новый билет получен, переподключаем телеметрию...');
        _connectTelemetry(cabinetId);
        return;
      }
      _scheduleTelemetryReconnect();
      return;
    }

    _scheduleTelemetryReconnect();
  }

  void _scheduleTelemetryReconnect() {
    if (_isTelemetryAccessRevoked || _isTelemetryIntentionallyClosed) return;
    _telemetryReconnectTimer?.cancel();
    _telemetryReconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_telemetryCabinetId != null &&
          !_isTelemetryIntentionallyClosed &&
          !_isTelemetryAccessRevoked) {
        _connectTelemetry(_telemetryCabinetId!);
      }
    });
  }

  // === SSE (Server-Sent Events) Поддержка ===

  /// Создание контроллера SSE потока с автоматическим переподключением:
  /// SSE при переподключении получит 401. Клиент запрашивает новый билет,
  /// а если тот вернёт 403, прекращает переподключаться.
  SseSubscription connectSse({
    required String path,
    String ticketEndpoint = '/user-events/ticket',
    required void Function(Map<String, dynamic> event) onEvent,
    void Function()? onRevoked,
    void Function(dynamic error)? onError,
  }) {
    final subscription = SseSubscription(
      apiClient: _apiClient,
      path: path,
      ticketEndpoint: ticketEndpoint,
      fetchTicketFn: (ep) => fetchTicket(endpoint: ep),
      onEvent: onEvent,
      onRevoked: onRevoked,
      onError: onError,
    );
    subscription.start();
    return subscription;
  }
}

/// Управляемый SSE подписчик, соблюдающий контракт переподключения и отзыва прав
class SseSubscription {
  final ApiClient apiClient;
  final String path;
  final String ticketEndpoint;
  final Future<TicketResponse> Function(String endpoint) fetchTicketFn;
  final void Function(Map<String, dynamic> event) onEvent;
  final void Function()? onRevoked;
  final void Function(dynamic error)? onError;

  bool _isClosed = false;
  bool _isRevoked = false;
  Timer? _reconnectTimer;
  CancelToken? _cancelToken;
  StreamSubscription? _streamSub;

  SseSubscription({
    required this.apiClient,
    required this.path,
    required this.ticketEndpoint,
    required this.fetchTicketFn,
    required this.onEvent,
    this.onRevoked,
    this.onError,
  });

  bool get isClosed => _isClosed;
  bool get isRevoked => _isRevoked;

  void start() {
    _isClosed = false;
    _isRevoked = false;
    _connect();
  }

  void stop() {
    _isClosed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cancelToken?.cancel();
    _cancelToken = null;
    _streamSub?.cancel();
    _streamSub = null;
  }

  Future<void> _connect({String? existingTicket}) async {
    if (_isClosed || _isRevoked) return;

    String? currentTicket = existingTicket;
    if (currentTicket == null) {
      final ticketRes = await fetchTicketFn(ticketEndpoint);
      if (ticketRes.isForbidden) {
        debugPrint('🚫 [SSE] Билет вернул 403 (Forbidden). Прекращаем переподключение.');
        _isRevoked = true;
        _reconnectTimer?.cancel();
        onRevoked?.call();
        return;
      }
      if (!ticketRes.isSuccess) {
        debugPrint('⚠️ [SSE] Не удалось получить билет: ${ticketRes.error}. Повтор...');
        _scheduleReconnect();
        return;
      }
      currentTicket = ticketRes.ticket!;
    }

    _cancelToken = CancelToken();
    try {
      final response = await apiClient.dio.get<ResponseBody>(
        path,
        queryParameters: {'ticket': currentTicket},
        cancelToken: _cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
          },
        ),
      );

      final stream = response.data?.stream;
      if (stream == null) {
        _scheduleReconnect();
        return;
      }

      StringBuffer buffer = StringBuffer();
      _streamSub = stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.isEmpty) {
            // Конец события в SSE
            final dataStr = buffer.toString().trim();
            buffer.clear();
            if (dataStr.isNotEmpty) {
              try {
                final json = jsonDecode(dataStr) as Map<String, dynamic>;
                onEvent(json);
              } catch (_) {}
            }
          } else if (line.startsWith('data:')) {
            buffer.writeln(line.substring(5).trim());
          }
        },
        onError: (err) {
          debugPrint('❌ [SSE] Ошибка потока: $err');
          onError?.call(err);
          _handleDisconnection();
        },
        onDone: () {
          debugPrint('ℹ️ [SSE] Поток завершился');
          _handleDisconnection();
        },
        cancelOnError: true,
      );
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      debugPrint('❌ [SSE] Ошибка соединения ($statusCode): ${e.message}');
      if (statusCode == 401) {
        // SSE при переподключении получит 401. Клиент должен запросить новый билет,
        // а если тот вернёт 403, перестать переподключаться.
        debugPrint('⚠️ [SSE] Получен 401 при подключении. Запрашиваем свежий билет...');
        final freshRes = await fetchTicketFn(ticketEndpoint);
        if (freshRes.isForbidden) {
          debugPrint('🚫 [SSE] Свежий билет вернул 403. Прекращаем переподключение.');
          _isRevoked = true;
          _reconnectTimer?.cancel();
          onRevoked?.call();
          return;
        }
        if (freshRes.isSuccess) {
          _connect(existingTicket: freshRes.ticket);
          return;
        }
      }
      _scheduleReconnect();
    } catch (e) {
      debugPrint('❌ [SSE] Непредвиденная ошибка: $e');
      _scheduleReconnect();
    }
  }

  void _handleDisconnection() async {
    if (_isClosed || _isRevoked) return;
    // При разрыве запрашиваем новый билет, проверяя статус 403
    final freshRes = await fetchTicketFn(ticketEndpoint);
    if (freshRes.isForbidden) {
      debugPrint('🚫 [SSE] Новый билет вернул 403 (права отозваны). Прекращаем переподключение.');
      _isRevoked = true;
      _reconnectTimer?.cancel();
      onRevoked?.call();
      return;
    }
    _scheduleReconnect(existingTicket: freshRes.ticket);
  }

  void _scheduleReconnect({String? existingTicket}) {
    if (_isClosed || _isRevoked) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _connect(existingTicket: existingTicket);
    });
  }
}
