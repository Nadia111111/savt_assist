// lib/screens/register_request_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_spacing.dart';
import '../widgets/animated_background.dart';
import '../main.dart';

class RegisterRequestScreen extends StatefulWidget {
  const RegisterRequestScreen({super.key});

  @override
  State<RegisterRequestScreen> createState() => _RegisterRequestScreenState();
}

class _RegisterRequestScreenState extends State<RegisterRequestScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _userCommentController = TextEditingController();

  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  final FocusNode _fullNameFocusNode = FocusNode();
  final FocusNode _orgNameFocusNode = FocusNode();
  final FocusNode _contactPhoneFocusNode = FocusNode();
  final FocusNode _userCommentFocusNode = FocusNode();

  String _selectedCountryCode = '+375';
  final List<Map<String, dynamic>> _countries = [
    {'code': '+375', 'name': '🇧🇾 Беларусь', 'flag': '🇧🇾', 'length': 9},
    {'code': '+7', 'name': '🇷🇺 Россия', 'flag': '🇷🇺', 'length': 10},
  ];

  String _userType = 'individual';
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isSubmitted = false;

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Введите номер телефона';
    final cleanNumber = value.replaceAll(RegExp(r'[^0-9]'), '');
    int requiredLength = 9;
    for (var country in _countries) {
      if (country['code'] == _selectedCountryCode) {
        requiredLength = country['length'];
        break;
      }
    }
    if (cleanNumber.length != requiredLength) {
      return 'Введите $requiredLength цифр';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Введите пароль';
    if (value.length < 8) return 'Пароль должен быть не менее 8 символов';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Подтвердите пароль';
    if (value != _passwordController.text) return 'Пароли не совпадают';
    return null;
  }

  Future<void> _submitRequest() async {
    final phoneError = _validatePhone(_phoneController.text);
    if (phoneError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(phoneError), backgroundColor: Colors.red),
      );
      return;
    }

    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите ФИО'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_userType == 'organization' && _orgNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название организации'), backgroundColor: Colors.red),
      );
      return;
    }

    final passwordError = _validatePassword(_passwordController.text);
    if (passwordError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(passwordError), backgroundColor: Colors.red),
      );
      return;
    }

    final confirmError = _validateConfirmPassword(_confirmPasswordController.text);
    if (confirmError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(confirmError), backgroundColor: Colors.red),
      );
      return;
    }

    String? contactPhone;
    if (_contactPhoneController.text.trim().isNotEmpty) {
      final contactError = _validatePhone(_contactPhoneController.text);
      if (contactError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(contactError), backgroundColor: Colors.red),
        );
        return;
      }
      final cleanDigits = _contactPhoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
      contactPhone = _selectedCountryCode + cleanDigits;
    }

    setState(() => _isLoading = true);

    final fullPhone = _selectedCountryCode + _phoneController.text.trim();

    try {
      await authService.registerRequest(
        phone: fullPhone,
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        userType: _userType,
        organizationName: _userType == 'organization' ? _orgNameController.text.trim() : null,
        contactPhone: contactPhone,
        userComment: _userCommentController.text.trim().isEmpty ? null : _userCommentController.text.trim(),
      );

      setState(() => _isSubmitted = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заявка отправлена, ожидайте'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _orgNameController.dispose();
    _contactPhoneController.dispose();
    _userCommentController.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _fullNameFocusNode.dispose();
    _orgNameFocusNode.dispose();
    _contactPhoneFocusNode.dispose();
    _userCommentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: AnimatedBackground(
              gradientColors: [
                Color(0xFF054582),
                Color(0xFF0a7ac2),
                Color(0xFF0d3a5c)
              ],
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildHeader(theme),
                  const SizedBox(height: 32),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                            spreadRadius: -5),
                        BoxShadow(
                            color: const Color(0xFF054582).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      children: [
                         Padding(
                           padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                           child: Column(
                             children: [
                               Row(
                                 children: [
                                   IconButton(
                                     onPressed: () => Navigator.pop(context),
                                     icon: Icon(Icons.arrow_back,
                                         color: theme.colorScheme.primary),
                                   ),
                                   Expanded(
                                     child: Text(
                                       _isSubmitted ? 'Заявка отправлена' : 'Заявка на регистрацию',
                                       style: theme.textTheme.headlineSmall?.copyWith(
                                           fontWeight: FontWeight.bold,
                                           color: theme.colorScheme.onSurface),
                                     ).animate().fadeIn().slideY(begin: 0.2),
                                   ),
                                 ],
                               ),
                               const SizedBox(height: 8),
                              Text(
                                _isSubmitted
                                    ? 'Ваша заявка находится на рассмотрении. После одобрения вы получите push-уведомление.'
                                    : 'Для пользователей без Telegram',
                                textAlign: TextAlign.start,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ).animate().fadeIn(delay: const Duration(milliseconds: 100)),
                              const SizedBox(height: 24),
                              if (!_isSubmitted) ...[
                                _buildCountryDropdown(),
                                const SizedBox(height: 16),
                                _buildPhoneField(
                                  controller: _phoneController,
                                  focusNode: _phoneFocusNode,
                                  label: 'Номер телефона',
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _fullNameController,
                                  focusNode: _fullNameFocusNode,
                                  label: 'ФИО *',
                                ),
                                const SizedBox(height: 16),
                                _buildUserTypeSelector(),
                                const SizedBox(height: 16),
                                if (_userType == 'organization') ...[
                                  _buildTextField(
                                    controller: _orgNameController,
                                    focusNode: _orgNameFocusNode,
                                    label: 'Название организации *',
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                Text(
                                  'Рабочий телефон (необязательно)',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _buildPhoneField(
                                  controller: _contactPhoneController,
                                  focusNode: _contactPhoneFocusNode,
                                  label: 'Контактный телефон',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Этот номер будет использоваться для связи.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.start,
                                ),
                                const SizedBox(height: 16),
                                _buildPasswordField(
                                  controller: _passwordController,
                                  focusNode: _passwordFocusNode,
                                  label: 'Пароль',
                                ),
                                const SizedBox(height: 16),
                                _buildPasswordField(
                                  controller: _confirmPasswordController,
                                  focusNode: _confirmPasswordFocusNode,
                                  label: 'Подтвердите пароль',
                                  isConfirm: true,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _userCommentController,
                                  focusNode: _userCommentFocusNode,
                                  label: 'Комментарий (необязательно, до 1000 символов)',
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 24),
                                 _buildSubmitButton(
                                   text: 'Отправить заявку',
                                   onPressed: _isLoading ? null : _submitRequest,
                                 ),
                               ] else ...[
                                const SizedBox(height: 24),
                                _buildSubmitButton(
                                  text: 'На главный экран',
                                  onPressed: () {
                                    Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _continueWithoutAuth,
                    child: Text('Продолжить без входа →',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ).animate().fadeIn(delay: const Duration(milliseconds: 600)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Image.network(
          'https://savt.by/wp-content/uploads/2025/10/logo-small.png',
          width: 200,
          height: 100,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            width: 200,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.white70, Colors.white38]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
                child: Text('SAVT',
                    style: TextStyle(
                        fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white))),
          ),
        )
            .animate()
            .fadeIn(duration: const Duration(milliseconds: 800))
            .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack),
        const SizedBox(height: 16),
        Text('Добро пожаловать в SAVT Assist',
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500))
            .animate()
            .fadeIn(delay: const Duration(milliseconds: 400))
            .slideY(begin: 0.3, end: 0),
      ],
    );
  }

  Widget _buildUserTypeSelector() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Тип пользователя',
            style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: _buildUserTypeButton(
                  title: 'Частное лицо',
                  icon: Icons.person_outline,
                  isActive: _userType == 'individual',
                  onTap: () => setState(() => _userType = 'individual'))),
          const SizedBox(width: 12),
          Expanded(
              child: _buildUserTypeButton(
                  title: 'Организация',
                  icon: Icons.business_outlined,
                  isActive: _userType == 'organization',
                  onTap: () => setState(() => _userType = 'organization'))),
        ]),
      ],
    );
  }

  Widget _buildUserTypeButton({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: 2),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 18,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }

  Widget _buildCountryDropdown() {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Номер телефона',
          style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline, width: 1.5),
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surfaceContainerLow,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedCountryCode,
            icon: Icon(Icons.arrow_drop_down,
                color: theme.colorScheme.primary, size: 20),
            isExpanded: true,
            dropdownColor: theme.colorScheme.surfaceContainerHighest,
            style: TextStyle(color: theme.colorScheme.onSurface),
            items: _countries.map((country) {
              return DropdownMenuItem(
                value: country['code'] as String,
                child: Row(children: [
                  Text(country['flag'] as String),
                  const SizedBox(width: 6),
                  Text(country['code'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ]),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedCountryCode = value!),
          ),
        ),
      ),
    ]);
  }

  Widget _buildPhoneField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
  }) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          hintText: 'Введите номер телефона',
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerLow,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.colorScheme.outline, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
        ),
      ),
    ]);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: 'Введите $label',
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerLow,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.colorScheme.outline, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
        ),
      ),
    ]);
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    bool isConfirm = false,
  }) {
    final theme = Theme.of(context);
    final bool passwordsMismatch = isConfirm &&
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text != _confirmPasswordController.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            hintText: isConfirm ? 'Подтвердите пароль' : 'Введите пароль',
            errorText: passwordsMismatch ? 'Пароли не совпадают' : null,
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.colorScheme.outline, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: onPressed == null
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : Text(text,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
      ),
    );
  }

  Future<void> _continueWithoutAuth() async {
    try {
      await authService.loginAsGuest();
      if (mounted) {
        Navigator.pushNamed(context, '/knowledge');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось войти как гость. Попробуйте позже.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}

