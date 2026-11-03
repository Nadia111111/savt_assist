import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class UploadService {
  final ApiClient _apiClient;

  UploadService(this._apiClient);

  /// Загрузить файл (изображение, документ, видео).
  /// Сервер возвращает подписанную ссылку, которую необходимо передавать без изменений.
  Future<String> uploadAttachment(String filePath, {bool compress = true}) async {
    try {
      String targetPath = filePath;
      final lowercasePath = filePath.toLowerCase();
      if (compress && (lowercasePath.endsWith('.jpg') ||
          lowercasePath.endsWith('.jpeg') ||
          lowercasePath.endsWith('.png') ||
          lowercasePath.endsWith('.webp'))) {
        try {
          final tempDir = await getTemporaryDirectory();
          final tempPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final result = await FlutterImageCompress.compressAndGetFile(
            filePath,
            tempPath,
            quality: 75,
            format: CompressFormat.jpeg,
          );
          if (result != null) {
            targetPath = result.path;
          }
        } catch (e) {
          debugPrint('Ошибка сжатия изображения: $e');
        }
      }

      final fileName = targetPath.split('/').last;
      final file = await MultipartFile.fromFile(targetPath, filename: fileName);
      final formData = FormData.fromMap({
        'file': file,
      });
      final response = await _apiClient.dio.post(
        '/upload/attachment',
        data: formData,
      );
      // Возвращаем ссылку ровно так, как её выдал сервер (с подписью)
      final raw = response.data;
      if (raw is Map) {
        final url = raw['url'] ?? raw['file_url'];
        if (url != null) return url.toString();
      }
      return raw?.toString() ?? '';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Загрузить файл из байтов (для веб-версии, буфера обмена и т.д.)
  Future<String> uploadAttachmentBytes(Uint8List bytes, String fileName) async {
    try {
      final file = MultipartFile.fromBytes(bytes, filename: fileName);
      final formData = FormData.fromMap({
        'file': file,
      });
      final response = await _apiClient.dio.post(
        '/upload/attachment',
        data: formData,
      );
      final raw = response.data;
      if (raw is Map) {
        final url = raw['url'] ?? raw['file_url'];
        if (url != null) return url.toString();
      }
      return raw?.toString() ?? '';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Загрузить голосовое сообщение.
  /// Сервер возвращает подписанную ссылку, которую необходимо передавать без изменений.
  Future<String> uploadVoice(String filePath) async {
    try {
      final fileName = filePath.split('/').last;
      final file = await MultipartFile.fromFile(filePath, filename: fileName);
      final formData = FormData.fromMap({
        'file': file,
      });
      final response = await _apiClient.dio.post(
        '/upload/voice',
        data: formData,
      );
      // Возвращаем ссылку ровно так, как её выдал сервер (с подписью)
      final raw = response.data;
      if (raw is Map) {
        final url = raw['url'] ?? raw['file_url'];
        if (url != null) return url.toString();
      }
      return raw?.toString() ?? '';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Распознать голосовое сообщение в текст
  Future<String> transcribeVoice(String fileUrl) async {
    try {
      final response = await _apiClient.dio.post(
        '/upload/transcribe',
        data: {
          'file_url': fileUrl,
          'voice_url': fileUrl,
          'url': fileUrl,
        },
      );
      
      final rawData = response.data;
      if (rawData is Map) {
        final textVal = rawData['text'] ?? rawData['transcription'] ?? rawData['result'];
        if (textVal != null) {
          if (textVal is String) return textVal;
          if (textVal is Map || textVal is List) {
            return _parseTranscriptionRaw(textVal);
          }
        }
        return _parseTranscriptionRaw(rawData);
      }
      return rawData?.toString() ?? '';
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _parseTranscriptionRaw(dynamic transcription) {
    if (transcription == null) return '';
    if (transcription is String) return transcription;
    if (transcription is Map) {
      return (transcription['text'] ?? transcription['transcription'] ?? transcription['result'] ?? transcription.toString()).toString();
    }
    if (transcription is List) {
      return transcription.map((e) {
        if (e is Map) {
          return (e['text'] ?? e['transcription'] ?? e['result'] ?? e.toString()).toString();
        }
        return e.toString();
      }).join(' ');
    }
    return transcription.toString();
  }

  /// Скачивание любого файла по его URL на сервере (например, из чата)
  Future<List<int>> downloadFile(
    String fileUrl, {
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final fullUrl = fileUrl.startsWith('http')
          ? fileUrl
          : '${ApiClient.baseUrl}${fileUrl.startsWith('/') ? '' : '/'}$fileUrl';

      if (kIsWeb) {
        // 1. Прямое скачивание статических файлов и вложений по URL
        try {
          final response = await _apiClient.dio.get<dynamic>(
            fullUrl,
            options: Options(
              responseType: ResponseType.bytes,
              headers: {'Accept': '*/*'},
            ),
            onReceiveProgress: onProgress,
          );
          final bytes = _extractBytes(response.data);
          if (bytes.isNotEmpty) {
            return bytes;
          }
        } catch (dioErr) {
          debugPrint('⚠️ [UploadService] direct _apiClient.dio download failed: $dioErr');
        }

        // 2. Скачивание через чистый webDio без специфических заголовков
        try {
          final webDio = Dio(BaseOptions(
            connectTimeout: const Duration(seconds: 25),
            receiveTimeout: const Duration(seconds: 40),
          ));
          final response = await webDio.get<dynamic>(
            fullUrl,
            options: Options(
              responseType: ResponseType.bytes,
            ),
            onReceiveProgress: onProgress,
          );
          final bytes = _extractBytes(response.data);
          if (bytes.isNotEmpty) {
            return bytes;
          }
        } catch (webDioErr) {
          debugPrint('⚠️ [UploadService] webDio download failed: $webDioErr');
        }

        // 3. Fallback: эндпоинт /upload/download только если прямое скачивание не сработало
        final uri = Uri.tryParse(fullUrl);
        if (uri != null && uri.path.startsWith('/static/photos/')) {
          final downloadPath = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
          try {
            final response = await _apiClient.dio.get<dynamic>(
              '/upload/download',
              queryParameters: {'url': downloadPath},
              options: Options(
                responseType: ResponseType.bytes,
              ),
              onReceiveProgress: onProgress,
            );
            final bytes = _extractBytes(response.data);
            if (bytes.isNotEmpty) {
              return bytes;
            }
          } catch (e) {
            debugPrint('⚠️ [UploadService] fallback /upload/download failed: $e');
          }
        }

        return [];
      }

      final tempFile = File('${Directory.systemTemp.path}/temp_download_${DateTime.now().microsecondsSinceEpoch}');
      try {
        await _apiClient.dio.download(
          fullUrl,
          tempFile.path,
          options: Options(
            headers: {},
          ),
          onReceiveProgress: onProgress,
        );
        final bytes = await tempFile.readAsBytes();
        return bytes;
      } catch (nativeErr) {
        debugPrint('⚠️ [UploadService] native download failed: $nativeErr, checking /upload/download...');
        final uri = Uri.tryParse(fullUrl);
        final isPhotoAsset = uri != null &&
            (uri.path.startsWith('/static/photos/') ||
             fullUrl.contains('/static/photos/') ||
             uri.path.toLowerCase().endsWith('.jpg') ||
             uri.path.toLowerCase().endsWith('.jpeg') ||
             uri.path.toLowerCase().endsWith('.png') ||
             uri.path.toLowerCase().endsWith('.webp'));
        if (isPhotoAsset) {
          final downloadPath = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
          final response = await _apiClient.dio.get<dynamic>(
            '/upload/download',
            queryParameters: {'url': downloadPath},
            options: Options(responseType: ResponseType.bytes),
            onReceiveProgress: onProgress,
          );
          final bytes = _extractBytes(response.data);
          if (bytes.isNotEmpty) return bytes;
        }
        rethrow;
      } finally {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  List<int> _extractBytes(dynamic data) {
    if (data == null) return [];
    if (data is ByteBuffer) {
      return data.asUint8List();
    } else if (data is Uint8List) {
      return data;
    } else if (data is List<int>) {
      return data;
    }
    return [];
  }

  String _handleError(DioException e) {
    if (e.response?.statusCode == 429) {
      return 'Слишком много запросов. Пожалуйста, подождите немного.';
    }
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
    return 'Ошибка загрузки файла';
  }
}
