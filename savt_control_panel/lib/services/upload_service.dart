import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class UploadService {
  final ApiClient _apiClient;

  static const int maxFileSizeBytes = 30 * 1024 * 1024; // 30 MB
  static const int maxVideoSizeBytes = 100 * 1024 * 1024; // 100 MB
  static const int maxVoiceSizeBytes = 25 * 1024 * 1024; // 25 MB

  static bool isVideo(String pathOrName) {
    final lower = pathOrName.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.3gp') ||
        lower.endsWith('.flv') ||
        lower.endsWith('.m4v');
  }

  UploadService(this._apiClient);

  /// Загрузить файл (изображение, документ, видео).
  /// Сервер возвращает подписанную ссылку, которую необходимо передавать без изменений.
  Future<String> uploadAttachment(String filePath, {bool compress = true}) async {
    try {
      if (!kIsWeb) {
        final originFile = File(filePath);
        if (await originFile.exists()) {
          final originalLength = await originFile.length();
          final bool isVid = isVideo(filePath);
          if (isVid && originalLength > maxVideoSizeBytes) {
            throw 'Файл слишком большой';
          }
          if (!isVid && originalLength > maxFileSizeBytes) {
            throw 'Файл слишком большой';
          }
        }
      }

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

      if (!kIsWeb) {
        final targetFile = File(targetPath);
        if (await targetFile.exists()) {
          final targetLength = await targetFile.length();
          final bool isVid = isVideo(targetPath);
          if (isVid && targetLength > maxVideoSizeBytes) {
            throw 'Файл слишком большой';
          }
          if (!isVid && targetLength > maxFileSizeBytes) {
            throw 'Файл слишком большой';
          }
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
      final bool isVid = isVideo(fileName);
      if (isVid && bytes.length > maxVideoSizeBytes) {
        throw 'Файл слишком большой';
      }
      if (!isVid && bytes.length > maxFileSizeBytes) {
        throw 'Файл слишком большой';
      }

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
      if (!kIsWeb) {
        final f = File(filePath);
        if (await f.exists()) {
          final len = await f.length();
          if (len > maxVoiceSizeBytes) {
            throw 'Файл слишком большой';
          }
        }
      }

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
    if (e.response?.statusCode == 413) {
      return 'Файл слишком большой';
    }
    if (e.response?.statusCode == 429) {
      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        final detail = e.response!.data['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
      }
      return 'Суточный лимит загрузок исчерпан (500 МБ). Попробуйте позже';
    }
    if (e.response?.statusCode == 422) {
      return 'Проверьте введённые данные';
    }
    if (e.response?.statusCode == 502 ||
        e.response?.statusCode == 503 ||
        e.response?.statusCode == 504) {
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      if (detail is String && detail.isNotEmpty) return detail;
      return 'Сервис временно недоступен, попробуйте ещё раз через минуту';
    }
    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      final detail = e.response!.data['detail'];
      if (detail is String) return detail;
      if (detail is List) {
        return 'Проверьте введённые данные';
      }
      return detail.toString();
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Сервис временно недоступен, попробуйте ещё раз через минуту';
    }
    return 'Ошибка загрузки файла';
  }
}
