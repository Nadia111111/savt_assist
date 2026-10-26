// lib/services/download_manager.dart
import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../main.dart';
import 'file_save_helper.dart';

/// Статус задачи скачивания
enum DownloadStatus {
  queued,
  downloading,
  completed,
  cancelled,
  failed,
}

/// Задача в очереди скачивания
class DownloadTask {
  final int docId;
  final String fileName;
  final CancelToken cancelToken;
  final Future<List<int>> Function(
    CancelToken cancelToken,
    void Function(int received, int total) onProgress,
  ) downloadAction;
  final Future<void> Function(String savePath)? onCompleted;

  DownloadStatus status;
  double progress = 0.0;
  int receivedBytes = 0;
  int totalBytes = 0;
  String? savePath;
  String? error;

  DownloadTask({
    required this.docId,
    required this.fileName,
    required this.downloadAction,
    this.onCompleted,
    CancelToken? cancelToken,
  })  : cancelToken = cancelToken ?? CancelToken(),
        status = DownloadStatus.queued;
}

/// Сервис управления очередью скачивания файлов (поддержка 10+ файлов, отмена, сворачивание в мини-окошко)
class DownloadManager extends ChangeNotifier {
  static final DownloadManager instance = DownloadManager._();
  DownloadManager._();

  /// Список задач в очереди
  final ValueNotifier<List<DownloadTask>> tasksNotifier =
      ValueNotifier<List<DownloadTask>>([]);

  /// Текущая выполняемая задача
  final ValueNotifier<DownloadTask?> currentTaskNotifier =
      ValueNotifier<DownloadTask?>(null);

  /// Свернуто ли модальное окно в мини-окошко
  final ValueNotifier<bool> isMinimizedNotifier = ValueNotifier<bool>(false);

  bool _isProcessing = false;

  bool get isDownloading => currentTaskNotifier.value != null;

  /// Проверка: скачивается ли конкретный документ прямо сейчас
  bool isDocDownloading(int docId) =>
      currentTaskNotifier.value?.docId == docId;

  /// Проверка: находится ли документ в очереди ожидания
  bool isDocQueued(int docId) => tasksNotifier.value.any(
      (t) => t.docId == docId && t.status == DownloadStatus.queued);

  /// Проверка: документ либо скачивается, либо уже в очереди
  bool isDocActive(int docId) => tasksNotifier.value.any((t) =>
      t.docId == docId &&
      (t.status == DownloadStatus.queued ||
          t.status == DownloadStatus.downloading));

  /// Количество активных задач (скачивающихся + в очереди)
  int get activeCount => tasksNotifier.value
      .where((t) =>
          t.status == DownloadStatus.queued ||
          t.status == DownloadStatus.downloading)
      .length;

  /// Добавление документа в очередь на скачивание (поддерживает 10 и более файлов)
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
    // Если файл уже скачивается или в очереди — уведомляем
    if (isDocActive(docId)) {
      final navContext =
          ControlPanelApp.navigatorKey.currentContext ?? context;
      if (navContext.mounted) {
        ScaffoldMessenger.of(navContext).showSnackBar(
          SnackBar(
            content: Text('Файл "$fileName" уже в очереди скачивания'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final task = DownloadTask(
      docId: docId,
      fileName: fileName,
      downloadAction: downloadAction,
      onCompleted: onCompleted,
    );

    final wasEmpty = tasksNotifier.value.isEmpty;
    tasksNotifier.value = [...tasksNotifier.value, task];
    notifyListeners();

    final navContext =
        ControlPanelApp.navigatorKey.currentContext ?? context;

    if (!wasEmpty) {
      // Уже есть скачивающиеся файлы: показываем информационный тост о добавлении в очередь
      final queuePos = tasksNotifier.value
          .where((t) =>
              t.status == DownloadStatus.queued ||
              t.status == DownloadStatus.downloading)
          .length;
      if (navContext.mounted) {
        ScaffoldMessenger.of(navContext).showSnackBar(
          SnackBar(
            content: Text('Добавлено в очередь ($queuePos): "$fileName"'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Первая загрузка: открываем модальное окно развернутым
      isMinimizedNotifier.value = false;
    }

    // Запускаем обработчик очереди, если он не работает
    _processQueue();
  }

  /// Свернуть модальное окно в маленькое плавающее окошко
  void minimize() {
    isMinimizedNotifier.value = true;
  }

  /// Развернуть обратно в модальное окно
  void expand() {
    isMinimizedNotifier.value = false;
  }

  /// Отменить конкретную задачу
  void cancelTask(DownloadTask task) {
    if (task.status == DownloadStatus.downloading) {
      task.cancelToken.cancel('cancelled_by_user');
      task.status = DownloadStatus.cancelled;
    } else if (task.status == DownloadStatus.queued) {
      task.status = DownloadStatus.cancelled;
      tasksNotifier.value =
          tasksNotifier.value.where((t) => t != task).toList();
    }
    tasksNotifier.value = List.from(tasksNotifier.value);
    notifyListeners();

    final navContext = ControlPanelApp.navigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      ScaffoldMessenger.of(navContext).showSnackBar(
        SnackBar(
          content: Text('Скачивание "${task.fileName}" отменено'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Отменить все активные и ожидающие задачи в очереди
  void cancelAll() {
    for (final task in tasksNotifier.value) {
      if (task.status == DownloadStatus.downloading) {
        task.cancelToken.cancel('cancelled_by_user');
        task.status = DownloadStatus.cancelled;
      } else if (task.status == DownloadStatus.queued) {
        task.status = DownloadStatus.cancelled;
      }
    }

    tasksNotifier.value = [];
    currentTaskNotifier.value = null;
    isMinimizedNotifier.value = false;
    notifyListeners();

    final navContext = ControlPanelApp.navigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      ScaffoldMessenger.of(navContext).showSnackBar(
        const SnackBar(
          content: Text('Все скачивания отменены'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Последовательная обработка очереди
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (true) {
      final list = tasksNotifier.value;
      final queuedIndex =
          list.indexWhere((t) => t.status == DownloadStatus.queued);

      if (queuedIndex == -1) {
        break; // Нет больше файлов в очереди
      }

      final task = list[queuedIndex];
      task.status = DownloadStatus.downloading;
      currentTaskNotifier.value = task;
      tasksNotifier.value = List.from(tasksNotifier.value);
      notifyListeners();

      try {
        final bytes = await task.downloadAction(
          task.cancelToken,
          (received, total) {
            task.receivedBytes = received;
            task.totalBytes = total;
            if (total > 0) {
              task.progress = (received / total).clamp(0.0, 1.0);
            }
            // Обновляем прогресс
            currentTaskNotifier.value = task;
            notifyListeners();
          },
        );

        final rootContext = ControlPanelApp.navigatorKey.currentContext;
        if (rootContext != null && rootContext.mounted) {
          final savePath = await FileSaveHelper.saveFile(
            context: rootContext,
            bytes: bytes,
            fileName: task.fileName,
          );
          task.savePath = savePath;
          task.status = DownloadStatus.completed;
          tasksNotifier.value = List.from(tasksNotifier.value);
          notifyListeners();

          if (task.onCompleted != null) {
            await task.onCompleted!(savePath);
          }

          if (rootContext.mounted && !kIsWeb) {
            ScaffoldMessenger.of(rootContext).showSnackBar(
              SnackBar(
                content: Text('Файл "${task.fileName}" успешно скачан'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 2),
                action: (savePath != 'Галерея')
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
        }
      } catch (e) {
        final wasCancelled = CancelToken.isCancel(e as dynamic) ||
            e.toString().contains('cancelled_by_user') ||
            e.toString().contains('Загрузка отменена');

        if (wasCancelled) {
          task.status = DownloadStatus.cancelled;
        } else {
          task.status = DownloadStatus.failed;
          task.error = e.toString();
          final rootContext = ControlPanelApp.navigatorKey.currentContext;
          if (rootContext != null && rootContext.mounted) {
            ScaffoldMessenger.of(rootContext).showSnackBar(
              SnackBar(
                content: Text('Ошибка скачивания "${task.fileName}": $e'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        tasksNotifier.value = List.from(tasksNotifier.value);
        notifyListeners();
      }

      // Небольшая пауза между скачиваниями
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _isProcessing = false;
    currentTaskNotifier.value = null;

    final activeRemaining = tasksNotifier.value.where((t) =>
        t.status == DownloadStatus.queued ||
        t.status == DownloadStatus.downloading).length;

    if (activeRemaining == 0) {
      final completed = tasksNotifier.value
          .where((t) => t.status == DownloadStatus.completed)
          .length;
      if (completed > 1) {
        final rootContext = ControlPanelApp.navigatorKey.currentContext;
        if (rootContext != null && rootContext.mounted) {
          ScaffoldMessenger.of(rootContext).showSnackBar(
            SnackBar(
              content: Text('Все файлы скачаны (всего $completed)'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      // Очищаем список после завершения всей очереди
      tasksNotifier.value = [];
      isMinimizedNotifier.value = false;
      notifyListeners();
    }
  }
}

/// Обертка MaterialApp для отображения модального окна и мини-окна поверх всех экранов
class DownloadOverlayWrapper extends StatelessWidget {
  final Widget child;
  const DownloadOverlayWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const DownloadOverlayWidget(),
      ],
    );
  }
}

/// Виджет оверлея скачивания: управляет отображением модального окна или свернутого мини-окна
class DownloadOverlayWidget extends StatelessWidget {
  const DownloadOverlayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<DownloadTask>>(
      valueListenable: DownloadManager.instance.tasksNotifier,
      builder: (context, tasks, _) {
        final activeTasks = tasks
            .where((t) =>
                t.status == DownloadStatus.queued ||
                t.status == DownloadStatus.downloading)
            .toList();

        if (activeTasks.isEmpty) {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<bool>(
          valueListenable: DownloadManager.instance.isMinimizedNotifier,
          builder: (context, isMinimized, _) {
            if (isMinimized) {
              return DownloadMiniWindowWidget(tasks: activeTasks);
            } else {
              return DownloadExpandedModalWidget(tasks: activeTasks);
            }
          },
        );
      },
    );
  }
}

/// Развернутое модальное окно скачивания (с поддержкой очереди из 10+ файлов)
class DownloadExpandedModalWidget extends StatelessWidget {
  final List<DownloadTask> tasks;

  const DownloadExpandedModalWidget({super.key, required this.tasks});

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
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    final modalWidth = min(screenSize.width - 32, 440.0);
    final maxHeight = min(screenSize.height * 0.8, 540.0);

    final currentTask = tasks.firstWhere(
      (t) => t.status == DownloadStatus.downloading,
      orElse: () => tasks.first,
    );

    final queuedTasks = tasks.where((t) => t != currentTask).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Нажатие кнопки «Назад» на телефоне сворачивает окно в фон
        DownloadManager.instance.minimize();
      },
      child: Stack(
        children: [
          // Затемненный фон: нажатие на него сворачивает окно в фон
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => DownloadManager.instance.minimize(),
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ),
          // Модальная карточка по центру
          Center(
            child: Material(
              color: Colors.transparent,
              elevation: 16,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: modalWidth,
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Заголовок
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.downloading,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Загрузка файлов',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tasks.length > 1
                                      ? 'Всего в очереди: ${tasks.length}'
                                      : 'Скачивание документа',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Кнопка свернуть в фон
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down, size: 26),
                            tooltip: 'Свернуть в фон',
                            onPressed: () => DownloadManager.instance.minimize(),
                          ),
                          // Кнопка закрыть / отменить
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            tooltip: 'Отменить все',
                            onPressed: () => DownloadManager.instance.cancelAll(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Тело: активное скачивание + очередь
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Карточка текущего скачиваемого файла
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: ValueListenableBuilder<DownloadTask?>(
                                valueListenable: DownloadManager.instance.currentTaskNotifier,
                                builder: (context, activeTask, _) {
                                  final task = activeTask ?? currentTask;
                                  final isDeterminate = task.progress > 0.005 || task.totalBytes > 0;
                                  final receivedStr = _formatBytes(task.receivedBytes);
                                  final totalStr = _formatBytes(task.totalBytes);
                                  final pct = (task.progress * 100).toInt();

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              task.fileName,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close, size: 18),
                                            tooltip: 'Отменить этот файл',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                            onPressed: () => DownloadManager.instance.cancelTask(task),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: isDeterminate ? task.progress.clamp(0.0, 1.0) : null,
                                          minHeight: 8,
                                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            isDeterminate
                                                ? (totalStr.isNotEmpty ? '$receivedStr / $totalStr' : 'Скачивание...')
                                                : 'Подключение...',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          Text(
                                            isDeterminate ? '$pct%' : '',
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
                              ),
                            ),

                            // Список файлов в очереди
                            if (queuedTasks.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(
                                    Icons.queue,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'В очереди (${queuedTasks.length}):',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: queuedTasks.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final queued = queuedTasks[index];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${index + 2}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                queued.fileName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                'В очереди ожидания',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 16),
                                          tooltip: 'Убрать из очереди',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          onPressed: () => DownloadManager.instance.cancelTask(queued),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const Divider(height: 1),

                    // Кнопки действий
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                              label: const Text(
                                'Отменить все',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.red.withValues(alpha: 0.35)),
                                backgroundColor: Colors.red.withValues(alpha: 0.06),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                              onPressed: () => DownloadManager.instance.cancelAll(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => DownloadManager.instance.minimize(),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.white),
                                        SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Свернуть',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Свернутое плавающее мини-окошко скачивания (перетаскиваемое, не закрывающее экран)
class DownloadMiniWindowWidget extends StatefulWidget {
  final List<DownloadTask> tasks;

  const DownloadMiniWindowWidget({super.key, required this.tasks});

  @override
  State<DownloadMiniWindowWidget> createState() => _DownloadMiniWindowWidgetState();
}

class _DownloadMiniWindowWidgetState extends State<DownloadMiniWindowWidget> {
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    final cardWidth = (screenSize.width - 32).clamp(290.0, 360.0);
    final cardHeight = widget.tasks.length > 1 ? 72.0 : 64.0;

    // По умолчанию размещаем над нижней панелью навигации
    _position ??= Offset(
      (screenSize.width - cardWidth) / 2,
      screenSize.height - bottomPadding - cardHeight - 88,
    );

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
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              // Разворачиваем модальное окно обратно
              DownloadManager.instance.expand();
            },
            child: Container(
              width: cardWidth,
              height: cardHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.45),
                  width: 1.2,
                ),
              ),
              child: ValueListenableBuilder<DownloadTask?>(
                valueListenable: DownloadManager.instance.currentTaskNotifier,
                builder: (context, activeTask, _) {
                  final task = activeTask ?? widget.tasks.first;
                  final isDeterminate = task.progress > 0.005 || task.totalBytes > 0;
                  final pct = (task.progress * 100).toInt();
                  final queueCount = widget.tasks.length;

                  return Row(
                    children: [
                      // Кольцевой индикатор с иконкой
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: isDeterminate ? task.progress.clamp(0.0, 1.0) : null,
                              strokeWidth: 3,
                              backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    task.fileName,
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
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: isDeterminate ? task.progress.clamp(0.0, 1.0) : null,
                                minHeight: 4,
                                backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.5),
                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                              ),
                            ),
                            if (queueCount > 1) ...[
                              const SizedBox(height: 3),
                              Text(
                                '+${queueCount - 1} в очереди',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Кнопка развернуть
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.open_in_full_rounded, size: 15, color: theme.colorScheme.primary),
                          tooltip: 'Развернуть',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => DownloadManager.instance.expand(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Кнопка отмены текущего
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                          tooltip: 'Отменить',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => DownloadManager.instance.cancelTask(task),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
