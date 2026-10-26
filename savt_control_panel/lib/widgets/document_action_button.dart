import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Clean, overflow-safe action button for cabinet and project documents.
/// Perfectly matches the SAVT Assist corporate design language:
/// uses theme colors, calm status tints, crisp single-line typography,
/// and eliminates any text overflow issues.
class DocumentActionButton extends StatelessWidget {
  final bool hasAccess;
  final bool isDownloaded;
  final bool isDownloading;
  final bool isQueued;
  final bool accessRequested;
  final double? progress;
  final VoidCallback? onDownload;
  final VoidCallback? onOpen;
  final VoidCallback? onRequestAccess;
  final VoidCallback? onShowQueue;

  const DocumentActionButton({
    super.key,
    required this.hasAccess,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.isQueued = false,
    this.accessRequested = false,
    this.progress,
    this.onDownload,
    this.onOpen,
    this.onRequestAccess,
    this.onShowQueue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final Color bgColor;
    final Color fgColor;
    final Border? border;
    final Widget leadingWidget;
    final String label;
    final VoidCallback? onTap;

    if (hasAccess) {
      if (isDownloaded) {
        // Просмотр (файл уже сохранен локально)
        bgColor = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5);
        fgColor = isDark ? const Color(0xFF34D399) : AppColors.success;
        border = Border.all(color: fgColor.withValues(alpha: 0.5), width: 1);
        leadingWidget = Icon(Icons.visibility_rounded, size: 15, color: fgColor);
        label = 'Просмотр';
        onTap = onOpen;
      } else if (isDownloading) {
        // В процессе загрузки
        bgColor = primary.withValues(alpha: 0.12);
        fgColor = primary;
        border = Border.all(color: primary.withValues(alpha: 0.4), width: 1);
        final pct = progress != null && progress! > 0 ? (progress! * 100).toInt() : null;
        leadingWidget = SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(fgColor),
          ),
        );
        label = pct != null ? '$pct%' : 'Загрузка...';
        onTap = onShowQueue;
      } else if (isQueued) {
        // В очереди
        bgColor = isDark ? const Color(0xFF78350F).withValues(alpha: 0.25) : const Color(0xFFFFFBEB);
        fgColor = const Color(0xFFD97706);
        border = Border.all(color: fgColor.withValues(alpha: 0.5), width: 1);
        leadingWidget = Icon(Icons.hourglass_top_rounded, size: 14, color: fgColor);
        label = 'В очереди';
        onTap = onShowQueue;
      } else {
        // Доступен для скачивания (основная кнопка)
        bgColor = primary;
        fgColor = Colors.white;
        border = null;
        leadingWidget = const Icon(Icons.file_download_outlined, size: 16, color: Colors.white);
        label = 'Скачать';
        onTap = onDownload;
      }
    } else {
      if (accessRequested) {
        // Запрос на доступ уже отправлен
        bgColor = theme.colorScheme.surfaceContainerHighest;
        fgColor = theme.colorScheme.onSurfaceVariant;
        border = Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2), width: 1);
        leadingWidget = Icon(Icons.done_all_rounded, size: 14, color: fgColor);
        label = 'Запрошено';
        onTap = null;
      } else {
        // Требуется запросить доступ
        bgColor = Colors.transparent;
        fgColor = primary;
        border = Border.all(color: primary, width: 1.2);
        leadingWidget = Icon(Icons.lock_outline_rounded, size: 14, color: fgColor);
        label = 'Доступ';
        onTap = onRequestAccess;
      }
    }

    return Container(
      height: 34,
      constraints: const BoxConstraints(minWidth: 84, maxWidth: 124),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: border,
        boxShadow: hasAccess && !isDownloaded && !isDownloading && !isQueued
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                leadingWidget,
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
