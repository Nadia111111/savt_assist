import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/skeletons.dart';
import '../widgets/animated_card.dart';
import '../main.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService =
      NotificationService(apiClient);

  NotificationSettings? _settings;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final settings = await _notificationService.getSettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки настроек: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSetting(String key, bool value) async {
    final oldSettings = _settings;
    if (oldSettings == null) return;

    setState(() {
      switch (key) {
        case 'chat_messages':
          _settings = oldSettings.copyWith(chatMessages: value);
        case 'promotional':
          _settings = oldSettings.copyWith(promotional: value);
        case 'warranty_expiring':
          _settings = oldSettings.copyWith(warrantyExpiring: value);
        case 'request_status_change':
          _settings = oldSettings.copyWith(requestStatusChange: value);
        case 'cabinet_alarms':
          _settings = oldSettings.copyWith(cabinetAlarms: value);
      }
    });

    try {
      await _notificationService.updateSetting(key, value);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _settings = oldSettings;
      });
      _showError('Ошибка сохранения настройки');
    }
  }

  Future<void> _muteNotifications({int? hours}) async {
    final oldSettings = _settings;
    if (oldSettings == null) return;

    setState(() {
      _settings = oldSettings.copyWith(
        isMuted: true,
        mutedUntil: hours != null
            ? DateTime.now().add(Duration(hours: hours))
            : null,
        mutedIndefinitely: hours == null,
      );
    });

    try {
      await _notificationService.muteNotifications(hours: hours);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _settings = oldSettings;
      });
      _showError('Ошибка включения паузы');
    }
  }

  Future<void> _unmuteNotifications() async {
    final oldSettings = _settings;
    if (oldSettings == null) return;

    setState(() {
      _settings = oldSettings.copyWith(
        isMuted: false,
        mutedUntil: null,
        mutedIndefinitely: false,
      );
    });

    try {
      await _notificationService.unmuteNotifications();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _settings = oldSettings;
      });
      _showError('Ошибка выключения паузы');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBarTitle: 'Настройки уведомлений',
      appBarLeading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      body: ResponsiveContainer(
        maxWidth: 600,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const SkeletonList();
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Ошибка загрузки',
                style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _error,
                textAlign: TextAlign.start,
                style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadSettings,
                icon: const Icon(Icons.refresh),
                label: const Text('Попробовать снова'),
              ),
            ],
          ),
        ),
      );
    }

    if (_settings == null) {
      return const Center(child: Text('Не удалось загрузить настройки'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(theme, 'Типы уведомлений'),
        _buildToggleTile(
          theme,
          'Сообщения в чате',
          'Уведомления о новых сообщениях',
          _settings!.chatMessages,
          (v) => _toggleSetting('chat_messages', v),
        ),
        _buildToggleTile(
          theme,
          'Рекламные уведомления',
          'Уведомления о акциях и новостях',
          _settings!.promotional,
          (v) => _toggleSetting('promotional', v),
        ),
        _buildToggleTile(
          theme,
          'Гарантия',
          'Уведомления об окончании гарантии',
          _settings!.warrantyExpiring,
          (v) => _toggleSetting('warranty_expiring', v),
        ),
        _buildToggleTile(
          theme,
          'Статус заявок',
          'Уведомления об изменении статуса заявок',
          _settings!.requestStatusChange,
          (v) => _toggleSetting('request_status_change', v),
        ),
        _buildToggleTile(
          theme,
          'Аварии ШУ',
          'Уведомления о новых авариях шкафов управления',
          _settings!.cabinetAlarms,
          (v) => _toggleSetting('cabinet_alarms', v),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader(theme, 'Пауза уведомлений'),
        _buildMuteSection(theme),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildToggleTile(
    ThemeData theme,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return AnimatedCard(
      index: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SwitchListTile(
        title: Text(title, style: theme.textTheme.bodyLarge),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ), textAlign: TextAlign.start),
        value: value,
        onChanged: onChanged,
        activeThumbColor: theme.colorScheme.primary,
        secondary: Icon(
          value ? Icons.notifications_active : Icons.notifications_off,
          color: value ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
      ),
    );
  }

  Widget _buildMuteSection(ThemeData theme) {
    final muteStatus = _settings!.getMuteStatusText();
    final isMuted = _settings!.isMuted;

    return AnimatedCard(
      index: 0,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isMuted ? Icons.volume_off : Icons.volume_up,
                color: isMuted ? theme.colorScheme.error : theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMuted ? 'Уведомления на паузе' : 'Уведомления активны',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      muteStatus,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isMuted) ...[
            _buildMuteButton(
              theme,
              'На 1 час',
              Icons.access_time,
              () => _muteNotifications(hours: 1),
            ),
            const SizedBox(height: 8),
            _buildMuteButton(
              theme,
              'На 6 часов',
              Icons.access_time,
              () => _muteNotifications(hours: 6),
            ),
            const SizedBox(height: 8),
            _buildMuteButton(
              theme,
              'На 24 часа',
              Icons.access_time,
              () => _muteNotifications(hours: 24),
            ),
            const SizedBox(height: 8),
            _buildMuteButton(
              theme,
              'Навсегда',
              Icons.block,
              () => _muteNotifications(),
            ),
          ] else ...[
            _buildUnmuteButton(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildMuteButton(
    ThemeData theme,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildUnmuteButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _unmuteNotifications,
        icon: const Icon(Icons.notifications_active, size: 18),
        label: const Text('Включить уведомления'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
