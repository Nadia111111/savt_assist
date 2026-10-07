import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'api_client.dart';

class UploadService {
  final ApiClient _apiClient;

  UploadService(this._apiClient);

  /// Загрузить файл (изображение, документ, видео)
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
          print('Ошибка сжатия изображения: $e');
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
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
      // Ожидаемый ответ { "file_url": "/static/attachments/abc.jpg" } или { "url": "..." }
      return (response.data['file_url'] ?? response.data['url'] ?? '').toString();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Загрузить голосовое сообщение
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
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
      return response.data['url'];
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

      final tempFile = File('${Directory.systemTemp.path}/temp_download_${DateTime.now().microsecondsSinceEpoch}');
      await _apiClient.dio.download(
        fullUrl,
        tempFile.path,
        onReceiveProgress: onProgress,
      );
      final bytes = await tempFile.readAsBytes();
      try {
        await tempFile.delete();
      } catch (_) {}
      return bytes;
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
    return 'Ошибка загрузки файла';
  }
}
