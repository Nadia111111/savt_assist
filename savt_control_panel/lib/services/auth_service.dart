// lib/services/auth_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'token_storage.dart';
import 'push_service.dart';
import 'offline_service.dart';
import 'db_service.dart';
import '../main.dart';

class AuthService {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  Map<String, dynamic>? _cachedMe;
  DateTime? _cachedMeAt;
  static const _meCacheTTL = Duration(seconds: 10);

  AuthService(this._apiClient, this._tokenStorage);

  Future<Map<String, dynamic>> registerStart({
    required String password,
    required String fullName,
    required String userType,
    String? organizationName,
    String? contactPhone,
  }) async {
    try {
      final response = await _apiClient.dio.post('/auth/register/start', data: {
        'password': password,
        'password_confirm': password,
        'full_name': fullName,
        'user_type': userType,
        if (organizationName != null) 'organization_name': organizationName,
        if (contactPhone != null && contactPhone.isNotEmpty) 'contact_phone': contactPhone,
      });
      return {
        'message': response.data['message']?.toString(),
        'registration_token': response.data['registration_token']?.toString(),
        'deep_link': response.data['deep_link']?.toString(),
        'resend_after_seconds': response.data['resend_after_seconds'] ?? 60,
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> registerComplete(String registrationToken, String code, {bool rememberMe = true}) async {
    try {
      final response = await _apiClient.dio.post('/auth/register/complete', data: {
        'registration_token': registrationToken,
        'code': code,
      });
      final data = response.data;
      await _tokenStorage.saveTokens(
          data['access_token'], data['refresh_token'],
          rememberMe: rememberMe);
      clearMeCache();
      await clearUserDataCache();
      await PushService(_apiClient).registerToken().catchError((_) => null);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> guestLogin() async {
    try {
      final response = await _apiClient.dio.post('/auth/guest');
      final data = response.data;
      final accessToken = data['access_token']?.toString();
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Не удалось получить гостевой токен');
      }
      return {
        'access_token': accessToken,
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> loginAsGuest() async {
    try {
      await _tokenStorage.clearTokens();
      final guestData = await guestLogin();
      if (guestData['access_token'] == null || guestData['access_token']!.isEmpty) {
        throw Exception('Не удалось получить гостевой токен');
      }
      await _tokenStorage.saveGuestToken(guestData['access_token']!);
      clearMeCache();
      await clearUserDataCache();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> login(String phone, String password, {bool rememberMe = true}) async {
    try {
      final response = await _apiClient.dio.post('/auth/login', data: {
        'phone': phone,
        'password': password,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data != null && data['access_token'] != null && data['access_token'].isNotEmpty) {
          final refreshToken = data['refresh_token']?.toString();
          if (refreshToken == null || refreshToken.isEmpty) {
            throw Exception('Неверный ответ от сервера: отсутствует токен обновления');
          }
          await _tokenStorage.saveTokens(
              data['access_token'],
              refreshToken,
              rememberMe: rememberMe);
          clearMeCache();
          await clearUserDataCache();
          try {
            await PushService(_apiClient).registerToken();
          } catch (e) {
            print('⚠️ [Auth] Failed to register push token: $e');
          }
          return;
        } else {
          throw Exception('Неверный ответ от сервера: отсутствует токен доступа');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Неверный номер телефона или пароль');
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Неверный номер телефона или пароль');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Сервер авторизации недоступен. Проверьте подключение к интернету.');
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout ||
                 e.type == DioExceptionType.sendTimeout) {
        throw Exception('Сервер временно недоступен. Попробуйте позже.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Не удалось подключиться к серверу. Проверьте интернет.');
      } else {
        throw Exception(_handleError(e));
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    final refresh = await _tokenStorage.getRefreshToken();
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _apiClient.dio.post('/auth/logout', data: {'refresh_token': refresh});
      } catch (e) {
        print('⚠️ [Auth] Logout failed: $e');
      }
    }
    try {
      await PushService(_apiClient).unregisterToken();
    } catch (e) {
      print('⚠️ [Auth] Failed to unregister push token: $e');
    }
    await _tokenStorage.clearTokens();
    clearMeCache();
    await clearUserDataCache();
    try {
      await userEventsService.stop();
    } catch (_) {}
  }

  void clearMeCache() {
    _cachedMe = null;
    _cachedMeAt = null;
  }

  Future<void> clearUserDataCache() async {
    try {
      await DbService.instance.clearCabinetCache();
    } catch (_) {}
    try {
      await OfflineService().removeCache('cabinets_list');
      await OfflineService().removeCache('projects_list');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getMe() async {
    if (_cachedMe != null && _cachedMeAt != null) {
      final age = DateTime.now().difference(_cachedMeAt!);
      if (age < _meCacheTTL) {
        debugPrint('✅ [Auth] getMe() cache hit, age=${age.inMilliseconds}ms');
        return Map<String, dynamic>.from(_cachedMe!);
      }
      debugPrint('🟡 [Auth] getMe() cache expired, age=${age.inMilliseconds}ms');
    } else {
      debugPrint('🔵 [Auth] getMe() cache miss');
    }

    try {
      final response = await _apiClient.dio.get('/auth/me');
      final data = response.data as Map<String, dynamic>;
      
      _cachedMe = Map<String, dynamic>.from(data);
      _cachedMeAt = DateTime.now();
      
      await OfflineService().saveCache('user_me', data);
      return data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await _tokenStorage.clearTokens();
        try {
          await userEventsService.stop();
        } catch (_) {}
        throw Exception('Сессия истекла. Войдите заново.');
      }
      
      if (e.response?.statusCode != 401 && e.response?.statusCode != 403) {
        final cached = await OfflineService().getCache('user_me');
        if (cached != null && cached is Map<String, dynamic>) {
          print('🟡 [Auth] Using cached user data');
          return cached;
        }
      }
      
      throw _handleError(e);
    } catch (e) {
      final cached = await OfflineService().getCache('user_me');
      if (cached != null && cached is Map<String, dynamic>) {
        return cached;
      }
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _apiClient.dio.delete('/auth/me');
      await logout();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        final detail = e.response?.data?['detail'];
        if (detail is String && detail.isNotEmpty) {
          throw AuthException(statusCode: 403, message: detail);
        }
      }
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> changedFields) async {
    try {
      final response = await _apiClient.dio.patch('/auth/me', data: changedFields);
      final data = response.data as Map<String, dynamic>;
      _cachedMe = Map<String, dynamic>.from(data);
      _cachedMeAt = DateTime.now();
      await OfflineService().saveCache('user_me', data);
      return data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> deleteEmail() async {
    try {
      final response = await _apiClient.dio.delete('/auth/me/email');
      final data = response.data as Map<String, dynamic>;
      _cachedMe = Map<String, dynamic>.from(data);
      _cachedMeAt = DateTime.now();
      await OfflineService().saveCache('user_me', data);
      return data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> requestVerification(String documentUrl, String comment) async {
    try {
      await _apiClient.dio.post('/auth/request-verification', data: {
        'document_url': documentUrl,
        'comment': comment,
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        try {
          int dummyCabinetId = 0;
          final cabinets = await cabinetService.getUserCabinets();
          if (cabinets.isNotEmpty) {
            dummyCabinetId = cabinets.first.cabinetId;
          }

          await serviceRequestService.createServiceRequest(
            cabinetId: dummyCabinetId,
            requestType: 'other',
            description: '[Запрос верификации аккаунта]\nДокумент: $documentUrl\nКомментарий: $comment',
          );
        } catch (_) {
          throw 'Не удалось отправить запрос на верификацию. Попробуйте позже.';
        }
      } else {
        throw _handleError(e);
      }
    } catch (e) {
      throw 'Ошибка отправки запроса верификации: $e';
    }
  }

  Future<int> passwordResetStart(String phone) async {
    try {
      final response = await _apiClient.dio
          .post('/auth/password-reset/start', data: {'phone': phone, 'channel': 'telegram'});
      return response.data['resend_after_seconds'] ?? 60;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> passwordResetComplete(
      String phone, String code, String newPassword) async {
    try {
      await _apiClient.dio.post('/auth/password-reset/complete', data: {
        'phone': phone,
        'code': code,
        'new_password': newPassword,
        'new_password_confirm': newPassword,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    try {
      await _apiClient.dio.post('/auth/password-change', data: {
        'password': oldPassword,
        'new_password': newPassword,
        'new_password_confirm': newPassword,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> resendRegisterCode(String registrationToken) async {
    try {
      final response = await _apiClient.dio.post('/auth/register/resend', data: {
        'registration_token': registrationToken,
      });
      return {
        'message': response.data['message']?.toString(),
        'resend_after_seconds': response.data['resend_after_seconds'] ?? 60,
        'deep_link': response.data['deep_link']?.toString(),
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> registerRequest({
    required String phone,
    required String password,
    required String fullName,
    required String userType,
    String? organizationName,
    String? contactPhone,
    String? userComment,
  }) async {
    try {
      final response = await _apiClient.dio.post('/auth/register/request', data: {
        'phone': phone,
        'password': password,
        'password_confirm': password,
        'full_name': fullName,
        'user_type': userType,
        if (organizationName != null && organizationName.isNotEmpty) 'organization_name': organizationName,
        if (contactPhone != null && contactPhone.isNotEmpty) 'contact_phone': contactPhone,
        if (userComment != null && userComment.isNotEmpty) 'user_comment': userComment,
      });
      return {
        'id': response.data['id'],
        'status': response.data['status']?.toString(),
        'created_at': response.data['created_at']?.toString(),
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception('Номер уже зарегистрирован или заявка с этим номером уже на рассмотрении.');
      }
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> passwordResetRequest({
    required String phone,
    required String newPassword,
    String? userComment,
  }) async {
    try {
      final response = await _apiClient.dio.post('/auth/password-reset/request', data: {
        'phone': phone,
        'new_password': newPassword,
        'new_password_confirm': newPassword,
        if (userComment != null && userComment.isNotEmpty) 'user_comment': userComment,
      });
      return {
        'id': response.data['id'],
        'status': response.data['status']?.toString(),
        'created_at': response.data['created_at']?.toString(),
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Аккаунт с таким номером телефона не найден.');
      }
      if (e.response?.statusCode == 409) {
        throw Exception('Уже есть необработанная заявка на сброс пароля для этого номера.');
      }
      throw _handleError(e);
    }
  }

  Future<void> submitChangePhoneRequest(String newPhone, String? comment) async {
    try {
      await _apiClient.dio.post('/auth/change-phone/request', data: {
        'new_phone': newPhone,
        if (comment != null && comment.isNotEmpty) 'user_comment': comment,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>?> getChangePhoneRequest() async {
    try {
      final response = await _apiClient.dio.get('/auth/change-phone/request');
      if (response.statusCode == 204 || response.data == null) return null;
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _handleError(e);
    }
  }

  Future<void> cancelChangePhoneRequest() async {
    try {
      await _apiClient.dio.delete('/auth/change-phone/request');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    int? statusCode = e.response?.statusCode;
    String message = 'Произошла ошибка. Попробуйте позже.';

    if (e.error is AuthException) {
      final authErr = e.error as AuthException;
      return AuthException(statusCode: authErr.statusCode, message: authErr.message);
    }

    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      final detail = e.response!.data['detail'];
      if (detail is String) {
        message = detail;
      } else if (detail is List) {
        try {
          message = detail.map((e) => e is Map ? (e['msg'] ?? e.toString()) : e.toString()).join('\n');
        } catch (_) {
          message = detail.join('\n');
        }
      } else {
        message = detail.toString();
      }
    } else {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        message = 'Сервер временно недоступен. Попробуйте позже.';
      } else if (e.type == DioExceptionType.connectionError) {
        message = 'Не удалось подключиться к серверу. Проверьте интернет.';
      } else if (statusCode == 401) {
        message = 'Неверный логин или пароль. Попробуйте снова.';
      } else if (statusCode == 403) {
        message = 'Доступ запрещён. У вас недостаточно прав.';
      } else if (statusCode == 404) {
        message = 'Сервер временно недоступен. Попробуйте позже.';
      } else if (statusCode == 409) {
        message = 'Конфликт данных. Возможно, такой пользователь уже существует.';
      } else if (statusCode == 422) {
        final data = e.response?.data;
        if (data is Map && data['detail'] != null) {
          final detail = data['detail'];
          if (detail is List) {
            message = detail.map((d) => d is Map ? (d['msg'] ?? d.toString()) : d.toString()).join('\n');
          } else {
            message = detail.toString();
          }
        } else {
          message = 'Неверные данные. Проверьте введённую информацию.';
        }
      } else if (statusCode == 429) {
        message = e.response?.data?['detail']?.toString() ??
            'Слишком много запросов. Подождите и попробуйте снова.';
      } else if (statusCode == 500) {
        message = 'Ошибка на сервере. Попробуйте позже.';
      }
    }

    return AuthException(statusCode: statusCode, message: message);
  }
}

class AuthException implements Exception {
  final int? statusCode;
  final String message;

  AuthException({this.statusCode, required this.message});

  @override
  String toString() => message;
}