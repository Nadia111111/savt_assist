// lib/widgets/secure_image.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../main.dart';

class SecureImage extends StatefulWidget {
  final String? url;
  final BoxFit fit;
  final Widget? errorWidget;
  final Widget? loadingWidget;

  const SecureImage({
    super.key,
    this.url,
    this.fit = BoxFit.cover,
    this.errorWidget,
    this.loadingWidget,
  });

  @override
  State<SecureImage> createState() => _SecureImageState();
}

class _SecureImageState extends State<SecureImage> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadImage() async {
    if (widget.url == null) {
      setState(() {
        _isLoading = false;
        _error = 'URL not provided';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await apiClient.dio.get(
        widget.url!,
        options: Options(responseType: ResponseType.bytes),
      );

      if (mounted) {
        setState(() {
          _imageBytes = response.data as Uint8List;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ??
          Container(
            color: Colors.grey.shade300,
            child: const Center(child: CircularProgressIndicator()),
          );
    }

    if (_error != null || _imageBytes == null) {
      return widget.errorWidget ??
          Container(
            color: Colors.grey.shade300,
            child: const Icon(Icons.broken_image, size: 40),
          );
    }

    return Image.memory(
      _imageBytes!,
      fit: widget.fit,
      errorBuilder: (_, __, ___) =>
          widget.errorWidget ??
          Container(
            color: Colors.grey.shade300,
            child: const Icon(Icons.broken_image, size: 40),
          ),
    );
  }
}
