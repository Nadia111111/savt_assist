import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_colors.dart';
import '../services/file_save_helper.dart';
import '../services/api_client.dart';
import '../widgets/auth_image.dart';
import '../widgets/web_html_image.dart';
import 'image_editor_screen.dart';
import '../main.dart';
import '../utils/download_helper.dart';

class FullscreenImageViewer extends StatefulWidget {
  static bool skipHeroAnimation = false;
  static ModalRoute? activeRoute;

  static void dismissImmediately() {
    skipHeroAnimation = true;
    if (activeRoute != null && activeRoute!.isActive) {
      final route = activeRoute!;
      activeRoute = null;
      try {
        if (route.animation?.isCompleted == true) {
          route.navigator?.removeRoute(route);
        } else {
          route.navigator?.pop();
        }
      } catch (e) {
        debugPrint('⚠️ [FullscreenImageViewer] dismissImmediately removeRoute failed: $e');
        try {
          route.navigator?.pop();
        } catch (_) {}
      }
    }
  }

  final String? imageUrl;
  final String? localPath;
  final String fileName;
  final String? heroTag;
  final Future<List<int>> Function(String url)? onDownloadRequest;
  final Function(String path)? onSendEdited;
  final Function(Uint8List bytes, String fileName)? onSendEditedBytes;
  final VoidCallback? onShowInChat;
  final VoidCallback? onDelete;

  const FullscreenImageViewer({
    super.key,
    this.imageUrl,
    this.localPath,
    required this.fileName,
    this.heroTag,
    this.onDownloadRequest,
    this.onSendEdited,
    this.onSendEditedBytes,
    this.onShowInChat,
    this.onDelete,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> with SingleTickerProviderStateMixin {
  Uint8List? _editedBytes;
  bool _isDownloading = false;

  late final TransformationController _transformationController;
  late final AnimationController _resetAnimController;
  Animation<double>? _offsetAnimation;
  Animation<double>? _opacityAnimation;
  Animation<double>? _scaleAnimation;

  double _dragOffsetY = 0.0;
  double _bgOpacity = 1.0;
  double _dragScale = 1.0;
  bool _isZoomed = false;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);

    _resetAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _resetAnimController.addListener(() {
      setState(() {
        _dragOffsetY = _offsetAnimation?.value ?? 0.0;
        _bgOpacity = _opacityAnimation?.value ?? 1.0;
        _dragScale = _scaleAnimation?.value ?? 1.0;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    FullscreenImageViewer.activeRoute = ModalRoute.of(context);
  }

  @override
  void dispose() {
    if (FullscreenImageViewer.activeRoute == ModalRoute.of(context)) {
      FullscreenImageViewer.activeRoute = null;
    }
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _resetAnimController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final zoomed = _transformationController.value.getMaxScaleOnAxis() > 1.05;
    if (zoomed != _isZoomed) {
      setState(() {
        _isZoomed = zoomed;
      });
    }
  }

  void _handleDoubleTap() {
    if (_isZoomed) {
      _transformationController.value = Matrix4.identity();
    } else {
      final pos = _doubleTapDetails?.localPosition ?? Offset.zero;
      final zoomed = Matrix4.identity()
        ..translate(-pos.dx * 1.5, -pos.dy * 1.5)
        ..scale(2.5);
      _transformationController.value = zoomed;
    }
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_isZoomed) return;
    if (_resetAnimController.isAnimating) {
      _resetAnimController.stop();
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    final newOffset = _dragOffsetY + details.delta.dy;
    if (newOffset >= 0) {
      setState(() {
        _dragOffsetY = newOffset;
        _bgOpacity = (1.0 - (_dragOffsetY / 340.0)).clamp(0.0, 1.0);
        _dragScale = (1.0 - (_dragOffsetY / 1200.0)).clamp(0.70, 1.0);
      });
    } else {
      setState(() {
        _dragOffsetY = newOffset * 0.20;
        _bgOpacity = 1.0;
        _dragScale = 1.0;
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isZoomed) return;
    final velocity = details.primaryVelocity ?? 0.0;
    if (_dragOffsetY > 80.0 || velocity > 350.0) {
      Navigator.of(context).pop();
    } else {
      _animateReset();
    }
  }

  void _onVerticalDragCancel() {
    if (_isZoomed) return;
    _animateReset();
  }

  void _animateReset() {
    if (_dragOffsetY == 0.0 && _bgOpacity == 1.0 && _dragScale == 1.0) return;
    _offsetAnimation = Tween<double>(begin: _dragOffsetY, end: 0.0).animate(
      CurvedAnimation(parent: _resetAnimController, curve: Curves.easeOutCubic),
    );
    _opacityAnimation = Tween<double>(begin: _bgOpacity, end: 1.0).animate(
      CurvedAnimation(parent: _resetAnimController, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: _dragScale, end: 1.0).animate(
      CurvedAnimation(parent: _resetAnimController, curve: Curves.easeOutCubic),
    );
    _resetAnimController.forward(from: 0.0);
  }

  Future<Uint8List?> _getImageBytes() async {
    if (_editedBytes != null) return _editedBytes;
    if (!kIsWeb && widget.localPath != null) {
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
          if (bytes.isNotEmpty) {
            final uint8List = Uint8List.fromList(bytes);
            AuthImage.cacheBytes(widget.imageUrl!, uint8List);
            return uint8List;
          }
        } catch (e) {
          debugPrint('⚠️ [FullscreenImageViewer] onDownloadRequest failed: $e');
        }
      }

      try {
        final bytes = await uploadService.downloadFile(widget.imageUrl!);
        if (bytes.isNotEmpty) {
          final uint8List = Uint8List.fromList(bytes);
          AuthImage.cacheBytes(widget.imageUrl!, uint8List);
          return uint8List;
        }
      } catch (e) {
        debugPrint('⚠️ [FullscreenImageViewer] uploadService.downloadFile failed: $e');
      }

      if (kIsWeb) {
        try {
          final fullUrl = widget.imageUrl!.startsWith('http')
              ? widget.imageUrl!
              : '${ApiClient.baseUrl}${widget.imageUrl!.startsWith('/') ? '' : '/'}${widget.imageUrl!}';
          final webBytes = await fetchWebImageBytes(fullUrl);
          if (webBytes != null && webBytes.isNotEmpty) {
            AuthImage.cacheBytes(widget.imageUrl!, webBytes);
            return webBytes;
          }
        } catch (e) {
          debugPrint('⚠️ [FullscreenImageViewer] fetchWebImageBytes failed: $e');
        }
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
      } else if (!kIsWeb && widget.localPath != null) {
        try {
          bytes = await File(widget.localPath!).readAsBytes();
        } catch (_) {}
      } else if (widget.imageUrl != null) {
        final cached = AuthImage.getCachedBytes(widget.imageUrl!);
        if (cached != null) {
          bytes = cached;
        } else {
          showProgress = true;
          showDownloadProgressDialog(
              context, widget.fileName, progressController.stream);
          try {
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
          } catch (downloadErr) {
            debugPrint('Failed to download image bytes: $downloadErr');
            if (kIsWeb) {
              if (showProgress && mounted) {
                Navigator.pop(context);
                showProgress = false;
              }
              final fullUrl = widget.imageUrl!.startsWith('http')
                  ? widget.imageUrl!
                  : '${ApiClient.baseUrl}${widget.imageUrl!.startsWith('/') ? '' : '/'}${widget.imageUrl!}';
              await FileSaveHelper.saveUrl(
                context: context,
                url: fullUrl,
                fileName: widget.fileName,
              );
              return;
            } else {
              rethrow;
            }
          }
        }
      }

      if (showProgress && mounted) {
        Navigator.pop(context); // Close progress dialog
        showProgress = false;
      }

      if (bytes == null) {
        if (kIsWeb && widget.imageUrl != null) {
          final fullUrl = widget.imageUrl!.startsWith('http')
              ? widget.imageUrl!
              : '${ApiClient.baseUrl}${widget.imageUrl!.startsWith('/') ? '' : '/'}${widget.imageUrl!}';
          await FileSaveHelper.saveUrl(
            context: context,
            url: fullUrl,
            fileName: widget.fileName,
          );
          return;
        }
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
            content: Text('Ошибка скачивания: $e',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            width: kIsWeb ? 420 : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    } finally {
      progressController.close();
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _editImage() async {
    setState(() => _isDownloading = true);
    try {
      final bytes = await _getImageBytes();
      if (!mounted) return;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Не удалось загрузить данные изображения для редактирования',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            width: kIsWeb ? 420 : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
        return;
      }

      final edited = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (_) => ImageEditorScreen(imageBytes: bytes),
        ),
      );

      if (edited != null && mounted) {
        setState(() {
          _editedBytes = edited;
        });
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Widget _buildImageContent(BuildContext context) {
    if (_editedBytes != null) {
      return Image.memory(_editedBytes!, fit: BoxFit.contain);
    }

    if (!kIsWeb && widget.localPath != null && File(widget.localPath!).existsSync()) {
      return Image.file(File(widget.localPath!), fit: BoxFit.contain);
    }

    if (widget.imageUrl != null) {
      final cachedBytes = AuthImage.getCachedBytes(widget.imageUrl!);
      if (cachedBytes != null) {
        return Image.memory(cachedBytes, fit: BoxFit.contain);
      }

      final screenSize = MediaQuery.of(context).size;

      // On Web, render AuthImage directly via HTML <img> tag without delay
      if (kIsWeb) {
        return AuthImage(
          url: widget.imageUrl!,
          fit: BoxFit.contain,
          width: screenSize.width,
          height: screenSize.height,
        );
      }

      return FutureBuilder<Uint8List?>(
        future: _getImageBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(snapshot.data!, fit: BoxFit.contain);
          }
          return AuthImage(
            url: widget.imageUrl!,
            fit: BoxFit.contain,
            width: screenSize.width,
            height: screenSize.height,
          );
        },
      );
    }

    return const Icon(Icons.broken_image, color: Colors.white24, size: 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: _bgOpacity),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Opacity(
          opacity: _bgOpacity,
          child: AppBar(
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
              if (widget.onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Удалить сообщение?'),
                        content: const Text('Это сообщение с файлом будет удалено для всех участников.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Отмена'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.pop(context);
                              widget.onDelete!();
                            },
                            child: const Text('Удалить'),
                          ),
                        ],
                      ),
                    );
                  },
                  tooltip: 'Удалить',
                ),
            ],
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTapDown: (d) => _doubleTapDetails = d,
        onDoubleTap: _handleDoubleTap,
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        onVerticalDragCancel: _onVerticalDragCancel,
        child: Stack(
          children: [
            Center(
              child: Transform.translate(
                offset: Offset(0, _dragOffsetY),
                child: Transform.scale(
                  scale: _dragScale,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    panEnabled: _isZoomed,
                    scaleEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: (!kIsWeb && widget.heroTag != null && !FullscreenImageViewer.skipHeroAnimation)
                        ? Hero(
                            tag: widget.heroTag!,
                            flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                              if (FullscreenImageViewer.skipHeroAnimation) {
                                return const SizedBox.shrink();
                              }
                              final Hero hero = flightDirection == HeroFlightDirection.push
                                  ? (toHeroContext.widget as Hero)
                                  : (fromHeroContext.widget as Hero);
                              return AnimatedBuilder(
                                animation: animation,
                                builder: (context, child) {
                                  final radius = flightDirection == HeroFlightDirection.push
                                      ? (1.0 - animation.value) * 12.0
                                      : animation.value * 12.0;
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(radius),
                                    child: hero.child,
                                  );
                                },
                              );
                            },
                            child: _buildImageContent(context),
                          )
                        : _buildImageContent(context),
                  ),
                ),
              ),
            ),
            if (_editedBytes != null &&
                (widget.onSendEdited != null || widget.onSendEditedBytes != null))
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Opacity(
                  opacity: _bgOpacity,
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
                        if (_editedBytes == null) return;
                        final fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}.png';

                        if (widget.onSendEditedBytes != null) {
                          widget.onSendEditedBytes!(_editedBytes!, fileName);
                          if (context.mounted) {
                            Navigator.pop(context, true);
                          }
                          return;
                        }

                        if (!kIsWeb && widget.onSendEdited != null) {
                          try {
                            final tempDir = await getTemporaryDirectory();
                            final tempFile = File(
                                '${tempDir.path}/edited_chat_${DateTime.now().millisecondsSinceEpoch}.png');
                            await tempFile.writeAsBytes(_editedBytes!);
                            widget.onSendEdited!(tempFile.path);
                          } catch (e) {
                            debugPrint('Error writing edited file: $e');
                          }
                          if (context.mounted) {
                            Navigator.pop(context, true);
                          }
                          return;
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Отправить отредактированное фото в чат'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
