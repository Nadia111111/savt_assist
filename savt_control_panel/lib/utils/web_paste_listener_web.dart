import 'dart:html' as html;
import 'dart:typed_data';
import 'web_paste_listener.dart';

class WebPasteListenerImpl {
  static html.EventListener? _listener;
  static int _lastPasteTime = 0;

  static void initialize({required OnFilePastedCallback onFilePasted}) {
    dispose();

    _listener = (html.Event event) {
      if (event is! html.ClipboardEvent) return;
      final clipboardData = event.clipboardData;
      if (clipboardData == null) return;

      // Throttle rapid double triggers
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastPasteTime < 300) return;

      // 1. Check items (standard for images / screenshots from clipboard)
      final items = clipboardData.items;
      if (items != null) {
        final int len = items.length ?? 0;
        for (int i = 0; i < len; i++) {
          final item = items[i];
          final type = (item.type ?? '').toLowerCase();
          final isImage = type.startsWith('image/');
          final isFile = item.kind == 'file';

          if (isImage || isFile) {
            final file = item.getAsFile();
            if (file != null) {
              _lastPasteTime = now;
              event.preventDefault();
              _processFile(file, type, onFilePasted);
              return;
            }
          }
        }
      }

      // 2. Check files
      final files = clipboardData.files;
      if (files != null && files.isNotEmpty) {
        final file = files.first;
        _lastPasteTime = now;
        event.preventDefault();
        _processFile(file, file.type, onFilePasted);
      }
    };

    html.document.addEventListener('paste', _listener!);
  }

  static void _processFile(
    html.File file,
    String type,
    OnFilePastedCallback onFilePasted,
  ) {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoadEnd.first.then((_) {
      final result = reader.result;
      if (result == null) return;

      final Uint8List bytes;
      if (result is ByteBuffer) {
        bytes = Uint8List.view(result);
      } else if (result is Uint8List) {
        bytes = result;
      } else {
        bytes = Uint8List.fromList((result as List<dynamic>).cast<int>());
      }

      String fileName = file.name;
      if (fileName.isEmpty) {
        final ext = type.contains('jpeg') || type.contains('jpg')
            ? 'jpg'
            : type.contains('png')
                ? 'png'
                : type.contains('gif')
                    ? 'gif'
                    : type.contains('webp')
                        ? 'webp'
                        : type.contains('pdf')
                            ? 'pdf'
                            : 'png';
        fileName = 'pasted_image_${DateTime.now().millisecondsSinceEpoch}.$ext';
      }

      final effectiveMime = type.isNotEmpty ? type : 'image/png';
      onFilePasted(bytes, fileName, effectiveMime);
    });
  }

  static void dispose() {
    if (_listener != null) {
      html.document.removeEventListener('paste', _listener!);
      _listener = null;
    }
  }
}
