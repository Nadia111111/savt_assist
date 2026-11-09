// lib/widgets/cache_clear_dialog.dart
import 'package:flutter/material.dart';
import '../services/cache_service.dart';

/// Диалог/шторка комплексной очистки кэша с возможностью выбора категорий
class CacheClearDialog extends StatefulWidget {
  final AppCacheBreakdown? initialBreakdown;
  final bool isBottomSheet;

  const CacheClearDialog({
    super.key,
    this.initialBreakdown,
    this.isBottomSheet = false,
  });

  /// Статический метод для удобного открытия: на смартфонах — шторка снизу, на десктопе — диалог
  static Future<int?> show(BuildContext context,
      {AppCacheBreakdown? initialBreakdown}) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      return showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CacheClearDialog(
          initialBreakdown: initialBreakdown,
          isBottomSheet: true,
        ),
      );
    }
    return showDialog<int>(
      context: context,
      builder: (_) => CacheClearDialog(
        initialBreakdown: initialBreakdown,
        isBottomSheet: false,
      ),
    );
  }

  @override
  State<CacheClearDialog> createState() => _CacheClearDialogState();
}

class _CacheClearDialogState extends State<CacheClearDialog> {
  AppCacheBreakdown? _breakdown;
  bool _isLoading = true;
  bool _isClearing = false;

  bool _clearImages = true;
  bool _clearDatabase = true;
  bool _clearOfflineData = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialBreakdown != null) {
      _breakdown = widget.initialBreakdown;
      _isLoading = false;
      _initSelections();
    } else {
      _loadBreakdown();
    }
  }

  void _initSelections() {
    // По умолчанию выбираем все непустые категории (или все, если весь кэш 0)
    final b = _breakdown;
    if (b != null && b.totalBytes > 0) {
      _clearImages = b.imageBytes > 0;
      _clearDatabase = b.databaseBytes > 0;
      _clearOfflineData = b.offlineDataBytes > 0;
      if (!_clearImages && !_clearDatabase && !_clearOfflineData) {
        _clearImages = true;
        _clearDatabase = true;
        _clearOfflineData = true;
      }
    } else {
      _clearImages = true;
      _clearDatabase = true;
      _clearOfflineData = true;
    }
  }

  Future<void> _loadBreakdown() async {
    try {
      final data = await AppCacheService.instance.getBreakdown();
      if (mounted) {
        setState(() {
          _breakdown = data;
          _isLoading = false;
          _initSelections();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _breakdown = AppCacheBreakdown.empty;
          _isLoading = false;
          _initSelections();
        });
      }
    }
  }

  int get _selectedBytes {
    if (_breakdown == null) return 0;
    int total = 0;
    if (_clearImages) total += _breakdown!.imageBytes;
    if (_clearDatabase) total += _breakdown!.databaseBytes;
    if (_clearOfflineData) total += _breakdown!.offlineDataBytes;
    return total;
  }

  bool get _hasSelection =>
      _clearImages || _clearDatabase || _clearOfflineData;

  void _toggleAll() {
    final allSelected = _clearImages && _clearDatabase && _clearOfflineData;
    setState(() {
      _clearImages = !allSelected;
      _clearDatabase = !allSelected;
      _clearOfflineData = !allSelected;
    });
  }

  Future<void> _performClear() async {
    if (!_hasSelection || _isClearing) return;
    setState(() => _isClearing = true);

    final clearedBytes = _selectedBytes;
    try {
      await AppCacheService.instance.clearSelected(
        clearImages: _clearImages,
        clearDatabase: _clearDatabase,
        clearOfflineData: _clearOfflineData,
      );

      if (mounted) {
        Navigator.pop(context, clearedBytes);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при очистке кэша: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.isBottomSheet) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(top: 4, bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _buildHeader(theme, isDesktop: false),
                const SizedBox(height: 14),
                if (_isLoading)
                  const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSummaryBanner(theme, isDark, isDesktop: false),
                          _buildCategorySectionHeader(theme, isDesktop: false),
                          _buildGroupedCategories(theme, isDark, isDesktop: false),
                          _buildInfoDisclaimer(theme, isDesktop: false),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildActionButtons(theme, isMobile: true),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Режим диалога (для веба и десктопа) — увеличенный, просторный
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 26, 32, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(theme, isDesktop: true),
                const SizedBox(height: 20),
                if (_isLoading)
                  const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  _buildSummaryBanner(theme, isDark, isDesktop: true),
                  _buildCategorySectionHeader(theme, isDesktop: true),
                  _buildGroupedCategories(theme, isDark, isDesktop: true),
                  _buildInfoDisclaimer(theme, isDesktop: true),
                  const SizedBox(height: 6),
                  _buildActionButtons(theme, isMobile: false),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, {required bool isDesktop}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isDesktop ? 12 : 9),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
          ),
          child: Icon(
            Icons.cleaning_services_rounded,
            color: theme.colorScheme.primary,
            size: isDesktop ? 24 : 20,
          ),
        ),
        SizedBox(width: isDesktop ? 14 : 12),
        Expanded(
          child: Text(
            'Очистка кэша',
            style: TextStyle(
              fontSize: isDesktop ? 21 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, size: isDesktop ? 24 : 22),
          color: theme.colorScheme.onSurfaceVariant,
          splashRadius: isDesktop ? 22 : 20,
          tooltip: 'Закрыть',
        ),
      ],
    );
  }

  Widget _buildSummaryBanner(ThemeData theme, bool isDark,
      {required bool isDesktop}) {
    final totalFormatted =
        AppCacheService.formatBytes(_breakdown?.totalBytes ?? 0);
    final selectedFormatted = AppCacheService.formatBytes(_selectedBytes);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 16,
        vertical: isDesktop ? 16 : 13,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(isDesktop ? 18 : 16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Всего в кэше',
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: isDesktop ? 4 : 3),
                Text(
                  totalFormatted,
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 17,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: isDesktop ? 38 : 32,
            width: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
          SizedBox(width: isDesktop ? 20 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'К удалению',
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: isDesktop ? 4 : 3),
                Text(
                  selectedFormatted,
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 17,
                    fontWeight: FontWeight.bold,
                    color: _selectedBytes > 0
                        ? const Color(0xFFEF4444)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySectionHeader(ThemeData theme,
      {required bool isDesktop}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          4, isDesktop ? 18 : 14, 4, isDesktop ? 10 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Категории',
            style: TextStyle(
              fontSize: isDesktop ? 14.5 : 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TextButton(
            onPressed: _isClearing ? null : _toggleAll,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 10 : 8,
                vertical: isDesktop ? 4 : 2,
              ),
              minimumSize: Size.zero,
            ),
            child: Text(
              (_clearImages && _clearDatabase && _clearOfflineData)
                  ? 'Снять все'
                  : 'Выбрать все',
              style: TextStyle(
                fontSize: isDesktop ? 13 : 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedCategories(ThemeData theme, bool isDark,
      {required bool isDesktop}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(isDesktop ? 18 : 16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          _buildCategoryRow(
            theme: theme,
            title: 'Изображения и медиа',
            subtitle: 'Фото из чатов, обои, рекламации',
            sizeBytes: _breakdown!.imageBytes,
            icon: Icons.image_rounded,
            iconColor: const Color(0xFF3B82F6),
            value: _clearImages,
            onChanged: (val) => setState(() => _clearImages = val ?? false),
            isDesktop: isDesktop,
          ),
          Divider(
            height: 1,
            indent: isDesktop ? 74 : 62,
            color: theme.colorScheme.outline.withValues(alpha: 0.08),
          ),
          _buildCategoryRow(
            theme: theme,
            title: 'База данных чатов',
            subtitle: 'История сообщений (SQLite)',
            sizeBytes: _breakdown!.databaseBytes,
            icon: Icons.chat_bubble_rounded,
            iconColor: const Color(0xFF10B981),
            value: _clearDatabase,
            onChanged: (val) => setState(() => _clearDatabase = val ?? false),
            isDesktop: isDesktop,
          ),
          Divider(
            height: 1,
            indent: isDesktop ? 74 : 62,
            color: theme.colorScheme.outline.withValues(alpha: 0.08),
          ),
          _buildCategoryRow(
            theme: theme,
            title: 'Оффлайн-копии данных',
            subtitle: 'Списки ШУ, проектов, базы знаний',
            sizeBytes: _breakdown!.offlineDataBytes,
            icon: Icons.folder_rounded,
            iconColor: const Color(0xFFF59E0B),
            value: _clearOfflineData,
            onChanged: (val) =>
                setState(() => _clearOfflineData = val ?? false),
            isDesktop: isDesktop,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required int sizeBytes,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required bool isDesktop,
  }) {
    final sizeFormatted = AppCacheService.formatBytes(sizeBytes);

    return InkWell(
      onTap: _isClearing ? null : () => onChanged(!value),
      borderRadius: BorderRadius.circular(isDesktop ? 18 : 16),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 18 : 14,
          vertical: isDesktop ? 15 : 12,
        ),
        child: Row(
          children: [
            Container(
              width: isDesktop ? 44 : 36,
              height: isDesktop ? 44 : 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
              ),
              child: Icon(icon, color: iconColor, size: isDesktop ? 23 : 20),
            ),
            SizedBox(width: isDesktop ? 14 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isDesktop ? 15 : 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 3 : 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isDesktop ? 12.5 : 11.5,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: isDesktop ? 14 : 10),
            Text(
              sizeFormatted,
              style: TextStyle(
                fontSize: isDesktop ? 14 : 13,
                fontWeight: FontWeight.w600,
                color: sizeBytes > 0
                    ? (value
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(width: isDesktop ? 10 : 6),
            Checkbox(
              value: value,
              onChanged: _isClearing ? null : onChanged,
              materialTapTargetSize: isDesktop
                  ? MaterialTapTargetSize.padded
                  : MaterialTapTargetSize.shrinkWrap,
              visualDensity: isDesktop
                  ? VisualDensity.standard
                  : VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoDisclaimer(ThemeData theme, {required bool isDesktop}) {
    return Padding(
      padding: EdgeInsets.only(
        top: isDesktop ? 18 : 14,
        bottom: isDesktop ? 22 : 18,
        left: 4,
        right: 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: isDesktop ? 18 : 16,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
          SizedBox(width: isDesktop ? 10 : 8),
          Expanded(
            child: Text(
              'Данные аккаунта не удалятся. Свежая информация автоматически загрузится с сервера при следующем открытии экранов.',
              style: TextStyle(
                fontSize: isDesktop ? 12.5 : 11.5,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, {required bool isMobile}) {
    final isDesktop = !isMobile;
    final clearButton = SizedBox(
      height: isDesktop ? 52 : 48,
      child: TextButton(
        onPressed: (!_hasSelection || _isClearing) ? null : _performClear,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFEF4444),
          disabledForegroundColor:
              const Color(0xFFEF4444).withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
          ),
        ),
        child: _isClearing
            ? SizedBox(
                width: isDesktop ? 22 : 20,
                height: isDesktop ? 22 : 20,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                ),
              )
            : Text(
                _selectedBytes > 0
                    ? 'Очистить кэш (${AppCacheService.formatBytes(_selectedBytes)})'
                    : 'Очистить кэш',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 15,
                  fontWeight: FontWeight.w600,
                  color: (!_hasSelection || _isClearing)
                      ? const Color(0xFFEF4444).withValues(alpha: 0.35)
                      : const Color(0xFFEF4444),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );

    if (isMobile) {
      return clearButton;
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: TextButton(
              onPressed: _isClearing ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Отмена', style: TextStyle(fontSize: 15)),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(flex: 1, child: clearButton),
      ],
    );
  }
}

