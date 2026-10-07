// lib/services/reclamations_service.dart
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'offline_service.dart';

class ReclamationsService {
  final ApiClient _apiClient;

  ReclamationsService(this._apiClient);

  /// Создать новую рекламацию
  /// POST /reclamations
  Future<Map<String, dynamic>> createReclamation({
    required String objectType,
    int? cabinetId,
    int? projectId,
    Map<String, dynamic>? objectDetails,
    required String description,
    String? occurrenceConditions,
    String? errorCodes,
    String? contractNumber,
    String? orderNumber,
    String? ttnNumber,
    required String contactName,
    required String contactPhone,
    required String contactEmail,
    String? customerName,
    List<Map<String, dynamic>>? attachments,
  }) async {
    try {
      final data = <String, dynamic>{
        'object_type': objectType,
        'description': description,
        'contact_name': contactName,
        'contact_phone': contactPhone,
        'contact_email': contactEmail,
      };

      if (objectDetails != null && objectDetails.isNotEmpty) {
        data['object_details'] = objectDetails;
      }

      if (occurrenceConditions != null && occurrenceConditions.trim().isNotEmpty) {
        data['occurrence_conditions'] = occurrenceConditions.trim();
      }
      if (errorCodes != null && errorCodes.trim().isNotEmpty) {
        data['error_codes'] = errorCodes.trim();
      }
      if (contractNumber != null && contractNumber.trim().isNotEmpty) {
        data['contract_number'] = contractNumber.trim();
      }
      if (orderNumber != null && orderNumber.trim().isNotEmpty) {
        data['order_number'] = orderNumber.trim();
      }
      if (ttnNumber != null && ttnNumber.trim().isNotEmpty) {
        data['ttn_number'] = ttnNumber.trim();
      }
      if (customerName != null && customerName.trim().isNotEmpty) {
        data['customer_name'] = customerName.trim();
      }
      if (attachments != null && attachments.isNotEmpty) {
        data['attachments'] = attachments;
      }

      final response = await _apiClient.dio.post('/reclamations', data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Получить список своих рекламаций
  /// GET /reclamations?status=&page=&size=
  Future<Map<String, dynamic>> getReclamations({
    String? status,
    int page = 1,
    int size = 20,
  }) async {
    final cacheKey = 'reclamations_list_${status ?? "all"}_p$page';
    try {
      final query = <String, dynamic>{'page': page, 'size': size};
      if (status != null && status.isNotEmpty && status != 'Все') {
        query['status'] = status;
      }

      final response =
          await _apiClient.dio.get('/reclamations', queryParameters: query);
      final data = response.data as Map<String, dynamic>;

      if (page == 1) {
        await OfflineService().saveCache(cacheKey, data);
        if (status == null || status.isEmpty || status == 'Все') {
          await OfflineService().saveCache('reclamations_list', data);
        }
      }
      return data;
    } on DioException catch (e) {
      final cached = await OfflineService().getCache(cacheKey) ??
          await OfflineService().getCache('reclamations_list');
      if (cached != null && cached is Map<String, dynamic>) {
        return cached;
      }
      throw _handleError(e);
    } catch (e) {
      final cached = await OfflineService().getCache(cacheKey) ??
          await OfflineService().getCache('reclamations_list');
      if (cached != null && cached is Map<String, dynamic>) {
        return cached;
      }
      rethrow;
    }
  }

  /// Получить детали рекламации
  /// GET /reclamations/{id}
  Future<Map<String, dynamic>> getReclamationDetail(int reclamationId) async {
    final cacheKey = 'reclamation_detail_$reclamationId';
    try {
      final response =
          await _apiClient.dio.get('/reclamations/$reclamationId');
      final data = response.data as Map<String, dynamic>;
      await OfflineService().saveCache(cacheKey, data);
      return data;
    } on DioException catch (e) {
      // Проверяем оффлайн кэш деталей
      final cached = await OfflineService().getCache(cacheKey);
      if (cached != null && cached is Map<String, dynamic>) {
        return cached;
      }
      // Запасной вариант: попробовать найти в сохраненном списке
      try {
        final listCached = await OfflineService().getCache('reclamations_list');
        if (listCached != null && listCached is Map && listCached['items'] is List) {
          final items = listCached['items'] as List;
          final found = items.firstWhere(
            (item) => item['id'] == reclamationId ||
                item['id']?.toString() == reclamationId.toString(),
            orElse: () => null,
          );
          if (found != null) {
            return Map<String, dynamic>.from(found);
          }
        }
      } catch (_) {}
      throw _handleError(e);
    } catch (e) {
      final cached = await OfflineService().getCache(cacheKey);
      if (cached != null && cached is Map<String, dynamic>) {
        return cached;
      }
      rethrow;
    }
  }

  String _handleError(DioException e) {
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
    if (e.response?.statusCode == 403) {
      return 'Нет доступа к указанному шкафу или проекту';
    }
    if (e.response?.statusCode == 404) {
      return 'Рекламация не найдена';
    }
    return 'Ошибка при работе с рекламациями (${e.message ?? e.toString()})';
  }
}