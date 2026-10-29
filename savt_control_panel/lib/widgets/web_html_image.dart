// lib/widgets/web_html_image.dart
import 'package:flutter/widgets.dart';
import 'web_html_image_stub.dart'
    if (dart.library.html) 'web_html_image_web.dart';

Widget buildWebHtmlImage({
  required String url,
  required BoxFit fit,
  Widget? errorWidget,
  Widget? loadingWidget,
}) {
  return createWebHtmlImage(
    url: url,
    fit: fit,
    errorWidget: errorWidget,
    loadingWidget: loadingWidget,
  );
}
