import 'package:flutter/material.dart';

/// A colorful, modern, overflow-safe action button for cabinet documents.
/// Features vibrant gradients, glow shadows, clear icons, and strict single-line text constraints.
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
    final List<Color> gradientColors;
    final Color glowColor;
    final Widget leadingWidget;
    final String label;
    final VoidCallback? onTap;

    if (hasAccess) {
      if (isDownloaded) {
        // Просмотр (уже скачан)
        gradientColors = const [Color(0xFF10B981), Color(0xFF059669)];
        glowColor = const Color(0xFF10B981);
        leadingWidget = const Icon(Icons.visibility_rounded, size: 14, color: Colors.white);
        label = 'Просмотр';
        onTap = onOpen;
      } else if (isDownloading) {
        // В процессе загрузки
        gradientColors = const [Color(0xFF0284C7), Color(0xFF0369A1)];
        glowColor = const Color(0xFF0284C7);
        final pct = progress != null && progress! > 0 ? (progress! * 100).toInt() : null;
        leadingWidget = const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
        label = pct != null ? '$pct%' : 'Загрузка';
        onTap = onShowQueue;
      } else if (isQueued) {
        // В очереди
        gradientColors = const [Color(0xFFF59E0B), Color(0xFFD97706)];
        glowColor = const Color(0xFFF59E0B);
        leadingWidget = const Icon(Icons.hourglass_top_rounded, size: 13, color: Colors.white);
        label = 'В очереди';
        onTap = onShowQueue;
      } else {
        // Доступен для скачивания
        gradientColors = const [Color(0xFF2563EB), Color(0xFF1D4ED8)];
        glowColor = const Color(0xFF2563EB);
        leadingWidget = const Icon(Icons.file_download_outlined, size: 15, color: Colors.white);
        label = 'Скачать';
        onTap = onDownload;
      }
    } else {
      if (accessRequested) {
        // Запрос на доступ отправлен
        gradientColors = const [Color(0xFF64748B), Color(0xFF475569)];
        glowColor = const Color(0xFF64748B);
        leadingWidget = const Icon(Icons.done_all_rounded, size: 14, color: Colors.white);
        label = 'Запрошено';
        onTap = null;
      } else {
        // Требуется запросить доступ
        gradientColors = const [Color(0xFF8B5CF6), Color(0xFF6D28D9)];
        glowColor = const Color(0xFF8B5CF6);
        leadingWidget = const Icon(Icons.lock_open_rounded, size: 14, color: Colors.white);
        label = 'Доступ';
        onTap = onRequestAccess;
      }
    }

    return Container(
      height: 34,
      constraints: const BoxConstraints(minWidth: 84, maxWidth: 125),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
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
