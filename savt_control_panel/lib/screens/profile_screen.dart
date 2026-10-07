import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_spacing.dart';
import '../theme/app_colors.dart';
import '../services/app_theme.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/skeletons.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';
import '../main.dart';
import 'notification_settings_screen.dart';
import 'favorites_screen.dart';
import 'edit_profile_screen.dart';
import '../widgets/auth_image.dart';
import '../services/preferences_service.dart';
import '../services/offline_service.dart';
import '../auth/auth_page.dart';
import '../widgets/responsive_layout.dart';

class ProfileScreen extends StatefulWidget {
  final bool isTab;
  const ProfileScreen({super.key, this.isTab = false});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final int _currentIndex = 3;
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;
  bool _isLoadingUserData = false;
  double _cacheSizeMB = 0.0;
  final ScrollController _scrollController = ScrollController();

  void resetState() {
    if (mounted && _scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Timer? _verificationPollTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCacheSize();
    _startVerificationPolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _startVerificationPolling() {
    _verificationPollTimer?.cancel();
    _verificationPollTimer =
        Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final data = await authService.getMe();
        if (mounted) {
          setState(() {
            _userData = data;
          });
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _verificationPollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCacheSize() async {
    try {
      final size = await AuthImage.getDiskCacheSizeMB();
      setState(() {
        _cacheSizeMB = size;
      });
    } catch (_) {}
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить кэш?'),
        content: Text(
          'Размер кэша: ${_cacheSizeMB.toStringAsFixed(1)} МБ.\n\n'
          'При следующей загрузке изображения будут скачиваться заново с сервера.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Очистить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AuthImage.clearDiskCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Кэш изображений очищен'),
              backgroundColor: Colors.green),
        );
      }
      _loadCacheSize();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка очистки кэша: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadUserData() async {
    if (_isLoadingUserData) return;
    _isLoadingUserData = true;
    setState(() => _isLoading = true);
    try {
      final data = await authService.getMe().timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw Exception('Таймаут загрузки профиля'),
          );
      if (mounted) {
        setState(() {
          _userData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка загрузки профиля: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      _isLoadingUserData = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBarTitle: 'Профиль',
      showBackButton: false,
      enableDesktopCentering: false,
      body: ResponsiveContainer(
        maxWidth: 600,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            final horizontalPadding = isDesktop ? 24.0 : 16.0;

            if (_isLoading) {
              return const SkeletonDetail();
            }

            final fullName = _userData['full_name'] ?? 'Не указано';
            final organization = _userData['organization_name'];
            final phone = _userData['phone'] ?? '';
            final email = _userData['email'] ?? 'Не указан';
            final verified = _userData['is_phone_verified'] ?? false;
            final userType = _userData['user_type'] ?? 'individual';
            final orgDisplay = organization ??
                (userType == 'organization'
                    ? 'Организация'
                    : 'Физическое лицо');

            return ListView(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: AppSpacing.base),
              children: [
                _buildProfileHeader(fullName, orgDisplay, verified),
                const SizedBox(height: AppSpacing.xl),
                _buildSectionTitle('Информация'),
                const SizedBox(height: AppSpacing.md),
                _buildInfoCard(phone, email, organization),
                const SizedBox(height: AppSpacing.xl),
                _buildSectionTitle('Настройки'),
                const SizedBox(height: AppSpacing.md),
                _buildSettingsCard(),
                const SizedBox(height: AppSpacing.xl),
                _buildSectionTitle('Учетная запись'),
                const SizedBox(height: AppSpacing.md),
                _buildAccountActionsCard(),
                const SizedBox(height: AppSpacing.xxl),
              ],
            );
          },
        ),
      ),
      bottomNavBar: widget.isTab
          ? null
          : BottomNavBar(
              currentIndex: _currentIndex,
              onTap: _onNavTapped,
            ),
    );
  }

  Widget _buildProfileHeader(
      String fullName, String orgDisplay, bool verified) {
    final theme = Theme.of(context);
    return AnimatedCard(
      index: 0,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
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
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 36),
              ),
              gapW16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName,
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    Text(orgDisplay,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.base, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: verified
                            ? const Color(0xFF10B981).withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: verified
                                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                : Colors.orange.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(verified ? Icons.verified : Icons.warning_amber,
                              size: 12,
                              color: verified
                                  ? AppColors.success
                                  : AppColors.warning),
                          const SizedBox(width: AppSpacing.xs),
                          Text(verified ? 'Подтвержден' : 'Не подтвержден',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: verified
                                      ? AppColors.success
                                      : AppColors.warning,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    if (!verified) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _showVerificationDialog,
                        child: Text(
                          'Запросить подтверждение аккаунта',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Text(title,
          style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.5)),
    );
  }

  Widget _buildInfoCard(String phone, String email, String? organization) {
    return AnimatedCard(
      index: 1,
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          _buildInfoTile(
              Icons.phone_outlined, phone.isNotEmpty ? phone : 'Не указан'),
          const Divider(height: 1, indent: 56),
          _buildInfoTile(
              Icons.email_outlined, email.isNotEmpty ? email : 'Не указан'),
          if (organization != null && organization.isNotEmpty) ...[
            const Divider(height: 1, indent: 56),
            _buildInfoTile(Icons.business_outlined, organization),
          ],
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
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: theme.colorScheme.primary, size: 20),
      ),
      title: Text(text,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface)),
    );
  }

  Widget _buildSettingsCard() {
    return AnimatedCard(
      index: 2,
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          _buildNavTile(Icons.person_outline, 'Редактировать профиль',
              () async {
            final result = await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()));
            if (result != null && mounted) {
              if (result is Map<String, dynamic>) {
                setState(() {
                  _userData = Map<String, dynamic>.from(result);
                });
              }
              await _loadUserData();
            }
          }),
          const Divider(height: 1, indent: 56),
          _buildNavTile(
              Icons.settings_outlined,
              'Настройки уведомлений',
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen()))),
          const Divider(height: 1, indent: 56),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppTheme.themeNotifier,
            builder: (context, themeMode, child) {
              return SwitchListTile(
                secondary: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.dark_mode_outlined,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                title: Text('Темная тема',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                value: themeMode == ThemeMode.dark,
                onChanged: (val) {
                  final newMode = val ? ThemeMode.dark : ThemeMode.light;
                  AppTheme.themeNotifier.value = newMode;
                  AppTheme.saveTheme(newMode);
                  PreferencesService.saveThemeChoice(val);
                },
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildNavTile(
              Icons.star_outline,
              'Избранное',
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const FavoritesScreen()))),
          const Divider(height: 1, indent: 56),
          _buildNavTile(Icons.help_outline, 'Помощь', () => _showHelpDialog()),
          const Divider(height: 1, indent: 56),
          _buildNavTile(
              Icons.info_outline, 'О приложении', () => _showAboutDialog()),
          const Divider(height: 1, indent: 56),
          _buildNavTile(
              Icons.cleaning_services,
              'Очистить кэш (${_cacheSizeMB.toStringAsFixed(1)} МБ)',
              _clearCache),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await authService.logout();
      if (mounted) {
        Navigator.pop(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showError('Ошибка выхода: $e');
      }
    }
  }

  void _deleteAccount() {
    final passwordController = TextEditingController();
    bool isPasswordError = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Удаление аккаунта'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Все ваши данные будут безвозвратно удалены: ШУ, чаты, документы, заявки.',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 8),
              const Text(
                'Это действие нельзя отменить.',
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 16),
              const Text('Для удаления аккаунта введите ваш пароль:',
                  textAlign: TextAlign.start),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  errorText: isPasswordError
                      ? 'Введите пароль для подтверждения'
                      : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (val) {
                  if (isPasswordError && val.isNotEmpty) {
                    setDialogState(() {
                      isPasswordError = false;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                final password = passwordController.text.trim();
                if (password.isEmpty) {
                  setDialogState(() {
                    isPasswordError = true;
                  });
                  return;
                }
                Navigator.pop(ctx); // Close confirmation dialog

                // Show loading progress dialog
                showDialog(
                  context: this.context,
                  barrierDismissible: false,
                  builder: (context) => const PopScope(
                    canPop: false,
                    child: AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Удаление аккаунта...'),
                        ],
                      ),
                    ),
                  ),
                );

                try {
                  await authService.deleteAccount();

                  // Clear local cache and offline data
                  await AuthImage.clearDiskCache();
                  await OfflineService().clearCache();

                  if (mounted) {
                    Navigator.pop(this.context); // Close progress dialog
                    Navigator.pushAndRemoveUntil(
                      this.context,
                      MaterialPageRoute(builder: (_) => const AuthPage()),
                      (route) => false,
                    );
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Аккаунт успешно удален'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(this.context); // Close progress dialog
                    _showError('Ошибка удаления аккаунта: $e');
                  }
                }
              },
              child: const Text('Удалить', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountActionsCard() {
    final theme = Theme.of(context);
    return AnimatedCard(
      index: 3,
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          _buildNavTile(
            Icons.logout,
            'Выйти из аккаунта',
            _logout,
            iconColor: Colors.orange.shade800,
            textColor: Colors.orange.shade800,
          ),
          const Divider(height: 1, indent: 56),
          _buildNavTile(
            Icons.delete_forever,
            'Удалить аккаунт',
            _deleteAccount,
            iconColor: theme.colorScheme.error,
            textColor: theme.colorScheme.error,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile(IconData icon, String title, VoidCallback onTap,
      {Color? iconColor, Color? textColor}) {
    final theme = Theme.of(context);
    final iCol = iconColor ?? theme.colorScheme.primary;
    final tCol = textColor ?? theme.colorScheme.onSurface;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: iCol.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iCol, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: tCol)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
                'Для получения помощи обратитесь в службу поддержки через чат.\n\nТелефон: +375 (29) 840-46-75\nEmail: support@savt.by',
                textAlign: TextAlign.start,
              ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Закрыть',
                  style: TextStyle(color: theme.colorScheme.primary)))
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
            Text('Приложение для управления ШУ и технической поддержки.',
                textAlign: TextAlign.start),
            SizedBox(height: 8),
            Text('© 2026 SAVT. Все права защищены.',
                textAlign: TextAlign.start)
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Закрыть',
                  style: TextStyle(color: theme.colorScheme.primary)))
        ],
      ),
    );
  }

  void _showVerificationDialog() {
    final theme = Theme.of(context);
    final commentController = TextEditingController();
    XFile? pickedFile;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Запрос подтверждения',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
const Text(
                'Прикрепите скан паспорта, договора или иного документа, подписывающего личность/организацию:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.start,
              ),
                  const SizedBox(height: 16),
                  if (pickedFile != null) ...[
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                        image: DecorationImage(
                          image: FileImage(File(pickedFile!.path)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon:
                          const Icon(Icons.delete, color: Colors.red, size: 16),
                      label: const Text('Удалить фото',
                          style: TextStyle(color: Colors.red, fontSize: 13)),
                      onPressed: () {
                        setStateDialog(() {
                          pickedFile = null;
                        });
                      },
                    ),
                  ] else
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Выбрать фото/скан'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final file =
                            await picker.pickImage(source: ImageSource.gallery);
                        if (file != null) {
                          setStateDialog(() {
                            pickedFile = file;
                          });
                        }
                      },
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Комментарий (необязательно)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (isSubmitting) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: (pickedFile == null || isSubmitting)
                    ? null
                    : () async {
                        setStateDialog(() {
                          isSubmitting = true;
                        });
                        try {
                          final photoUrl = await uploadService
                              .uploadAttachment(pickedFile!.path);
                          await authService.requestVerification(
                              photoUrl, commentController.text.trim());

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Запрос на верификацию успешно отправлен!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setStateDialog(() {
                              isSubmitting = false;
                            });
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Ошибка: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: const Text('Отправить'),
              ),
            ],
          );
        },
      ),
    );
  }
}

