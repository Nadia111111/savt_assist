import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';

class FileSaveHelper {
  static const MethodChannel _downloadsChannel = MethodChannel('com.savt.savt_control_panel/downloads');

  /// Ensures that the filename ends with a valid extension extracted from the file URL if missing.
  static String ensureExtension(String fileName, String? fileUrl) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.pdf') ||
        lowerName.endsWith('.docx') ||
        lowerName.endsWith('.doc') ||
        lowerName.endsWith('.xlsx') ||
        lowerName.endsWith('.xls') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg')) {
      return fileName;
    }
    
    if (fileUrl != null && fileUrl.isNotEmpty) {
      try {
        final uriPath = Uri.parse(fileUrl).path.toLowerCase();
        final lastDot = uriPath.lastIndexOf('.');
        if (lastDot != -1 && lastDot < uriPath.length - 1) {
          final ext = uriPath.substring(lastDot + 1);
          if (ext.length >= 2 && ext.length <= 5) {
            return '$fileName.$ext';
          }
        }
      } catch (_) {}
    }
    
    return '$fileName.pdf';
  }

  /// Получить локальную директорию приложения для сохранения файлов
  static Future<Directory> getStorageDirectory() async {
    Directory? dir;
    if (Platform.isAndroid) {
      try {
        dir = await getExternalStorageDirectory();
      } catch (e) {
        debugPrint('Failed to get external storage directory: $e');
      }
    }
    dir ??= await getApplicationDocumentsDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Проверить, существует ли уже файл локально и не пустой ли он
  static Future<String?> getLocalFilePath(String fileName) async {
    try {
      final dir = await getStorageDirectory();
      final file = File('${dir.path}/$fileName');
      if (await file.exists() && await file.length() > 0) {
        return file.path;
      }
    } catch (_) {}
    return null;
  }

  /// Проверить, скачан ли файл
  static Future<bool> isFileDownloaded(String fileName) async {
    final path = await getLocalFilePath(fileName);
    return path != null;
  }

  static String getMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    return 'application/octet-stream';
  }

  /// Saves bytes to either the photo gallery (if it's an image) or to the user's Downloads/Documents folder (if it's a document/file).
  ///
  /// Returns the saved file path in app-private documents directory so OpenFile can open it reliably without permission errors.
  static Future<String> saveFile({
    required BuildContext context,
    required List<int> bytes,
    required String fileName,
  }) async {
    final lowercaseName = fileName.toLowerCase();
    final isImage = lowercaseName.endsWith('.jpg') ||
                    lowercaseName.endsWith('.jpeg') ||
                    lowercaseName.endsWith('.png') ||
                    lowercaseName.endsWith('.webp') ||
                    lowercaseName.endsWith('.gif');
    final isVideo = lowercaseName.endsWith('.mp4') ||
                    lowercaseName.endsWith('.mov') ||
                    lowercaseName.endsWith('.avi') ||
                    lowercaseName.endsWith('.mkv');

    // 1. Write the file to a secure app-private documents directory first
    // (This always succeeds and OpenFile can access it via FileProvider on Android/iOS without global storage permissions).
    final secureDir = await getStorageDirectory();
    final securePath = '${secureDir.path}/$fileName';
    final secureFile = File(securePath);
    await secureFile.writeAsBytes(bytes);

    // 2. If it's an image or video, attempt to save to Gallery
    if (isImage || isVideo) {
      try {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }
        if (isImage) {
          await Gal.putImage(secureFile.path);
          if (context.mounted) {
            _showSnackBar(context, 'Изображение сохранено в Галерею!', Colors.green);
          }
        } else {
          await Gal.putVideo(secureFile.path);
          if (context.mounted) {
            _showSnackBar(context, 'Видео сохранено в Галерею!', Colors.green);
          }
        }
        return secureFile.path;
      } catch (galError) {
        debugPrint('Failed to save to gallery: $galError');
      }
    }

    // 3. Сохранение файла в системную папку «Загрузки» телефона
    if (Platform.isAndroid) {
      bool savedToDownloads = false;
      try {
        // Пробуем нативный MethodChannel через MediaStore.Downloads (без запроса лишних разрешений)
        final result = await _downloadsChannel.invokeMethod<String>('saveToDownloads', {
          'fileName': fileName,
          'bytes': Uint8List.fromList(bytes),
          'mimeType': getMimeType(fileName),
        });
        if (result != null && result.isNotEmpty) {
          savedToDownloads = true;
          if (context.mounted) {
            _showSnackBar(context, 'Файл сохранён в папку «Загрузки»: $fileName', Colors.green);
          }
        }
      } catch (channelError) {
        debugPrint('MethodChannel saveToDownloads error: $channelError');
      }

      // Fallback для старых устройств Android
      if (!savedToDownloads) {
        try {
          final permissionStatus = await Permission.storage.request();
          if (permissionStatus.isGranted) {
            final publicDir = Directory('/storage/emulated/0/Download');
            if (!await publicDir.exists()) {
              await publicDir.create(recursive: true);
            }
            final publicFile = File('${publicDir.path}/$fileName');
            await publicFile.writeAsBytes(bytes);
            if (context.mounted) {
              _showSnackBar(context, 'Файл сохранён в папку «Загрузки»: $fileName', Colors.green);
            }
            savedToDownloads = true;
          }
        } catch (e) {
          debugPrint('Failed fallback to public storage: $e');
        }
      }

      if (!savedToDownloads && context.mounted) {
        _showSnackBar(context, 'Файл сохранён: $fileName', Colors.green);
      }
    } else if (context.mounted) {
      // iOS - files saved in Documents folder are visible in iOS Files app
      _showSnackBar(context, 'Файл сохранён в Документы: $fileName', Colors.green);
    }

    return secureFile.path;
  }

  static void _showSnackBar(BuildContext context, String text, Color bgColor) {
    if (!context.mounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 4),
      ));
    } catch (_) {}
  }
}
