// lib/services/file_save_helper.dart
import 'package:flutter/material.dart';
import 'file_save_helper_mobile.dart' if (dart.library.html) 'file_save_helper_web.dart';

class FileSaveHelper {
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
  static Future<String> getStorageDirectory() async {
    return FileSaveHelperPlatform.getStorageDirectory();
  }

  /// Проверить, существует ли уже файл локально и не пустой ли он
  static Future<String?> getLocalFilePath(String fileName) async {
    return FileSaveHelperPlatform.getLocalFilePath(fileName);
  }

  /// Проверить, скачан ли файл
  static Future<bool> isFileDownloaded(String fileName) async {
    return FileSaveHelperPlatform.isFileDownloaded(fileName);
  }

  static String getMimeType(String fileName) {
    return FileSaveHelperPlatform.getMimeType(fileName);
  }

  /// Saves bytes to either the photo gallery (if it's an image) or to the user's Downloads/Documents folder (if it's a document/file).
  ///
  /// Returns the saved file path in app-private documents directory so OpenFile can open it reliably without permission errors.
  static Future<String> saveFile({
    required BuildContext context,
    required List<int> bytes,
    required String fileName,
  }) async {
    return FileSaveHelperPlatform.saveFile(
      context: context,
      bytes: bytes,
      fileName: fileName,
    );
  }
}
