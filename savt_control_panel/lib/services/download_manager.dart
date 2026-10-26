// lib/services/download_manager.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../main.dart';
import 'file_save_helper.dart';

/// Состояние текущей активной загрузки
class ActiveDownload {
  final int docId;
  final String fileName;
  final CancelToken cancelToken;
  final ValueNotifier<double> progress = ValueNotifier<double>(0.0);
  final ValueNotifier<int> receivedBytes = ValueNotifier<int>(0);
  final ValueNotifier<int> totalBytes = ValueNotifier<int>(0);
  final ValueNotifier<bool> isMinimized = ValueNotifier<bool>(false);
  final ValueNotifier<String> statusText =
      ValueNotifier<String>('Подключение...');

  final Future<void> Function(String savePath)? onComplete;

  ActiveDownload({
    required this.docId,
    required this.fileName,
    required this.cancelToken,
    this.onComplete,
  });

  void dispose() {
    progress.dispose();
    receivedBytes.dispose();
    totalBytes.dispose();
    isMinimized.dispose();
    statusText.dispose();
  }
}

/// Сервис управления скачиванием файлов с поддержкой отмены, фонового режима и мини-окна
class DownloadManager {
  static final DownloadManager instance = DownloadManager._();
  DownloadManager._();

  final ValueNotifier<ActiveDownload?> activeDownload =
      ValueNotifier<ActiveDownload?>(null);

  bool get isDownloading => activeDownload.value != null;
  bool isDocDownloading(int docId) => activeDownload.value?.docId == docId;

  BuildContext? _currentDialogContext;

  /// Запуск скачивания документа
  Future<void> startDownload({
    required BuildContext context,
    required int docId,
    required String fileName,
    required Future<List<int>> Function(
      CancelToken cancelToken,
      void Function(int received, int total) onProgress,
    ) downloadAction,
    Future<void> Function(String savePath)? onCompleted,
  }) async {
    if (activeDownload.value != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Уже выполняется другое скачивание'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final cancelToken = CancelToken();
    final active = ActiveDownload(
      docId: docId,
      fileName: fileName,
      cancelToken: cancelToken,
      onComplete: onCompleted,
    );

    activeDownload.value = active;

    // Открываем модальное окно прогресса
    _showDownloadDialog(context, active);

    try {
      final bytes = await downloadAction(
        cancelToken,
        (received, total) {
          active.receivedBytes.value = received;
          active.totalBytes.value = total;
          if (total > 0) {
            final p = (received / total).clamp(0.0, 1.0);
            active.progress.value = p;
            active.statusText.value = 'Скачивание...';
          } else {
            active.progress.value = 0.0;
            active.statusText.value = 'Загрузка данных...';
          }
        },
      );

      // Загрузка завершена
      _dismissDialogIfOpen();

      final rootContext = ControlPanelApp.navigatorKey.currentContext;
      if (rootContext == null || !rootContext.mounted) return;
      final savePath = await FileSaveHelper.saveFile(
        context: rootContext,
        bytes: bytes,
        fileName: fileName,
      );

      activeDownload.value = null;
      active.dispose();

      if (onCompleted != null) {
        await onCompleted(savePath);
      }

      if (rootContext.mounted) {
        ScaffoldMessenger.of(rootContext).showSnackBar(
          SnackBar(
            content: Text('Файл "$fileName" успешно скачан'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
            action: (!kIsWeb && savePath != 'Галерея')
                ? SnackBarAction(
                    label: 'Открыть',
                    textColor: Colors.white,
                    onPressed: () {
                      OpenFile.open(savePath);
                    },
                  )
                : null,
          ),
        );
      }

      if (savePath != 'Галерея' && !kIsWeb) {
        final result = await OpenFile.open(savePath);
        if (result.type != ResultType.done && rootContext.mounted) {
          debugPrint('Could not auto-open file: ${result.message}');
        }
      }
    } catch (e) {
      _dismissDialogIfOpen();

      final wasCancelled = CancelToken.isCancel(e as dynamic) ||
          e.toString().contains('cancelled_by_user') ||
          e.toString().contains('Загрузка отменена');

      activeDownload.value = null;
      active.dispose();

      final rootContext = ControlPanelApp.navigatorKey.currentContext;
      if (rootContext != null && rootContext.mounted) {
        if (wasCancelled) {
          ScaffoldMessenger.of(rootContext).showSnackBar(
            SnackBar(
              content: Text('Скачивание "$fileName" отменено'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(rootContext).showSnackBar(
            SnackBar(
              content: Text('Ошибка скачивания: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// Свернуть окно скачивания в фоновое маленькое окошко
  void minimizeDownload() {
    final active = activeDownload.value;
    if (active != null) {
      _dismissDialogIfOpen();
      active.isMinimized.value = true;
    }
  }

  /// Развернуть обратно в модальное окно
  void expandDownload(BuildContext? context) {
    final active = activeDownload.value;
    final targetContext =
        context ?? ControlPanelApp.navigatorKey.currentContext;
    if (active != null && targetContext != null && targetContext.mounted) {
      active.isMinimized.value = false;
      _showDownloadDialog(targetContext, active);
    }
  }

  /// Отменить текущую загрузку
  void cancelDownload({bool showToast = true}) {
    final active = activeDownload.value;
    if (active != null) {
      active.cancelToken.cancel('cancelled_by_user');
      _dismissDialogIfOpen();
    }
  }

  void _dismissDialogIfOpen() {
    if (_currentDialogContext != null) {
      try {
        Navigator.of(_currentDialogContext!).pop();
      } catch (_) {}
      _currentDialogContext = null;
    }
  }

  void _showDownloadDialog(BuildContext context, ActiveDownload active) {
    _dismissDialogIfOpen();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        _currentDialogContext = dialogCtx;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            // Кнопка «Назад» на телефоне сворачивает в фон
            minimizeDownload();
          },
          child: DownloadProgressDialogWidget(
            active: active,
            onMinimize: minimizeDownload,
            onCancel: () => cancelDownload(showToast: true),
          ),
        );
      },
    ).then((_) {
      if (_currentDialogContext != null) {
        _currentDialogContext = null;
      }
    });
  }
}

/// Модальный диалог прогресса скачивания
class DownloadProgressDialogWidget extends StatelessWidget {
  final ActiveDownload active;
  final VoidCallback onMinimize;
  final VoidCallback onCancel;

  const DownloadProgressDialogWidget({
    super.key,
    required this.active,
    required this.onMinimize,
    required this.onCancel,
  });

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.downloading,
                color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Загрузка файла',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 24),
            tooltip: 'Свернуть в фон',
            onPressed: onMinimize,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Отменить',
            onPressed: onCancel,
          ),
        ],
      ),
      content: ValueListenableBuilder<double>(
        valueListenable: active.progress,
        builder: (context, progress, _) {
          return ValueListenableBuilder<int>(
            valueListenable: active.receivedBytes,
            builder: (context, received, _) {
              return ValueListenableBuilder<int>(
                valueListenable: active.totalBytes,
                builder: (context, total, _) {
                  final isDeterminate = progress > 0.005 || total > 0;
                  final receivedStr = _formatBytes(received);
                  final totalStr = _formatBytes(total);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active.fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: isDeterminate ? progress.clamp(0.0, 1.0) : null,
                          minHeight: 8,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isDeterminate
                                ? (totalStr.isNotEmpty
                                    ? '$receivedStr / $totalStr'
                                    : 'Скачивание...')
                                : 'Подключение...',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            isDeterminate
                                ? '${(progress * 100).toInt()}%'
                                : '',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Отмена'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          ),
          onPressed: onCancel,
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.arrow_downward_rounded, size: 16),
          label: const Text('Свернуть в фон'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onMinimize,
        ),
      ],
    );
  }
}

/// Обертка MaterialApp для отображения мини-окна поверх всех экранов
class DownloadOverlayWrapper extends StatelessWidget {
  final Widget child;
  const DownloadOverlayWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const DownloadMiniWindowOverlay(),
      ],
    );
  }
}

/// Плавающее маленькое окошко скачивания при сворачивании
class DownloadMiniWindowOverlay extends StatefulWidget {
  const DownloadMiniWindowOverlay({super.key});

  @override
  State<DownloadMiniWindowOverlay> createState() =>
      _DownloadMiniWindowOverlayState();
}

class _DownloadMiniWindowOverlayState extends State<DownloadMiniWindowOverlay> {
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActiveDownload?>(
      valueListenable: DownloadManager.instance.activeDownload,
      builder: (context, active, _) {
        if (active == null) {
          _position = null;
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<bool>(
          valueListenable: active.isMinimized,
          builder: (context, isMinimized, _) {
            if (!isMinimized) {
              return const SizedBox.shrink();
            }

            final mediaQuery = MediaQuery.of(context);
            final screenSize = mediaQuery.size;
            final topPadding = mediaQuery.padding.top;
            final bottomPadding = mediaQuery.padding.bottom;

            final cardWidth = (screenSize.width - 32).clamp(280.0, 360.0);
            const cardHeight = 64.0;

            // По умолчанию размещаем внизу экрана над таб-баром
            _position ??= Offset(
              (screenSize.width - cardWidth) / 2,
              screenSize.height - bottomPadding - cardHeight - 88,
            );

            // Клампинг границ экрана
            const minX = 12.0;
            final maxX = screenSize.width - cardWidth - 12.0;
            final minY = topPadding + 12.0;
            final maxY = screenSize.height - bottomPadding - cardHeight - 12.0;

            final clampedX = _position!.dx.clamp(minX, maxX);
            final clampedY = _position!.dy.clamp(minY, maxY);

            final theme = Theme.of(context);

            return Positioned(
              left: clampedX,
              top: clampedY,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _position = Offset(
                      clampedX + details.delta.dx,
                      clampedY + details.delta.dy,
                    );
                  });
                },
                child: Material(
                  color: Colors.transparent,
                  elevation: 10,
                  shadowColor: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      DownloadManager.instance.expandDownload(context);
                    },
                    child: Container(
                      width: cardWidth,
                      height: cardHeight,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: ValueListenableBuilder<double>(
                        valueListenable: active.progress,
                        builder: (context, progress, _) {
                          return ValueListenableBuilder<int>(
                            valueListenable: active.totalBytes,
                            builder: (context, total, _) {
                              final isDeterminate =
                                  progress > 0.005 || total > 0;
                              final pct = (progress * 100).toInt();

                              return Row(
                                children: [
                                  // Кольцевой индикатор с иконкой документа в центре
                                  SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: isDeterminate
                                              ? progress.clamp(0.0, 1.0)
                                              : null,
                                          strokeWidth: 3,
                                          backgroundColor: theme
                                              .colorScheme.outlineVariant
                                              .withValues(alpha: 0.3),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            theme.colorScheme.primary,
                                          ),
                                        ),
                                        Icon(
                                          Icons.description_outlined,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Название и прогресс
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                active.fileName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isDeterminate ? '$pct%' : '...',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: isDeterminate
                                                ? progress.clamp(0.0, 1.0)
                                                : null,
                                            minHeight: 4,
                                            backgroundColor: theme
                                                .colorScheme.surface
                                                .withValues(alpha: 0.5),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              theme.colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Кнопка развернуть
                                  IconButton(
                                    icon: const Icon(Icons.open_in_full,
                                        size: 16),
                                    tooltip: 'Развернуть',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 28, minHeight: 28),
                                    onPressed: () {
                                      DownloadManager.instance
                                          .expandDownload(context);
                                    },
                                  ),
                                  // Кнопка отмены
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    tooltip: 'Отменить',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 28, minHeight: 28),
                                    onPressed: () {
                                      DownloadManager.instance
                                          .cancelDownload(showToast: true);
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
