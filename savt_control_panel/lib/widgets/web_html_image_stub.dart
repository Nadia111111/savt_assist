// lib/widgets/web_html_image_stub.dart
import 'package:flutter/widgets.dart';

Widget createWebHtmlImage({
  required String url,
  required BoxFit fit,
  Widget? errorWidget,
  Widget? loadingWidget,
}) {
  return Image.network(
    url,
    fit: fit,
    errorBuilder: (_, __, ___) => errorWidget ?? const SizedBox(),
  );
}
