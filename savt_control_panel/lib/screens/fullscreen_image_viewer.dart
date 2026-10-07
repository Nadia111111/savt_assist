import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_colors.dart';
import '../services/file_save_helper.dart';
import '../widgets/auth_image.dart';
import 'image_editor_screen.dart';
import '../main.dart';
import '../utils/download_helper.dart';

class FullscreenImageViewer extends StatefulWidget {
  final String? imageUrl;
  final String? localPath;
  final String fileName;
  final String? heroTag;
  final Future<List<int>> Function(String url)? onDownloadRequest;
  final Function(String path)? onSendEdited;
  final VoidCallback? onShowInChat;

  const FullscreenImageViewer({
    super.key,
    this.imageUrl,
    this.localPath,
    required this.fileName,
    this.heroTag,
    this.onDownloadRequest,
    this.onSendEdited,
    this.onShowInChat,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  Uint8List? _editedBytes;
  bool _isDownloading = false;

  Future<Uint8List?> _getImageBytes() async {
    if (_editedBytes != null) return _editedBytes;
    if (widget.localPath != null) {
      try {
        return await File(widget.localPath!).readAsBytes();
      } catch (_) {}
    }
    if (widget.imageUrl != null) {
      final cached = AuthImage.getCachedBytes(widget.imageUrl!);
      if (cached != null) return cached;

      if (widget.onDownloadRequest != null) {
        try {
          final bytes = await widget.onDownloadRequest!(widget.imageUrl!);
          final uint8List = Uint8List.fromList(bytes);
          AuthImage.cacheBytes(widget.imageUrl!, uint8List);
          return uint8List;
        } catch (_) {}
      }
    }
    return null;
  }

  Future<void> _downloadImage() async {
    setState(() => _isDownloading = true);
    final progressController = StreamController<double>();
    bool showProgress = false;

    try {
      Uint8List? bytes;
      if (_editedBytes != null) {
        bytes = _editedBytes;
      } else if (widget.localPath != null) {
        bytes = await File(widget.localPath!).readAsBytes();
      } else if (widget.imageUrl != null) {
        final cached = AuthImage.getCachedBytes(widget.imageUrl!);
        if (cached != null) {
          bytes = cached;
        } else {
          showProgress = true;
          showDownloadProgressDialog(
              context, widget.fileName, progressController.stream);
          final downloadedBytes = await uploadService.downloadFile(
            widget.imageUrl!,
            onProgress: (sent, total) {
              if (total > 0) {
                progressController.add(sent / total);
              }
            },
          );
          bytes = Uint8List.fromList(downloadedBytes);
          AuthImage.cacheBytes(widget.imageUrl!, bytes);
        }
      }

      if (showProgress && mounted) {
        Navigator.pop(context); // Close progress dialog
      }

      if (bytes == null) {
        throw Exception('Не удалось загрузить данные изображения');
      }

      if (!mounted) return;
      await FileSaveHelper.saveFile(
        context: context,
        bytes: bytes,
        fileName: widget.fileName,
      );
    } catch (e) {
      if (showProgress && mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка скачивания: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      progressController.close();
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _editImage() async {
    final bytes = await _getImageBytes();
    if (!mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Изображение еще загружается или недоступно')),
      );
      return;
    }

    if (!mounted) return;
    final edited = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageEditorScreen(imageBytes: bytes),
      ),
    );

    if (edited != null) {
      setState(() {
        _editedBytes = edited;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.onShowInChat != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              onPressed: widget.onShowInChat,
              tooltip: 'Показать в чате',
            ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _editImage,
            tooltip: 'Редактировать',
          ),
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.download, color: Colors.white),
            onPressed: _isDownloading ? null : _downloadImage,
            tooltip: 'Скачать на устройство',
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: widget.heroTag != null
                  ? Hero(
                      tag: widget.heroTag!,
                      flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            final radius = flightDirection == HeroFlightDirection.push
                                ? (1.0 - animation.value) * 12.0
                                : animation.value * 12.0;
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(radius),
                              child: (toHeroContext.widget as Hero).child,
                            );
                          },
                        );
                      },
                      child: _editedBytes != null
                          ? Image.memory(_editedBytes!)
                          : (widget.localPath != null
                              ? Image.file(File(widget.localPath!))
                              : (widget.imageUrl != null
                                  ? AuthImage(
                                      url: widget.imageUrl!,
                                      fit: BoxFit.contain)
                                  : const Icon(Icons.broken_image,
                                      color: Colors.white24, size: 100))),
                    )
                  : (_editedBytes != null
                      ? Image.memory(_editedBytes!)
                      : (widget.localPath != null
                          ? Image.file(File(widget.localPath!))
                          : (widget.imageUrl != null
                              ? AuthImage(
                                  url: widget.imageUrl!, fit: BoxFit.contain)
                              : const Icon(Icons.broken_image,
                                  color: Colors.white24, size: 100)))),
            ),
          ),
          if (_editedBytes != null && widget.onSendEdited != null)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: SafeArea(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final tempDir = await getTemporaryDirectory();
                    final tempFile = File(
                        '${tempDir.path}/edited_chat_${DateTime.now().millisecondsSinceEpoch}.png');
                    await tempFile.writeAsBytes(_editedBytes!);
                    widget.onSendEdited!(tempFile.path);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Отправить отредактированное фото в чат'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
