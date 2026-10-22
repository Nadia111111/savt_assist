import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:control_panel/services/user_events_service.dart';
import 'package:control_panel/services/upload_service.dart';
import 'package:control_panel/services/api_client.dart';
import 'package:control_panel/services/token_storage.dart';
import 'package:control_panel/utils/error_handler.dart';

class MockTokenStorage extends TokenStorage {
  String? token = 'valid-token';
  @override
  Future<String?> getAccessToken() async => token;
}

void main() {
  late File tempFile;

  setUp(() async {
    tempFile = File('${Directory.systemTemp.path}/test_upload_${DateTime.now().millisecondsSinceEpoch}.txt');
    await tempFile.writeAsString('test file contents');
  });

  tearDown(() async {
    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {}
  });

  group('Backend Contract: File URLs & Error Handling', () {
    test('ErrorHandler extracts 422 detail message from server response verbatim', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/chats/1/messages'),
        response: Response(
          requestOptions: RequestOptions(path: '/chats/1/messages'),
          statusCode: 422,
          data: {
            'detail': 'Ссылка на файл недействительна: загрузите файл заново',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final msg = ErrorHandler.getUserFriendlyMessage(dioException);
      expect(msg, 'Ссылка на файл недействительна: загрузите файл заново');
    });

    test('UploadService returns signed URL with query signature intact', () async {
      final tokenStorage = MockTokenStorage();
      final apiClient = ApiClient(tokenStorage);

      const signedUrl = '/static/attachments/test.jpg?sig=abc123xyz456&expires=1789000000';

      apiClient.dio.interceptors.insert(0, InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/upload/attachment') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'url': signedUrl},
            ));
          }
          return handler.next(options);
        },
      ));

      final uploadService = UploadService(apiClient);
      final result = await uploadService.uploadAttachment(tempFile.path, compress: false);

      expect(result, signedUrl);
      expect(result.contains('?sig='), isTrue);
      expect(result.contains('&expires='), isTrue);
    });

    test('UploadService uploadVoice returns signed URL verbatim', () async {
      final tokenStorage = MockTokenStorage();
      final apiClient = ApiClient(tokenStorage);

      const signedVoiceUrl = '/static/voice/audio.m4a?sig=voiceSig999&token=abc';

      apiClient.dio.interceptors.insert(0, InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/upload/voice') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'url': signedVoiceUrl},
            ));
          }
          return handler.next(options);
        },
      ));

      final uploadService = UploadService(apiClient);
      final result = await uploadService.uploadVoice(tempFile.path);

      expect(result, signedVoiceUrl);
      expect(result.contains('sig=voiceSig999'), isTrue);
    });
  });

  group('Backend Contract: Real-time Ticket, WebSocket & SSE Rights Revocation', () {
    test('Ticket request returning 403 sets status to forbidden', () async {
      final tokenStorage = MockTokenStorage();
      final apiClient = ApiClient(tokenStorage);

      apiClient.dio.interceptors.insert(0, InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/user-events/ticket') {
            return handler.reject(DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 403,
                data: {'detail': 'Права доступа отозваны'},
              ),
              type: DioExceptionType.badResponse,
            ));
          }
          return handler.next(options);
        },
      ));

      final service = UserEventsService(apiClient, tokenStorage);
      final res = await service.fetchTicket();

      expect(res.isForbidden, isTrue);
      expect(res.status, TicketStatus.forbidden);
    });

    test('When ticket returns 403, start() marks isAccessRevoked and stops reconnecting', () async {
      final tokenStorage = MockTokenStorage();
      final apiClient = ApiClient(tokenStorage);

      apiClient.dio.interceptors.insert(0, InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/user-events/ticket') {
            return handler.reject(DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 403,
                data: {'detail': 'Forbidden'},
              ),
              type: DioExceptionType.badResponse,
            ));
          }
          return handler.next(options);
        },
      ));

      final service = UserEventsService(apiClient, tokenStorage);
      bool revokedCallbackCalled = false;
      service.onAccessRevoked = () {
        revokedCallbackCalled = true;
      };

      await service.start();

      expect(service.isAccessRevoked, isTrue);
      expect(revokedCallbackCalled, isTrue);
    });

    test('When telemetry ticket returns 403, startTelemetry marks isTelemetryAccessRevoked and stops reconnecting', () async {
      final tokenStorage = MockTokenStorage();
      final apiClient = ApiClient(tokenStorage);

      apiClient.dio.interceptors.insert(0, InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/user-events/ticket') {
            return handler.reject(DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 403,
                data: {'detail': 'Forbidden'},
              ),
              type: DioExceptionType.badResponse,
            ));
          }
          return handler.next(options);
        },
      ));

      final service = UserEventsService(apiClient, tokenStorage);
      int? revokedCabinetId;
      service.onTelemetryAccessRevoked = (cabId) {
        revokedCabinetId = cabId;
      };

      await service.startTelemetry(42);

      expect(service.isTelemetryAccessRevoked, isTrue);
      expect(revokedCabinetId, 42);
    });

    test('SSE subscription stops reconnecting when ticket returns 403 on reconnect', () async {
      final tokenStorage = MockTokenStorage();
      final apiClient = ApiClient(tokenStorage);

      int ticketCallCount = 0;
      apiClient.dio.interceptors.insert(0, InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/operator/events/ticket') {
            ticketCallCount++;
            if (ticketCallCount == 1) {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {'ticket': 'valid-ticket-1'},
              ));
            } else {
              // Revoked on reconnect
              return handler.reject(DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 403,
                  data: {'detail': 'Forbidden'},
                ),
                type: DioExceptionType.badResponse,
              ));
            }
          }
          if (options.path == '/operator/events/chats') {
            // Emulate 401 when rights were revoked
            return handler.reject(DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 401,
                data: {'detail': 'Unauthorized'},
              ),
              type: DioExceptionType.badResponse,
            ));
          }
          return handler.next(options);
        },
      ));

      final service = UserEventsService(apiClient, tokenStorage);
      bool sseRevokedCalled = false;

      final sub = service.connectSse(
        path: '/operator/events/chats',
        ticketEndpoint: '/operator/events/ticket',
        onEvent: (_) {},
        onRevoked: () {
          sseRevokedCalled = true;
        },
      );

      // Allow async reconnect cycle to run
      await Future.delayed(const Duration(milliseconds: 100));

      expect(sub.isRevoked, isTrue);
      expect(sseRevokedCalled, isTrue);
      sub.stop();
    });
  });
}
