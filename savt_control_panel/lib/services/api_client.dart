// lib/services/api_client.dart
import 'dart:async';
import 'package:flutter/widgets.dart'; // <-- ДОБАВИТЬ ЭТОТ ИМПОРТ
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'token_storage.dart';
import 'network_service.dart';
import '../main.dart';

class ApiClient {
  static const String baseUrl = 'https://helper.savt.by';
  static const String apiPrefix = '';
  static DateTime? _lastAuthRedirect;

  final Dio _dio;
  final TokenStorage _tokenStorage;
  bool _isRefreshing = false;
  final List<
      ({
        void Function(String token) resolve,
        void Function(DioException error) reject,
      })> _queue = [];

  ApiClient(this._tokenStorage)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (!kIsWeb) 'User-Agent': 'SAVT-Assist/1.0',
          },
          validateStatus: (status) {
            return status != null && status < 300;
          },
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (apiPrefix.isNotEmpty && !options.path.startsWith(apiPrefix)) {
          options.path = '$apiPrefix${options.path}';
        }

        final token = await _tokenStorage.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        print('🔵 [API] ${options.method} ${options.uri}');
        if (options.data != null) {
          print('📦 [API] Data: ${options.data}');
        }

        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('🟢 [API] ${response.statusCode} ${response.requestOptions.uri}');
        return handler.next(response);
      },
      onError: (error, handler) async {
        print('🔴 [API] Error: ${error.type} - ${error.message}');
        if (error.response != null) {
          print('🔴 [API] Status: ${error.response?.statusCode}');
          print('🔴 [API] Data: ${error.response?.data}');
        }

        if (error.response?.statusCode == 404) {
          print('⚠️ [API] Endpoint not found (404)');
          final emptyResponse = Response(
            requestOptions: error.requestOptions,
            statusCode: 404,
            data: {'error': 'Endpoint not found', 'status': 404},
          );
          return handler.resolve(emptyResponse);
        }

        if (error.type == DioExceptionType.connectionError) {
          print('Network connection error: ${error.message}');
          NetworkService.setOnline(false);
        } else if (error.type == DioExceptionType.unknown) {
          final errMsg = error.message?.toLowerCase() ?? '';
          if (errMsg.contains('network') ||
              errMsg.contains('connection') ||
              errMsg.contains('socket') ||
              errMsg.contains('host') ||
              errMsg.contains('unreachable') ||
              errMsg.contains('refused')) {
            print('Network-related unknown error: ${error.message}');
            NetworkService.setOnline(false);
          } else {
            NetworkService.setOnline(true);
          }
        } else {
          NetworkService.setOnline(true);
        }

        if (error.response?.statusCode == 401) {
          final path = error.requestOptions.path;
          final isAuthEndpoint = path.contains('/auth/login') ||
                                 path.contains('/auth/register/start') ||
                                 path.contains('/auth/register/complete') ||
                                 path.contains('/auth/admin-login') ||
                                 path.contains('/auth/guest');

          if (isAuthEndpoint || path.contains('/auth/refresh')) {
            await _tokenStorage.clearTokens();
            _redirectToAuth();
            return handler.next(error);
          }

          if (_tokenStorage.isGuestMode) {
            return handler.next(error);
          }

          if (!_isRefreshing) {
            _isRefreshing = true;
            bool refreshSucceeded = false;
            try {
              final refreshToken = await _tokenStorage.getRefreshToken();
              if (refreshToken == null || refreshToken.isEmpty) {
                throw Exception('No refresh token');
              }

              print('🔄 [API] Refreshing token...');
              final response = await _dio.post(
                '/auth/refresh',
                data: {'refresh_token': refreshToken},
                options: Options(headers: {'Authorization': null}),
              );

              refreshSucceeded = true;
              final newAccess = response.data['access_token'] as String;
              final newRefresh = response.data['refresh_token'] as String;
              await _tokenStorage.saveTokens(newAccess, newRefresh);

              for (final entry in _queue) {
                entry.resolve(newAccess);
              }
              _queue.clear();

              final newOptions = error.requestOptions;
              newOptions.headers['Authorization'] = 'Bearer $newAccess';
              final retryResponse = await _dio.fetch(newOptions);
              _isRefreshing = false;
              return handler.resolve(retryResponse);
            } catch (e) {
              _isRefreshing = false;
              for (final entry in _queue) {
                entry.reject(error);
              }
              _queue.clear();

              if (!refreshSucceeded) {
                await _tokenStorage.clearTokens();
                _redirectToAuth();
              }
              return handler.next(error);
            }
          } else {
            final completer = Completer<String>();
            _queue.add((
              resolve: (token) => completer.complete(token),
              reject: (err) => completer.completeError(err),
            ));
            try {
              final newToken = await completer.future;
              final newOptions = error.requestOptions;
              newOptions.headers['Authorization'] = 'Bearer $newToken';
              final retryResponse = await _dio.fetch(newOptions);
              return handler.resolve(retryResponse);
            } catch (e) {
              return handler.next(error);
            }
          }
        }

        return handler.next(error);
      },
    ));
  }

  void _redirectToAuth() {
    try {
      final now = DateTime.now();
      if (_lastAuthRedirect == null || now.difference(_lastAuthRedirect!).inSeconds > 2) {
        _lastAuthRedirect = now;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final navigator = ControlPanelApp.navigatorKey.currentState;
          if (navigator != null && navigator.mounted) {
            navigator.pushNamedAndRemoveUntil('/auth', (route) => false);
          }
        });
      }
    } catch (e) {
      print('⚠️ [API] Error during navigation to auth: $e');
    }
  }

  Dio get dio => _dio;
}