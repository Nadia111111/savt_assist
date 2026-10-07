// lib/utils/error_handler.dart
import 'package:dio/dio.dart';

class ErrorHandler {
  static String getUserFriendlyMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'Нет соединения с сервером. Проверьте интернет.';
        case DioExceptionType.connectionError:
          return 'Не удалось подключиться к серверу.';
        case DioExceptionType.badResponse:
          switch (error.response?.statusCode) {
            case 401:
              return 'Сессия истекла. Войдите заново.';
            case 403:
              return 'Нет доступа к этому ресурсу.';
            case 404:
              return 'Данные не найдены.';
            case 409:
              return 'Конфликт данных. Возможно, запись уже существует.';
            case 422:
              return 'Некорректные данные. Проверьте ввод.';
            case 500:
              return 'Ошибка на сервере. Попробуйте позже.';
            default:
              return 'Ошибка сервера: ${error.response?.statusCode}';
          }
        default:
          return 'Произошла ошибка. Попробуйте позже.';
      }
    }
    return error.toString();
  }
}
