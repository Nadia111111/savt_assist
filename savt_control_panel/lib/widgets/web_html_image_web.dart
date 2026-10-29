// lib/widgets/web_html_image_web.dart
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget createWebHtmlImage({
  required String url,
  required BoxFit fit,
  Widget? errorWidget,
  Widget? loadingWidget,
}) {
  return WebHtmlImage(
    url: url,
    fit: fit,
    errorWidget: errorWidget,
    loadingWidget: loadingWidget,
  );
}

class WebHtmlImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget? errorWidget;
  final Widget? loadingWidget;

  const WebHtmlImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.errorWidget,
    this.loadingWidget,
  });

  @override
  State<WebHtmlImage> createState() => _WebHtmlImageState();
}

class _WebHtmlImageState extends State<WebHtmlImage> {
  static final Set<String> _registeredTypes = {};
  late String _viewType;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(WebHtmlImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.fit != widget.fit) {
      _hasError = false;
      _register();
    }
  }

  void _register() {
    final clean = widget.url.trim();
    final hash = clean.hashCode.abs().toString();
    final fitName = widget.fit.name;
    _viewType = 'web-img-$hash-$fitName';

    if (!_registeredTypes.contains(_viewType)) {
      _registeredTypes.add(_viewType);

      final objectFit = (widget.fit == BoxFit.contain)
          ? 'contain'
          : (widget.fit == BoxFit.fill ? 'fill' : 'cover');

      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        final img = html.ImageElement()
          ..src = clean
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..style.margin = '0'
          ..style.padding = '0'
          ..style.objectFit = objectFit
          ..style.pointerEvents = 'none'
          ..style.userSelect = 'none';

        img.onError.listen((_) {
          if (mounted && !_hasError) {
            setState(() => _hasError = true);
          }
        });

        return img;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorWidget ??
          const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }

    return HtmlElementView(viewType: _viewType);
  }
}
