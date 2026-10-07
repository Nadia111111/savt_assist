// lib/services/service_request_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'offline_service.dart';

class ServiceRequestService {
  final ApiClient _apiClient;

  ServiceRequestService(this._apiClient);

  /// Создать новую заявку на обслуживание
  Future<Map<String, dynamic>> createServiceRequest({
    int? cabinetId,
    int? projectId,
    required String
        requestType, // "repair", "maintenance", "inspection", "other"
    required String description,
    String? clientToken,
  }) async {
    try {
      final data = <String, dynamic>{
        'request_type': requestType,
        'description': description,
      };
      if (cabinetId != null) {
        data['cabinet_id'] = cabinetId;
      }
      if (projectId != null) {
        data['project_id'] = projectId;
      }
      if (clientToken != null && clientToken.isNotEmpty) {
        data['client_token'] = clientToken;
      }
      final response = await _apiClient.dio.post('/service-requests', data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Получить список заявок текущего пользователя
  Future<Map<String, dynamic>> getServiceRequests({
    String? status, // 'open', 'in_progress', 'closed'
    int page = 1,
    int size = 20,
  }) async {
    try {
      final query = <String, dynamic>{'page': page, 'size': size};
      if (status != null) query['status'] = status;
      final response =
          await _apiClient.dio.get('/service-requests', queryParameters: query);
      final data = response.data as Map<String, dynamic>;
      if (status == null && page == 1) {
        await OfflineService().saveCache('service_requests_list', data);
      }
      return data;
    } on DioException catch (e) {
      final cached = await OfflineService().getCache('service_requests_list');
      if (cached != null && cached is Map<String, dynamic>) {
        return cached;
      }
      throw _handleError(e);
    } catch (e) {
      final cached = await OfflineService().getCache('service_requests_list');
      if (cached != null && cached is Map<String, dynamic>) {
        return cached;
      }
      rethrow;
    }
  }

  /// Получить детальную информацию о заявке
  Future<Map<String, dynamic>> getServiceRequestDetail(int requestId) async {
    try {
      // Fallback: first fetch the list of requests and try to find the matching ID
      try {
        final listData = await getServiceRequests(page: 1, size: 100);
        final List items = listData['items'] ?? [];
        final found = items.firstWhere(
          (item) => item['id'] == requestId || item['id']?.toString() == requestId.toString(),
          orElse: () => null,
        );
        if (found != null) {
          return Map<String, dynamic>.from(found);
        }
      } catch (e) {
        debugPrint('Error fetching requests list in detail fallback: $e');
      }

      final response = await _apiClient.dio.get('/service-requests/$requestId');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Получить комментарии к заявке
  Future<List<Map<String, dynamic>>> getServiceRequestComments(int requestId) async {
    try {
      final response = await _apiClient.dio.get('/service-requests/$requestId/comments');
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Добавить комментарий к заявке
  Future<Map<String, dynamic>> createServiceRequestComment(int requestId, String text) async {
    try {
      final response = await _apiClient.dio.post(
        '/service-requests/$requestId/comments',
        data: {'text': text},
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      final detail = e.response!.data['detail'];
      if (detail is String) return detail;
      if (detail is List) {
        try {
          return detail.map((e) => e is Map ? (e['msg'] ?? e.toString()) : e.toString()).join('\n');
        } catch (_) {
          return detail.join('\n');
        }
      }
      return detail.toString();
    }
    return 'Ошибка при работе с заявками';
  }
}
