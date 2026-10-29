import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MobileClipboardHelper {
  static const MethodChannel _channel = MethodChannel('com.savt.savt_control_panel/downloads');

  /// Получить скопированное изображение из системного буфера обмена (Android)
  static Future<Map<String, dynamic>?> getClipboardImage() async {
    if (kIsWeb) return null;
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod<dynamic>('getClipboardImage');
        if (result is Map) {
          final bytes = result['bytes'] as Uint8List?;
          final fileName = result['fileName']?.toString() ?? 'clipboard_image.png';
          final mimeType = result['mimeType']?.toString() ?? 'image/png';
          if (bytes != null && bytes.isNotEmpty) {
            return {
              'bytes': bytes,
              'fileName': fileName,
              'mimeType': mimeType,
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting clipboard image: $e');
    }
    return null;
  }
}
