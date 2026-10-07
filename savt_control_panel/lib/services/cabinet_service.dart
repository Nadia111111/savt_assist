// lib/services/cabinet_service.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'offline_service.dart';
import 'db_service.dart';
import '../models/cabinet.dart';
import '../models/project.dart';
import '../models/telemetry.dart';

class CabinetService {
  final ApiClient _apiClient;
  final OfflineService _offlineService;

  CabinetService(this._apiClient) : _offlineService = OfflineService();

  Future<List<Cabinet>> getUserCabinets({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      try {
        final cachedFromSql = await DbService.instance.getCachedCabinets();
        if (cachedFromSql != null && cachedFromSql.isNotEmpty) {
          print(
              '🟡 [CabinetService] Загружено из кэша SQLite: ${cachedFromSql.length}');
          return cachedFromSql.map((json) => Cabinet.fromJson(json)).toList();
        }
      } catch (err) {
        print('🔴 [CabinetService] Ошибка загрузки ШУ из SQLite: $err');
      }
    }

    try {
      print('🔵 [CabinetService] Запрос к /cabinets с таймаутом 5 секунд');
      final response = await _apiClient.dio.get(
        '/cabinets',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      print('🟢 [CabinetService] Статус: ${response.statusCode}');
      print('📦 [CabinetService] raw cabinets response=${response.data}');

      if (response.statusCode == 200 || response.statusCode == 304) {
        // Парсим ответ
        List<dynamic> data;
        if (response.data == null) {
          return [];
        }

        if (response.data is Map<String, dynamic>) {
          if (response.data.containsKey('items')) {
            data = response.data['items'] as List<dynamic>;
          } else if (response.data.containsKey('data')) {
            data = response.data['data'] as List<dynamic>;
          } else {
            data = response.data.values
                .whereType<List<dynamic>>()
                .expand((e) => e)
                .toList();
          }
        } else if (response.data is List) {
          data = response.data as List<dynamic>;
        } else {
          return [];
        }

        if (data.isEmpty) {
          return [];
        }

        final cabinets = <Cabinet>[];
        for (var json in data) {
          try {
            cabinets.add(Cabinet.fromJson(json));
          } catch (e) {
            print('🔴 [CabinetService] Ошибка парсинга: $e');
          }
        }

        print('🟢 [CabinetService] Успешно получено ШУ: ${cabinets.length}');

        // Сохраняем в кэш
        try {
          await DbService.instance
              .cacheCabinets(List<Map<String, dynamic>>.from(data));
          await _offlineService.saveCache('cabinets_list', data);
        } catch (e) {
          print('🔴 [CabinetService] Ошибка сохранения кэша: $e');
        }

        return cabinets;
      }

      return [];
    } on DioException catch (e) {
      print('🔴 [CabinetService] Dio ошибка: ${e.type} - ${e.message}');

      // Если ошибка подключения - пытаемся вернуть кэш
      try {
        final cachedFromSql = await DbService.instance.getCachedCabinets();
        if (cachedFromSql != null && cachedFromSql.isNotEmpty) {
          print('🟡 [CabinetService] Возвращаем кэш SQLite после ошибки');
          return cachedFromSql.map((json) => Cabinet.fromJson(json)).toList();
        }
      } catch (err) {
        print('🔴 [CabinetService] Ошибка загрузки кэша: $err');
      }

      // Пробуем загрузить из JSON кэша
      try {
        final cached = await _offlineService.getCache('cabinets_list');
        if (cached != null) {
          final List<dynamic> data = cached is List ? cached : [];
          if (data.isNotEmpty) {
            print('🟡 [CabinetService] Возвращаем JSON кэш');
            return data.map((json) => Cabinet.fromJson(json)).toList();
          }
        }
      } catch (err) {
        print('🔴 [CabinetService] Ошибка загрузки JSON кэша: $err');
      }

      // Если кэша нет - возвращаем пустой список с ошибкой
      throw 'Не удалось загрузить список ШУ. Проверьте подключение к интернету.';
    } catch (e) {
      print('🔴 [CabinetService] Неожиданная ошибка: $e');
      throw 'Неожиданная ошибка: $e';
    }
  }

  Future<Map<String, dynamic>> getCabinetDetail(int cabinetId) async {
    try {
      print('🔵 [CabinetService] Запрос к /cabinets/$cabinetId');
      final response = await _apiClient.dio.get(
        '/cabinets/$cabinetId',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final detail = response.data;
      await _offlineService.saveCache('cabinet_detail_$cabinetId', detail);
      return detail;
    } on DioException catch (e) {
      print('🔴 [CabinetService] Ошибка получения деталей ШУ: $e');
      final cached =
          await _offlineService.getCache('cabinet_detail_$cabinetId');
      if (cached != null) return cached as Map<String, dynamic>;
      throw _handleError(e);
    }
  }

  Future<void> updateCabinet(int cabinetId,
      {String? customName, String? customComment}) async {
    try {
      final Map<String, dynamic> data = {};
      if (customName != null) data['custom_name'] = customName;
      if (customComment != null) data['custom_comment'] = customComment;
      await _apiClient.dio.patch('/cabinets/$cabinetId', data: data);

      // Обновляем кэш
      final cached =
          await _offlineService.getCache('cabinet_detail_$cabinetId');
      if (cached is Map<String, dynamic>) {
        if (customName != null) cached['custom_name'] = customName;
        if (customComment != null) cached['custom_comment'] = customComment;
        await _offlineService.saveCache('cabinet_detail_$cabinetId', cached);
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Получить кэшированные документы для кабинета (офлайн)
  Future<List<Map<String, dynamic>>?> getCachedDocuments(int cabinetId) async {
    try {
      final cachedSql = await DbService.instance.getCachedDocuments(cabinetId);
      if (cachedSql != null && cachedSql.isNotEmpty) return cachedSql;
      final cached =
          await _offlineService.getCache('cabinet_documents_$cabinetId');
      if (cached != null) return List<Map<String, dynamic>>.from(cached);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getCabinetChat(int cabinetId) async {
    try {
      final response = await _apiClient.dio.get('/cabinets/$cabinetId/chat');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<TelemetryStateResponse> getTelemetry(int cabinetId) async {
    try {
      final response = await _apiClient.dio.get(
        '/cabinets/$cabinetId/telemetry',
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return TelemetryStateResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getDocuments(int cabinetId,
      {int page = 1, int size = 20}) async {
    try {
      final response = await _apiClient.dio.get(
        '/cabinets/$cabinetId/documents',
        queryParameters: {'page': page, 'size': size},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final items =
          List<Map<String, dynamic>>.from(response.data['items'] ?? []);
      if (page == 1) {
        await _offlineService.saveCache('cabinet_documents_$cabinetId', items);
        await DbService.instance.cacheDocuments(cabinetId, items);
      }
      return items;
    } on DioException catch (e) {
      // Сначала пробуем SharedPreferences-кэш
      final cached =
          await _offlineService.getCache('cabinet_documents_$cabinetId');
      if (cached != null) return List<Map<String, dynamic>>.from(cached);
      // Затем пробуем SQLite-кэш
      final cachedSql = await DbService.instance.getCachedDocuments(cabinetId);
      if (cachedSql != null && cachedSql.isNotEmpty) return cachedSql;
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getUserAdditionRequests() async {
    try {
      final response = await _apiClient.dio.get('/cabinet-addition-requests');
      return List<Map<String, dynamic>>.from(response.data['items'] ?? []);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAdditionRequestStatus(int requestId) async {
    try {
      final response =
          await _apiClient.dio.get('/cabinet-addition-requests/$requestId');
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> requestDocumentAccess(int docId, {String? userMessage}) async {
    try {
      await _apiClient.dio.post('/documents/$docId/request-access', data: {
        'user_message': userMessage,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> getDocumentDownloadUrl(int docId) async {
    return '${ApiClient.baseUrl}/documents/$docId/download';
  }

  String? _tryParseUrl(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > 1000) return null;

    // Check if it starts with PDF magic bytes (%PDF)
    if (bytes.length >= 4 &&
        bytes[0] == 37 &&
        bytes[1] == 80 &&
        bytes[2] == 68 &&
        bytes[3] == 70) {
      return null; // It's a real PDF, do not parse as URL
    }

    try {
      final text = utf8.decode(bytes).trim();

      // A URL or relative path should not contain whitespace or line breaks
      if (text.contains(' ') ||
          text.contains('\n') ||
          text.contains('\r') ||
          text.contains('\t')) {
        return null;
      }

      String parsedText = text;
      if (text.startsWith('"') && text.endsWith('"')) {
        final decoded = jsonDecode(text);
        if (decoded is String) {
          parsedText = decoded.trim();
        }
      }

      final lower = parsedText.toLowerCase();
      if (lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          lower.startsWith('/') ||
          lower.startsWith('static/') ||
          lower.startsWith('uploads/')) {
        return parsedText;
      }
    } catch (_) {}
    return null;
  }

  Future<List<int>> downloadDocumentWithAuth(int docId) async {
    try {
      final response = await _apiClient.dio.get(
        '/documents/$docId/download',
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final bytes = response.data as List<int>;

      if (bytes.isNotEmpty) {
        String? redirectUrl;

        if (bytes[0] == 123 || bytes[0] == 91) {
          try {
            final text = utf8.decode(bytes);
            final decoded = jsonDecode(text);
            if (decoded is Map) {
              if (decoded.containsKey('detail') ||
                  decoded.containsKey('error') ||
                  decoded.containsKey('message')) {
                final errorMsg = decoded['detail'] ??
                    decoded['error'] ??
                    decoded['message'] ??
                    'Ошибка сервера';
                throw Exception(errorMsg.toString());
              }

              final fileUrl = decoded['url'] ??
                  decoded['path'] ??
                  decoded['file_url'] ??
                  decoded['download_url'];
              if (fileUrl != null) {
                redirectUrl = fileUrl.toString();
              }
            }
          } catch (e) {
            if (e is Exception) rethrow;
          }
        }

        redirectUrl ??= _tryParseUrl(bytes);

        if (redirectUrl != null) {
          final actualUrl = redirectUrl.startsWith('http')
              ? redirectUrl
              : '${ApiClient.baseUrl}${redirectUrl.startsWith('/') ? '' : '/'}$redirectUrl';

          final actualResponse = await _apiClient.dio.get(
            actualUrl,
            options: Options(
              responseType: ResponseType.bytes,
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );
          return actualResponse.data as List<int>;
        }
      }
      return bytes;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<int>> downloadDocumentWithProgress(
    int docId, {
    void Function(int, int)? onProgress,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/documents/$docId/download',
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
        ),
        onReceiveProgress: onProgress,
      );
      final bytes = response.data as List<int>;

      if (bytes.isNotEmpty) {
        String? redirectUrl;

        if (bytes[0] == 123 || bytes[0] == 91) {
          try {
            final text = utf8.decode(bytes);
            final decoded = jsonDecode(text);
            if (decoded is Map) {
              if (decoded.containsKey('detail') ||
                  decoded.containsKey('error') ||
                  decoded.containsKey('message')) {
                final errorMsg = decoded['detail'] ??
                    decoded['error'] ??
                    decoded['message'] ??
                    'Ошибка сервера';
                throw Exception(errorMsg.toString());
              }

              final fileUrl = decoded['url'] ??
                  decoded['path'] ??
                  decoded['file_url'] ??
                  decoded['download_url'];
              if (fileUrl != null) {
                redirectUrl = fileUrl.toString();
              }
            }
          } catch (e) {
            if (e is Exception) rethrow;
          }
        }

        redirectUrl ??= _tryParseUrl(bytes);

        if (redirectUrl != null) {
          final actualUrl = redirectUrl.startsWith('http')
              ? redirectUrl
              : '${ApiClient.baseUrl}${redirectUrl.startsWith('/') ? '' : '/'}$redirectUrl';

          final actualResponse = await _apiClient.dio.get(
            actualUrl,
            options: Options(
              responseType: ResponseType.bytes,
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ),
            onReceiveProgress: onProgress,
          );
          return actualResponse.data as List<int>;
        }
      }
      return bytes;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getAllUserDocuments({
    String? docType,
    String? search,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final query = <String, dynamic>{'page': page, 'size': size};
      if (docType != null && docType.isNotEmpty) query['doc_type'] = docType;
      if (search != null && search.isNotEmpty) query['search'] = search;
      final response = await _apiClient.dio.get(
        '/documents',
        queryParameters: query,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final items =
          List<Map<String, dynamic>>.from(response.data['items'] ?? []);
      if (page == 1 &&
          (docType == null || docType.isEmpty) &&
          (search == null || search.isEmpty)) {
        await _offlineService.saveCache('all_user_documents', items);
      }
      return items;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 ||
          e.response?.statusCode == 403 ||
          e.response?.statusCode == 405) {
        try {
          final cabinets = await getUserCabinets();
          final List<Map<String, dynamic>> allDocs = [];
          for (final cab in cabinets) {
            final docs = await getDocuments(cab.cabinetId);
            final cabName =
                cab.customName.isNotEmpty ? cab.customName : cab.objectNumber;
            for (final doc in docs) {
              final Map<String, dynamic> enrichedDoc =
                  Map<String, dynamic>.from(doc);
              enrichedDoc['cabinet_id'] ??= cab.cabinetId;
              enrichedDoc['cabinet_object_number'] ??= cab.objectNumber;
              enrichedDoc['cabinet_name'] ??= cabName;
              allDocs.add(enrichedDoc);
            }
          }
          // Filter by docType if specified
          List<Map<String, dynamic>> filtered = allDocs;
          if (docType != null && docType.isNotEmpty) {
            filtered = filtered.where((doc) {
              final ext = (doc['file_url'] ?? doc['title'] ?? '')
                  .toString()
                  .split('.')
                  .last
                  .toLowerCase();
              if (docType == 'other') {
                return ext != 'pdf' &&
                    ext != 'doc' &&
                    ext != 'docx' &&
                    ext != 'xls' &&
                    ext != 'xlsx';
              }
              if (docType == 'doc') {
                return ext == 'doc' || ext == 'docx';
              }
              if (docType == 'xls') {
                return ext == 'xls' || ext == 'xlsx';
              }
              return ext == docType.toLowerCase();
            }).toList();
          }
          // Filter by search query if specified
          if (search != null && search.isNotEmpty) {
            final q = search.toLowerCase();
            filtered = filtered.where((doc) {
              final title = (doc['title'] ?? '').toString().toLowerCase();
              return title.contains(q);
            }).toList();
          }
          // Pagination
          final startIndex = (page - 1) * size;
          if (startIndex >= filtered.length) {
            return [];
          }
          final endIndex = startIndex + size > filtered.length
              ? filtered.length
              : startIndex + size;
          final paginated = filtered.sublist(startIndex, endIndex);

          if (page == 1 &&
              (docType == null || docType.isEmpty) &&
              (search == null || search.isEmpty)) {
            await _offlineService.saveCache('all_user_documents', filtered);
          }
          return paginated;
        } catch (fallbackError) {
          print('Error in cabinet documents fallback: $fallbackError');
        }
      }

      final cached = await _offlineService.getCache('all_user_documents');
      if (cached != null) return List<Map<String, dynamic>>.from(cached);
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response?.data is Map) {
      final map = e.response!.data as Map;
      if (map['detail'] != null) {
        final detail = map['detail'];
        if (detail is String) return detail;
        if (detail is List) {
          try {
            return detail
                .map((item) =>
                    item is Map ? (item['msg'] ?? item.toString()) : item.toString())
                .join('\n');
          } catch (_) {
            return detail.join('\n');
          }
        }
        return detail.toString();
      }
      if (map['message'] != null) return map['message'].toString();
      if (map['error'] != null) return map['error'].toString();
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Сервер временно недоступен. Попробуйте позже.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Не удалось подключиться к серверу. Проверьте адрес сервера.';
    }
    if (e.response?.statusCode == 401) {
      return 'Сессия истекла. Войдите заново.';
    }
    if (e.response?.statusCode == 404) {
      return 'Данные не найдены на сервере.';
    }
    return 'Ошибка загрузки данных: ${e.message}';
  }

  Future<List<Project>> getUserProjects({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      try {
        final cached = await _offlineService.getCache('projects_list');
        if (cached != null && cached is List) {
          print(
              '🟡 [CabinetService] Загружены проекты из кэша: ${cached.length}');
          return cached.map((json) => Project.fromJson(json)).toList();
        }
      } catch (e) {
        print('🔴 [CabinetService] Ошибка чтения кэша проектов: $e');
      }
    }

    try {
      final response = await _apiClient.dio.get(
        '/projects',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 304) {
        final List<dynamic> data = response.data is List
            ? response.data
            : (response.data is Map && response.data['items'] is List)
                ? response.data['items']
                : [];

        debugPrint(
            '📦 [Projects] raw=${response.data}, parsed count=${data.length}');

        final List<Project> projects =
            data.map((json) => Project.fromJson(json)).toList();

        try {
          await _offlineService.saveCache('projects_list', data);
        } catch (e) {
          print('🔴 [CabinetService] Ошибка сохранения кэша проектов: $e');
        }

        return projects;
      }
      return [];
    } on DioException catch (e) {
      try {
        final cached = await _offlineService.getCache('projects_list');
        if (cached != null && cached is List) {
          return cached.map((json) => Project.fromJson(json)).toList();
        }
      } catch (_) {}
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> addProjectByQr(String qrData) async {
    final payload = qrData.trim();
    print('🚀 [CabinetService] Отправка POST /projects/add-by-qr');
    print('📦 [CabinetService] Данные: {"qr_data": "$payload"}');
    try {
      final response = await _apiClient.dio.post(
        '/projects/add-by-qr',
        data: {'qr_data': payload},
      );
      print('🟢 [CabinetService] Успешный ответ /projects/add-by-qr (${response.statusCode}): ${response.data}');
      await _invalidateProjectCache();
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        // Проверяем 404, перехваченный интерцептором
        if (data['status'] == 404 || data['status'] == 'not_found' || data['error'] == 'Endpoint not found') {
          return {
            'status': 'not_found',
            'message': data['message'] ?? data['detail'] ?? 'Проект с таким кодом не найден.',
          };
        }
        return data;
      }
      return {'status': 'linked', 'data': response.data};
    } on DioException catch (e) {
      print('🔴 [CabinetService] DioException в addProjectByQr: status=${e.response?.statusCode}, data=${e.response?.data}, message=${e.message}');
      if (e.response?.statusCode == 404) {
        final msg = _extractErrorMessage(e.response?.data, 'Проект с таким кодом не найден.');
        return {'status': 'not_found', 'message': msg};
      } else if (e.response?.statusCode == 409) {
        final msg = _extractErrorMessage(e.response?.data, 'Вы уже привязаны к этому проекту.');
        return {'status': 'conflict', 'message': msg};
      }
      final statusCode = e.response?.statusCode;
      final serverMsg = _extractErrorMessage(e.response?.data, null);
      final errMsg = statusCode != null
          ? 'Ошибка сервера (HTTP $statusCode): $serverMsg'
          : 'Сетевая ошибка (${e.type}): ${e.message ?? e.error ?? "Не удалось связаться с сервером"}';
      return {
        'status': 'error',
        'statusCode': statusCode,
        'message': errMsg,
      };
    } catch (e, stack) {
      print('🔴 [CabinetService] Непредвиденная ошибка в addProjectByQr: $e\n$stack');
      return {
        'status': 'error',
        'message': 'Ошибка: $e',
      };
    }
  }

  Future<Map<String, dynamic>> addCabinetByQr(String qrData) async {
    final payload = qrData.trim();
    print('🚀 [CabinetService] Отправка POST /cabinets/add-by-qr');
    print('📦 [CabinetService] Данные: {"qr_data": "$payload"}');
    try {
      final response = await _apiClient.dio.post(
        '/cabinets/add-by-qr',
        data: {'qr_data': payload},
      );
      print('🟢 [CabinetService] Успешный ответ /cabinets/add-by-qr (${response.statusCode}): ${response.data}');
      await _invalidateProjectCache();
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['status'] == 404 || data['status'] == 'not_found' || data['error'] == 'Endpoint not found') {
          return {
            'status': 'not_found',
            'message': data['message'] ?? data['detail'] ?? 'Шкаф управления с таким кодом не найден.',
          };
        }
        return data;
      }
      return {'status': 'linked', 'data': response.data};
    } on DioException catch (e) {
      print('🔴 [CabinetService] DioException в addCabinetByQr: status=${e.response?.statusCode}, data=${e.response?.data}, message=${e.message}');
      if (e.response?.statusCode == 404) {
        final msg = _extractErrorMessage(e.response?.data, 'Шкаф управления с таким кодом не найден.');
        return {'status': 'not_found', 'message': msg};
      } else if (e.response?.statusCode == 409) {
        final msg = _extractErrorMessage(e.response?.data, 'Шкаф управления уже добавлен в ваш список.');
        return {'status': 'conflict', 'message': msg};
      }
      final statusCode = e.response?.statusCode;
      final serverMsg = _extractErrorMessage(e.response?.data, null);
      final errMsg = statusCode != null
          ? 'Ошибка сервера (HTTP $statusCode): $serverMsg'
          : 'Сетевая ошибка (${e.type}): ${e.message ?? e.error ?? "Не удалось связаться с сервером"}';
      return {
        'status': 'error',
        'statusCode': statusCode,
        'message': errMsg,
      };
    } catch (e, stack) {
      print('🔴 [CabinetService] Непредвиденная ошибка в addCabinetByQr: $e\n$stack');
      return {
        'status': 'error',
        'message': 'Ошибка: $e',
      };
    }
  }

  String _extractErrorMessage(dynamic data, String? fallback) {
    if (data is Map) {
      if (data['message'] != null) return data['message'].toString();
      if (data['detail'] != null) return data['detail'].toString();
      if (data['error'] != null) return data['error'].toString();
    }
    return fallback ?? (data?.toString() ?? 'Неизвестная ошибка');
  }

  Future<Map<String, dynamic>> addCabinetByPhoto({
    required int projectId,
    required String photoUrl,
    String? userComment,
  }) async {
    try {
      final data = <String, dynamic>{
        'project_id': projectId,
        'photo_url': photoUrl,
      };
      if (userComment != null && userComment.isNotEmpty) {
        data['user_comment'] = userComment;
      }
      final response = await _apiClient.dio.post(
        '/cabinets/add-by-photo',
        data: data,
      );
      await _invalidateProjectCache();
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<ProjectDetails> getProjectDetails(int projectId) async {
    try {
      final response = await _apiClient.dio.get('/projects/$projectId');
      final raw = response.data;
      debugPrint('📦 [ProjectDetails] raw=$raw');
      if (raw is Map<String, dynamic>) {
        final cabs = raw['cabinets'];
        debugPrint(
            '📦 [ProjectDetails] cabinets count=${cabs is List ? cabs.length : 'n/a'}');
      }
      return ProjectDetails.fromJson(raw);
    } on DioException catch (e) {
      debugPrint(
          '🔴 [ProjectDetails] error=${e.response?.statusCode} ${e.message}');
      throw _handleError(e);
    }
  }

  Future<void> leaveProject(int projectId) async {
    try {
      await _apiClient.dio.delete('/projects/$projectId');
      await _invalidateProjectCache();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> pinProject(int projectId) async {
    try {
      await _apiClient.dio.post('/projects/$projectId/pin');
      await _invalidateProjectCache();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> unpinProject(int projectId) async {
    try {
      await _apiClient.dio.delete('/projects/$projectId/pin');
      await _invalidateProjectCache();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> pinCabinet(int cabinetId) async {
    try {
      await _apiClient.dio.post('/cabinets/$cabinetId/pin');
      await _invalidateProjectCache();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> unpinCabinet(int cabinetId) async {
    try {
      await _apiClient.dio.delete('/cabinets/$cabinetId/pin');
      await _invalidateProjectCache();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteCabinet(int cabinetId) async {
    try {
      await _apiClient.dio.delete('/cabinets/$cabinetId');
      await _invalidateProjectCache();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> _invalidateProjectCache() async {
    try {
      await DbService.instance.clearCabinetCache();
    } catch (_) {}
    try {
      await _offlineService.removeCache('cabinets_list');
      await _offlineService.removeCache('projects_list');
    } catch (_) {}
  }
}
