// lib/widgets/cache_clear_dialog.dart
import 'package:flutter/material.dart';
import '../services/cache_service.dart';

/// Диалог комплексной очистки кэша с возможностью выбора категорий
class CacheClearDialog extends StatefulWidget {
  final AppCacheBreakdown? initialBreakdown;

  const CacheClearDialog({super.key, this.initialBreakdown});

  /// Статический метод для удобного открытия диалога
  static Future<int?> show(BuildContext context, {AppCacheBreakdown? initialBreakdown}) {
    return showDialog<int>(
      context: context,
      builder: (_) => CacheClearDialog(initialBreakdown: initialBreakdown),
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

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.cleaning_services_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Очистка кэша',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 140,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryBanner(theme),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Категории для очистки:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: _isClearing ? null : _toggleAll,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          (_clearImages && _clearDatabase && _clearOfflineData)
                              ? 'Снять все'
                              : 'Выбрать все',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildCategoryTile(
                    theme: theme,
                    title: 'Изображения и медиа',
                    subtitle: 'Фото из чатов, обои, рекламации',
                    sizeBytes: _breakdown!.imageBytes,
                    icon: Icons.image_outlined,
                    iconColor: Colors.blue,
                    value: _clearImages,
                    onChanged: (val) =>
                        setState(() => _clearImages = val ?? false),
                  ),
                  const SizedBox(height: 6),
                  _buildCategoryTile(
                    theme: theme,
                    title: 'База данных чатов',
                    subtitle: 'История сообщений (SQLite)',
                    sizeBytes: _breakdown!.databaseBytes,
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: Colors.green,
                    value: _clearDatabase,
                    onChanged: (val) =>
                        setState(() => _clearDatabase = val ?? false),
                  ),
                  const SizedBox(height: 6),
                  _buildCategoryTile(
                    theme: theme,
                    title: 'Оффлайн-копии данных',
                    subtitle: 'Списки ШУ, проектов, базы знаний',
                    sizeBytes: _breakdown!.offlineDataBytes,
                    icon: Icons.folder_outlined,
                    iconColor: Colors.orange,
                    value: _clearOfflineData,
                    onChanged: (val) =>
                        setState(() => _clearOfflineData = val ?? false),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ваш аккаунт и настройки не удалятся. Свежие данные подгрузятся с сервера при открытии экранов.',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isClearing ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: (!_hasSelection || _isClearing) ? null : _performClear,
          child: _isClearing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                )
              : Text(
                  _selectedBytes > 0
                      ? 'Очистить (${AppCacheService.formatBytes(_selectedBytes)})'
                      : 'Очистить',
                  style: TextStyle(
                    color: (!_hasSelection || _isClearing)
                        ? Colors.grey
                        : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryBanner(ThemeData theme) {
    final totalFormatted =
        AppCacheService.formatBytes(_breakdown?.totalBytes ?? 0);
    final selectedFormatted = AppCacheService.formatBytes(_selectedBytes);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Всего кэша:',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                totalFormatted,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'К удалению:',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                selectedFormatted,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _selectedBytes > 0
                      ? Colors.red
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required int sizeBytes,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    final sizeFormatted = AppCacheService.formatBytes(sizeBytes);

    return InkWell(
      onTap: _isClearing ? null : () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? theme.colorScheme.primary.withValues(alpha: 0.4)
                : theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
          color: value
              ? theme.colorScheme.primary.withValues(alpha: 0.04)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: _isClearing ? null : onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              sizeFormatted,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sizeBytes > 0
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
