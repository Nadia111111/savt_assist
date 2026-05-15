// lib/screens/profile_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/app_theme.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';
import '../widgets/glow_button.dart';
import '../widgets/responsive_layout.dart';
import 'notification_settings_screen.dart';
import 'favorites_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _currentIndex = 3;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _startDemoNotifications();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _startDemoNotifications() {
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Напоминание: гарантия на ШУ-24М истекает через 10 дней'),
            backgroundColor: const Color(0xFF054582),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'ОК',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBarTitle: 'Профиль',
      enableDesktopCentering: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;
          final horizontalPadding = isDesktop ? 24.0 : 16.0;

          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16,
            ),
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 20),
              _buildSectionTitle('Информация'),
              const SizedBox(height: 12),
              _buildInfoCard(),
              const SizedBox(height: 20),
              _buildSectionTitle('Настройки'),
              const SizedBox(height: 12),
              _buildSettingsCard(),
              const SizedBox(height: 24),
              // Кнопка удаления аккаунта
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: _deleteAccount,
                  icon: const Icon(Icons.delete_forever,
                      size: 16, color: Colors.white),
                  label: const Text('Удалить аккаунт',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF991B1B),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/auth'),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Выйти', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF991B1B),
                    side: const BorderSide(color: Color(0xFF991B1B)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
      bottomNavBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTapped,
      ),
    );
  }

  Widget _buildProfileHeader() {
    final theme = Theme.of(context);
    return AnimatedCard(
      index: 0,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Фролова Надежда',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ООО "Системная автоматизация"',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 12, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text('Подтвержден',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(title,
          style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.5)),
    );
  }

  Widget _buildInfoCard() {
    return AnimatedCard(
      index: 1,
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          _buildInfoTile(Icons.phone_outlined, '+375 (29) 840-46-75'),
          const Divider(height: 1, indent: 56),
          _buildInfoTile(Icons.email_outlined, 'nadezdafrolova@gmail.com'),
          const Divider(height: 1, indent: 56),
          _buildInfoTile(Icons.business_outlined, 'УНП'),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String text) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 20),
      ),
      title: Text(text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _buildSettingsCard() {
    return AnimatedCard(
      index: 2,
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          _buildNavTile(
            Icons.notifications_outlined,
            'Уведомления',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen()),
            ),
          ),
          const Divider(height: 1, indent: 56),
          // Тёмная тема с отображением текущего состояния из AppTheme
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppTheme.themeNotifier,
            builder: (context, themeMode, child) {
              return SwitchListTile(
                secondary: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.dark_mode_outlined,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                title: const Text(
                  'Темная тема',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                value: themeMode == ThemeMode.dark,
                onChanged: (val) {
                  AppTheme.themeNotifier.value =
                      val ? ThemeMode.dark : ThemeMode.light;
                },
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildNavTile(
            Icons.list_alt_outlined,
            'Мои запросы',
            () => Navigator.pushNamed(context, '/my-requests'),
          ),
          const Divider(height: 1, indent: 56),
          _buildNavTile(
            Icons.star_outline,
            'Избранное',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
          const Divider(height: 1, indent: 56),
          _buildNavTile(
            Icons.lock_outline,
            'Смена пароля',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          const Divider(height: 1, indent: 56),
          _buildNavTile(Icons.help_outline, 'Помощь', () => _showHelpDialog()),
          const Divider(height: 1, indent: 56),
          _buildNavTile(
              Icons.info_outline, 'О приложении', () => _showAboutDialog()),
        ],
      ),
    );
  }

  Widget _buildNavTile(IconData icon, String title, VoidCallback onTap) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление аккаунта'),
        content: const Text(
            'Все ваши данные будут безвозвратно удалены. Продолжить?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, '/auth');
            },
            child: Text('Удалить',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  void _onNavTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/shu-list');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/knowledge');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/chats');
        break;
      case 3:
        break;
    }
  }

  void _showHelpDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Помощь'),
        content: const Text(
            'Для получения помощи обратитесь в службу поддержки через чат.\n\n'
            'Телефон: +375 (29) 840-46-75\n'
            'Email: support@savt.by'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Закрыть',
                style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('О приложении'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SAVT Assist v1.0.0'),
            SizedBox(height: 12),
            Text('Приложение для управления ШУ и технической поддержки.'),
            SizedBox(height: 8),
            Text('© 2026 SAVT. Все права защищены.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Закрыть',
                style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }
}
