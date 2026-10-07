import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'api_client.dart';
import 'offline_service.dart';

class KnowledgeService {
  final ApiClient _apiClient;
  final OfflineService _offlineService;

  KnowledgeService(this._apiClient) : _offlineService = OfflineService();

  Future<List<Map<String, dynamic>>> getKbCategories() async {
    try {
      final response = await _apiClient.dio.get('/kb/categories');
      final data = List<Map<String, dynamic>>.from(response.data);
      await _offlineService.saveCache('kb_categories', data);
      return data;
    } on DioException catch (e) {
      final cached = await _offlineService.getCache('kb_categories');
      if (cached != null) return List<Map<String, dynamic>>.from(cached);
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getKbArticles({
    int? categoryId,
    List<int>? tagIds,
    String? search,
    String? sortBy,
    String? sortOrder,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final query = <String, dynamic>{'page': page, 'size': size};
      if (categoryId != null) query['category_id'] = categoryId;
      if (tagIds != null && tagIds.isNotEmpty) query['tag_ids'] = tagIds;
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (sortBy != null && sortBy.isNotEmpty) query['sort_by'] = sortBy;
      if (sortOrder != null && sortOrder.isNotEmpty) query['sort_order'] = sortOrder;
      final response =
          await _apiClient.dio.get('/kb/articles', queryParameters: query);
      final data = response.data;
      if (page == 1 &&
          categoryId == null &&
          (tagIds == null || tagIds.isEmpty) &&
          search == null) {
        await _offlineService.saveCache('kb_articles', data);
      }
      return data;
    } on DioException catch (e) {
      final cached = await _offlineService.getCache('kb_articles');
      if (cached != null) return cached as Map<String, dynamic>;
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getKbArticleDetail(int articleId) async {
    try {
      final response = await _apiClient.dio.get('/kb/articles/$articleId');
      final data = response.data;
      await _offlineService.saveCache('kb_article_$articleId', data);
      return data;
    } on DioException catch (e) {
      final cached = await _offlineService.getCache('kb_article_$articleId');
      if (cached != null) return cached as Map<String, dynamic>;
      throw _handleError(e);
    }
  }

  Future<String> downloadKbAttachment(
    int articleId,
    int attachmentId, {
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      Directory directory;
      if (Platform.isAndroid) {
        final publicDir = Directory('/storage/emulated/0/Documents');
        try {
          if (!await publicDir.exists()) {
            await publicDir.create(recursive: true);
          }
          directory = publicDir;
        } catch (_) {
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final fileName = 'kb_${articleId}_$attachmentId.pdf';
      String savePath = '${directory.path}/$fileName';

      final saveFile = File(savePath);
      if (await saveFile.exists()) {
        final nameParts = fileName.split('.');
        final ext = nameParts.length > 1 ? nameParts.last : '';
        final baseName = nameParts.length > 1 ? nameParts.sublist(0, nameParts.length - 1).join('.') : fileName;
        final suffix = '_${DateTime.now().millisecondsSinceEpoch}';
        savePath = ext.isNotEmpty ? '${directory.path}/$baseName$suffix.$ext' : '${directory.path}/$baseName$suffix';
      }

      await _apiClient.dio.download(
        '/kb/articles/$articleId/attachments/$attachmentId/download',
        savePath,
        onReceiveProgress: onProgress,
      );
      return savePath;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getFaqCategories() async {
    try {
      final response = await _apiClient.dio.get('/faq/categories');
      final data = List<Map<String, dynamic>>.from(response.data);
      await _offlineService.saveCache('faq_categories', data);
      return data;
    } on DioException catch (e) {
      final cached = await _offlineService.getCache('faq_categories');
      if (cached != null) return List<Map<String, dynamic>>.from(cached);
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getFaqEntries({
    int? categoryId,
    String? search,
    String? sortBy,
    String? sortOrder,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final query = <String, dynamic>{'page': page, 'size': size};
      if (categoryId != null) query['category_id'] = categoryId;
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (sortBy != null && sortBy.isNotEmpty) query['sort_by'] = sortBy;
      if (sortOrder != null && sortOrder.isNotEmpty) query['sort_order'] = sortOrder;
      final response =
          await _apiClient.dio.get('/faq/entries', queryParameters: query);
      final data = response.data;
      if (page == 1 && categoryId == null && search == null) {
        await _offlineService.saveCache('faq_entries', data);
      }
      return data;
    } on DioException catch (e) {
      final cached = await _offlineService.getCache('faq_entries');
      if (cached != null) return cached as Map<String, dynamic>;
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getTags({String? scope}) async {
    try {
      final query = <String, dynamic>{};
      if (scope != null && scope.isNotEmpty) query['scope'] = scope;
      final response = await _apiClient.dio.get('/tags', queryParameters: query);
      final data = List<Map<String, dynamic>>.from(response.data);
      await _offlineService.saveCache('tags_${scope ?? "all"}', data);
      return data;
    } on DioException catch (e) {
      final cached = await _offlineService.getCache('tags_${scope ?? "all"}');
      if (cached != null) return List<Map<String, dynamic>>.from(cached);
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
    return 'Ошибка загрузки данных';
  }
}
