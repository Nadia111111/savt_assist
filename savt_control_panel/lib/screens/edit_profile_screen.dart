import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../theme/app_spacing.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/offline_aware_button.dart';
import '../widgets/skeletons.dart';
import '../main.dart'; // apiClient, authService
import 'change_password_screen.dart';
import 'change_phone_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _organizationController;
  late TextEditingController _contactPhoneController;

  String? _originalFullName;
  String? _originalEmail;
  String? _originalOrganization;
  String? _originalContactPhone;

  bool _isLoading = true;
  bool _isSaving = false;
  String _userType = 'individual';
  String _phoneNumber = '';

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _organizationController = TextEditingController();
    _contactPhoneController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _organizationController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final data = await authService.getMe();

      setState(() {
        _originalFullName = data['full_name'];
        _originalEmail = data['email'];
        _originalOrganization = data['organization_name'];
        _originalContactPhone = data['contact_phone'];

        _fullNameController.text = _originalFullName ?? '';
        _emailController.text = _originalEmail ?? '';
        _organizationController.text = _originalOrganization ?? '';
        _contactPhoneController.text = _originalContactPhone ?? '';
        _userType = data['user_type'] ?? 'individual';
        _phoneNumber = data['phone'] ?? '';
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      _showError(_getErrorDetail(e));
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Ошибка загрузки: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final Map<String, dynamic> changedFields = {};
    final newFullName = _fullNameController.text.trim();
    final newEmail = _emailController.text.trim();
    final newOrg = _organizationController.text.trim();
    final newContactPhone = _contactPhoneController.text.trim();

    final bool shouldDeleteEmail = newEmail.isEmpty && (_originalEmail != null && _originalEmail!.trim().isNotEmpty);
    final bool shouldUpdateEmail = newEmail.isNotEmpty && newEmail != (_originalEmail ?? '');

    if (newFullName != (_originalFullName ?? '')) {
      changedFields['full_name'] = newFullName;
    }
    if (shouldUpdateEmail) {
      changedFields['email'] = newEmail;
    }
    if (_userType == 'organization' && newOrg != (_originalOrganization ?? '')) {
      changedFields['organization_name'] = newOrg;
    }
    if (newContactPhone != (_originalContactPhone ?? '')) {
      changedFields['contact_phone'] = newContactPhone;
    }

    if (changedFields.isEmpty && !shouldDeleteEmail) {
      if (mounted) Navigator.pop(context, true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      Map<String, dynamic>? updatedData;
      if (shouldDeleteEmail) {
        updatedData = await authService.deleteEmail();
      }
      if (changedFields.isNotEmpty) {
        updatedData = await authService.updateProfile(changedFields);
      }
      authService.clearMeCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Профиль обновлен'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, updatedData);
      }
    } on DioException catch (e) {
      setState(() => _isSaving = false);
      _showError(_getErrorDetail(e));
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Ошибка сохранения: $e');
    }
  }

  Future<void> _changePhoneNumber() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePhoneScreen()),
    );
    if (mounted) {
      _loadProfile();
    }
  }

  String _getErrorDetail(DioException e) {
    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      return e.response!.data['detail'];
    }
    return 'Произошла ошибка';
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



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const GradientScaffold(
        appBarTitle: 'Редактировать профиль',
        body: SkeletonDetail(),
      );
    }

    return GradientScaffold(
      appBarTitle: 'Редактировать профиль',
      appBarAction: OfflineAwareButton(
        onPressed: _saveProfile,
        text: 'Сохранить',
        isLoading: _isSaving,
        isTextButton: true,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
        ),
      ),
      body: ResponsiveContainer(
        maxWidth: 600,
        child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.base),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, size: 50, color: Colors.grey),
              ),
              const SizedBox(height: AppSpacing.xl),
               TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'ФИО',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите ФИО';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.base),
               TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'example@domain.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return null;
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(trimmed)) {
                    return 'Введите корректный Email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.base),
               TextFormField(
                controller: _contactPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Рабочий телефон',
                  hintText: 'Введите номер для связи',
                  prefixIcon: Icon(Icons.contact_phone_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
               TextFormField(
                key: ValueKey(_phoneNumber),
                initialValue: _phoneNumber,
                decoration: const InputDecoration(
                  labelText: 'Телефон',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                readOnly: true,
                enabled: false,
              ),
              if (_userType == 'organization') ...[
                const SizedBox(height: AppSpacing.base),
                TextFormField(
                  controller: _organizationController,
                  decoration: const InputDecoration(
                    labelText: 'Название организации',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _buildActionTile(
                context: context,
                icon: Icons.phone_android_outlined,
                title: 'Сменить номер',
                onTap: _changePhoneNumber,
              ),
              const SizedBox(height: 12),
              _buildActionTile(
                context: context,
                icon: Icons.lock_outline,
                title: 'Сменить пароль',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

