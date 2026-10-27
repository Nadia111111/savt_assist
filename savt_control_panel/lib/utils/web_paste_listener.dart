import 'dart:typed_data';
import 'web_paste_listener_stub.dart'
    if (dart.library.html) 'web_paste_listener_web.dart';

typedef OnFilePastedCallback = void Function(
  Uint8List bytes,
  String fileName,
  String mimeType,
);

class WebPasteListener {
  static void initialize({required OnFilePastedCallback onFilePasted}) {
    WebPasteListenerImpl.initialize(onFilePasted: onFilePasted);
  }

  static void dispose() {
    WebPasteListenerImpl.dispose();
  }
}
