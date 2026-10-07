import 'dart:async';
import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/notification_settings.dart';
export '../models/notification.dart';
export '../models/notification_settings.dart';
import 'offline_service.dart';

class NotificationService {
  final ApiClient _apiClient;

  NotificationService(this._apiClient);

  // MARK: - Настройки уведомлений

  /// Получить настройки уведомлений
  Future<NotificationSettings> getSettings() async {
    print('🔵 [NotificationService] getSettings');
    try {
      final response = await _apiClient.dio.get('/notifications/settings');
      print('🟢 [NotificationService] Настройки получены');
      return NotificationSettings.fromJson(response.data);
    } on DioException catch (e) {
      print('🔴 [NotificationService] Ошибка getSettings: ${e.type}');
      throw _handleError(e);
    }
  }

  /// Обновить один параметр настроек
  Future<NotificationSettings> updateSetting(String key, bool value) async {
    print('🔵 [NotificationService] updateSetting: $key = $value');
    try {
      final response = await _apiClient.dio.patch(
        '/notifications/settings',
        data: {key: value},
      );
      print('🟢 [NotificationService] Настройка обновлена');
      return NotificationSettings.fromJson(response.data);
    } on DioException catch (e) {
      print('🔴 [NotificationService] Ошибка updateSetting: ${e.type}');
      throw _handleError(e);
    }
  }

  // MARK: - Пауза уведомлений

  /// Включить паузу на указанное количество часов
  /// hours: количество часов (1, 2, 3, 6, 12, 24) или null для бесконечной паузы
  Future<NotificationSettings> muteNotifications({int? hours}) async {
    print('🔵 [NotificationService] muteNotifications: hours=$hours');
    try {
      final response = await _apiClient.dio.post(
        '/notifications/mute',
        data: {'hours': hours},
      );
      print('🟢 [NotificationService] Пауза включена');
      return NotificationSettings.fromJson(response.data);
    } on DioException catch (e) {
      print('🔴 [NotificationService] Ошибка muteNotifications: ${e.type}');
      throw _handleError(e);
    }
  }

  /// Выключить паузу досрочно
  Future<NotificationSettings> unmuteNotifications() async {
    print('🔵 [NotificationService] unmuteNotifications');
    try {
      final response = await _apiClient.dio.delete('/notifications/mute');
      print('🟢 [NotificationService] Пауза выключена');
      return NotificationSettings.fromJson(response.data);
    } on DioException catch (e) {
      print('🔴 [NotificationService] Ошибка unmuteNotifications: ${e.type}');
      throw _handleError(e);
    }
  }

  // MARK: - Список уведомлений

  /// Получить список уведомлений
  Future<Map<String, dynamic>> getNotifications({
    bool? isRead,
    List<String>? types,
    int page = 1,
    int size = 20,
  }) async {
    print(
        '🔵 [NotificationService] getNotifications: page=$page, size=$size, isRead=$isRead, types=$types');

    try {
      final query = <String, dynamic>{'page': page, 'size': size};
      if (isRead != null) query['is_read'] = isRead;
      if (types != null) {
        for (final type in types) {
          query.addAll({'type': type});
        }
      }

      final response = await _apiClient.dio.get(
        '/notifications',
        queryParameters: query,
      );

      print('🟢 [NotificationService] Статус: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (page == 1 && isRead == false) {
          await OfflineService().saveCache('notifications_list', data);
        }
        return data;
      } else {
        throw Exception('Неверный ответ от сервера');
      }
    } on DioException catch (e) {
      print('🔴 [NotificationService] DioException: ${e.type}');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        final cached = await OfflineService().getCache('notifications_list');
        if (cached != null && cached is Map<String, dynamic>) {
          print('📦 [NotificationService] Используем кэш');
          return cached;
        }
        throw TimeoutException('Превышено время ожидания');
      }

      if (e.response?.statusCode == 401) {
        rethrow;
      }

      final cached = await OfflineService().getCache('notifications_list');
      if (cached != null && cached is Map<String, dynamic>) {
        print('📦 [NotificationService] Используем кэш при ошибке');
        return cached;
      }
      throw _handleError(e);
    } catch (e) {
      print('🔴 [NotificationService] Неизвестная ошибка: $e');
      final cached = await OfflineService().getCache('notifications_list');
      if (cached != null && cached is Map<String, dynamic>) {
        return cached;
      }
      rethrow;
    }
  }

  /// Получить количество непрочитанных уведомлений
  Future<int> getUnreadCount() async {
    print('🔵 [NotificationService] getUnreadCount');
    try {
      final response = await _apiClient.dio.get('/notifications/unread-count');
      return response.data['unread'] ?? 0;
    } on DioException catch (e) {
      print('🔴 [NotificationService] Ошибка getUnreadCount: ${e.type}');
      return 0;
    } catch (e) {
      print('🔴 [NotificationService] Ошибка getUnreadCount: $e');
      return 0;
    }
  }

  // MARK: - Действия с уведомлениями

  /// Отметить уведомление как прочитанное
  Future<void> markAsRead(int notificationId) async {
    print('🔵 [NotificationService] markAsRead: $notificationId');
    try {
      await _apiClient.dio.post('/notifications/$notificationId/read');
      print('🟢 [NotificationService] Отмечено как прочитанное');
    } on DioException catch (e) {
      print('🔴 [NotificationService] Ошибка markAsRead: ${e.type}');
      throw _handleError(e);
    }
  }

  /// Отметить все уведомления как прочитанные
  Future<void> markAllAsRead() async {
    print('🔵 [NotificationService] markAllAsRead');
    try {
      await _apiClient.dio.post('/notifications/read-all');
      print('🟢 [NotificationService] Все отмечены как прочитанные');
    } on DioException catch (e) {
      print('🔴 [NotificationService] Ошибка markAllAsRead: ${e.type}');
      throw _handleError(e);
    }
  }

  /// Удалить все уведомления
  Future<void> deleteAllNotifications() async {
    print('🔵 [NotificationService] deleteAllNotifications');
    try {
      await _apiClient.dio.delete('/notifications');
      print('🟢 [NotificationService] Все уведомления удалены');
    } on DioException catch (e) {
      print(
          '🔴 [NotificationService] Ошибка deleteAllNotifications: ${e.type}');
      throw _handleError(e);
    }
  }

  // MARK: - Вспомогательные методы

  String _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Превышено время ожидания ответа от сервера';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Нет соединения с интернетом. Проверьте подключение.';
    }
    if (e.response?.statusCode == 401) {
      return 'Сессия истекла. Войдите заново.';
    }
    if (e.response?.statusCode == 500) {
      return 'Ошибка на сервере. Попробуйте позже.';
    }
    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      final detail = e.response!.data['detail'];
      if (detail is String) return detail;
      if (detail is List) {
        try {
          return detail
              .map((e) => e is Map ? (e['msg'] ?? e.toString()) : e.toString())
              .join('\n');
        } catch (_) {
          return detail.join('\n');
        }
      }
      return detail.toString();
    }
    return 'Ошибка работы с уведомлениями';
  }
}
