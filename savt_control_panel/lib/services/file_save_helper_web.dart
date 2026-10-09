import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';

class FileSaveHelperPlatform {
  static Future<String> getStorageDirectory() async {
    // On web, we don't have a real file system, but we return a placeholder
    return '/web-virtual-fs';
  }

  static Future<String?> getLocalFilePath(String fileName) async {
    // On web, files aren't stored in a persistent local path accessible to the app
    // We could check IndexedDB or localStorage, but for simplicity return null
    // This will cause re-download which is fine for web
    return null;
  }

  static Future<bool> isFileDownloaded(String fileName) async {
    // On web, we don't track local files persistently
    return false;
  }

  static Future<String> saveFile({
    required BuildContext context,
    required List<int> bytes,
    required String fileName,
  }) async {
    final mimeType = getMimeType(fileName);
    final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    
    // Clean up the object URL after a short delay
    Future.delayed(const Duration(seconds: 10), () {
      html.Url.revokeObjectUrl(url);
    });

    if (context.mounted) {
      _showSnackBar(context, 'Файл загружается: $fileName', Colors.green);
    }

    // Return a virtual path for compatibility
    return '/web-virtual-fs/$fileName';
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
}