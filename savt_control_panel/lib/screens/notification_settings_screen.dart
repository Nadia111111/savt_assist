// lib/screens/notification_settings_screen.dart
import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _newMessages = true;
  bool _warranty30 = true;
  bool _warranty10 = true;
  bool _warranty1 = true;
  bool _promo = false;
  bool _requestStatus = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки уведомлений'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Сообщения'),
          _buildSwitch('Новые сообщения в чатах', _newMessages,
              (val) => setState(() => _newMessages = val)),
          const Divider(),
          _buildSection('Гарантия'),
          _buildSwitch('За 30 дней до окончания', _warranty30,
              (val) => setState(() => _warranty30 = val)),
          _buildSwitch('За 10 дней до окончания', _warranty10,
              (val) => setState(() => _warranty10 = val)),
          _buildSwitch('За 1 день до окончания', _warranty1,
              (val) => setState(() => _warranty1 = val)),
          const Divider(),
          _buildSection('Другое'),
          _buildSwitch('Рекламные уведомления', _promo,
              (val) => setState(() => _promo = val)),
          _buildSwitch('Изменение статуса запросов', _requestStatus,
              (val) => setState(() => _requestStatus = val)),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
      child: Text(title,
          style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.5)),
    );
  }

  Widget _buildSwitch(String title, bool value, Function(bool) onChanged) {
    final theme = Theme.of(context);
    return SwitchListTile(
      title: Text(title,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      value: value,
      onChanged: onChanged,
    );
  }
}
