// lib/utils/error_handler.dart
import 'package:dio/dio.dart';

class ErrorHandler {
  static String getUserFriendlyMessage(dynamic error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;

      // Шаг 3: Обработайте 413 до разбора тела
      if (statusCode == 413) {
        return 'Файл слишком большой';
      }

      // Шаг 6: Любой 502/503/504
      if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
        final detail = error.response?.data is Map ? error.response?.data['detail'] : null;
        if (detail is String && detail.isNotEmpty) return detail;
        return 'Сервис временно недоступен, попробуйте ещё раз через минуту';
      }

      // Шаг 3: 429 Суточный лимит загрузок
      if (statusCode == 429) {
        final detail = error.response?.data is Map ? error.response?.data['detail'] : null;
        if (detail is String && detail.isNotEmpty) return detail;
        return 'Суточный лимит загрузок исчерпан (500 МБ). Попробуйте позже';
      }

      final responseData = error.response?.data;
      if (responseData is Map && responseData['detail'] != null) {
        final detail = responseData['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
        if (detail is List && detail.isNotEmpty) {
          // Шаг 4: если detail — массив, не показывать его.
          return 'Проверьте введённые данные';
        }
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'Сервис временно недоступен, попробуйте ещё раз через минуту';
        case DioExceptionType.connectionError:
          return 'Не удалось подключиться к серверу. Проверьте интернет.';
        case DioExceptionType.badResponse:
          switch (statusCode) {
            case 401:
              return 'Сессия истекла. Войдите заново.';
            case 403:
              return 'Нет доступа к этому ресурсу.';
            case 404:
              return 'Данные не найдены.';
            case 409:
              return 'Конфликт данных. Возможно, запись уже существует.';
            case 413:
              return 'Файл слишком большой';
            case 422:
              return 'Проверьте введённые данные';
            case 429:
              return 'Суточный лимит загрузок исчерпан (500 МБ). Попробуйте позже';
            case 500:
              return 'Ошибка на сервере. Попробуйте позже.';
            case 502:
            case 503:
            case 504:
              return 'Сервис временно недоступен, попробуйте ещё раз через минуту';
            default:
              return 'Ошибка сервера: $statusCode';
          }
        default:
          return 'Произошла ошибка. Попробуйте позже.';
      }
    }
    return error.toString();
  }
}
