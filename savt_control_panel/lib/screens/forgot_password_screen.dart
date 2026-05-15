// lib/screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _smsCodeFocusNode = FocusNode();
  final FocusNode _newPasswordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  String _selectedCountryCode = '+375';
  final List<Map<String, dynamic>> _countries = [
    {'code': '+375', 'name': '🇧🇾 Беларусь', 'flag': '🇧🇾', 'length': 7},
    {'code': '+7', 'name': '🇷🇺 Россия', 'flag': '🇷🇺', 'length': 10},
  ];

  bool _isPasswordVisible = false;
  bool _isCodeSent = false;
  bool _isVerifyingCode = false;
  bool _isResetting = false;
  bool _isLoading = false;

  int _verificationStep = 1; // 1 - ввод телефона, 2 - ввод кода, 3 - новый пароль

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Введите номер телефона';
    final cleanNumber = value.replaceAll(RegExp(r'[^0-9]'), '');
    int requiredLength = 7;
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
    if (value.length < 6) return 'Пароль должен быть не менее 6 символов';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Подтвердите пароль';
    if (value != _newPasswordController.text) return 'Пароли не совпадают';
    return null;
  }

  Future<void> _sendSmsCode() async {
    if (_validatePhone(_phoneController.text) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Сначала введите корректный номер телефона'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isLoading = false;
      _isCodeSent = true;
      _verificationStep = 2;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Код подтверждения отправлен (mock: 1234)'),
          backgroundColor: Colors.green),
    );
  }

  Future<void> _verifySmsCode() async {
    setState(() => _isVerifyingCode = true);
    await Future.delayed(const Duration(seconds: 1));

    // Имитация проверки кода с возможностью ошибки
    final code = _smsCodeController.text;
    bool codeValid = code == '1234';

    setState(() => _isVerifyingCode = false);

    if (!codeValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Неверный SMS-код. Попробуйте снова (код: 1234)'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _verificationStep = 3);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Код подтверждён'),
          backgroundColor: Colors.green),
    );
  }

  Future<void> _resetPassword() async {
    if (_validatePassword(_newPasswordController.text) != null ||
        _validateConfirmPassword(_confirmPasswordController.text) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Проверьте корректность введённых данных'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isResetting = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isResetting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Пароль успешно изменён'),
          backgroundColor: Colors.green),
    );

    // Возврат на страницу входа
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/auth');
    }
  }

  void _backToPhone() {
    setState(() => _verificationStep = 1);
  }

  void _backToCode() {
    setState(() => _verificationStep = 2);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _smsCodeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _phoneFocusNode.dispose();
    _smsCodeFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Восстановление пароля'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF054582), Color(0xFF0a7ac2)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              _getStepTitle(),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getStepSubtitle(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Шаг 1: Ввод телефона
            if (_verificationStep == 1) ...[
              _buildCountryDropdown(),
              const SizedBox(height: 16),
              _buildPhoneField(),
              const SizedBox(height: 24),
              _buildSubmitButton(
                text: 'Отправить код',
                onPressed: _isLoading ? null : _sendSmsCode,
              ),
            ],

            // Шаг 2: Ввод SMS-кода
            if (_verificationStep == 2) ...[
              _buildSmsCodeField(),
              const SizedBox(height: 16),
              Text(
                'Код отправлен на ${_selectedCountryCode} ${_phoneController.text}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isVerifyingCode ? null : _backToPhone,
                      child: const Text('Изменить номер'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSubmitButton(
                      text: 'Подтвердить',
                      onPressed:
                          _isVerifyingCode ? null : _verifySmsCode,
                    ),
                  ),
                ],
              ),
            ],

            // Шаг 3: Новый пароль
            if (_verificationStep == 3) ...[
              _buildPasswordField(
                controller: _newPasswordController,
                focusNode: _newPasswordFocusNode,
                label: 'Новый пароль',
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _confirmPasswordController,
                focusNode: _confirmPasswordFocusNode,
                label: 'Подтвердите пароль',
                isConfirm: true,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isResetting ? null : _backToCode,
                      child: const Text('Назад'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSubmitButton(
                      text: 'Сменить пароль',
                      onPressed: _isResetting ? null : _resetPassword,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_verificationStep) {
      case 1:
        return 'Восстановление пароля';
      case 2:
        return 'Подтверждение номера';
      case 3:
        return 'Смена пароля';
      default:
        return '';
    }
  }

  String _getStepSubtitle() {
    switch (_verificationStep) {
      case 1:
        return 'Введите номер телефона, привязанный к вашему аккаунту';
      case 2:
        return 'Введите код, отправленный в SMS-сообщении';
      case 3:
        return 'Придумайте и подтвердите новый пароль';
      default:
        return '';
    }
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline, width: 1.5),
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surfaceContainerLow),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedCountryCode,
            icon: Icon(Icons.arrow_drop_down,
                color: theme.colorScheme.primary, size: 20),
            isExpanded: true,
            dropdownColor: theme.colorScheme.surfaceContainerHighest,
            style: TextStyle(color: theme.colorScheme.onSurface),
            items: _countries
                .map((country) => DropdownMenuItem(
                      value: country['code'] as String,
                      child: Row(children: [
                        Text(country['flag'] as String),
                        const SizedBox(width: 6),
                        Text(country['code'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14))
                      ]),
                    ))
                .toList(),
            onChanged: (value) =>
                setState(() => _selectedCountryCode = value!),
          ),
        ),
      ),
    ]);
  }

  Widget _buildPhoneField() {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Номер телефона',
          style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      TextFormField(
        controller: _phoneController,
        focusNode: _phoneFocusNode,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          hintText: 'Введите номер телефона',
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
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

  Widget _buildSmsCodeField() {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SMS-код',
          style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      TextFormField(
        controller: _smsCodeController,
        focusNode: _smsCodeFocusNode,
        keyboardType: TextInputType.number,
        maxLength: 4,
        decoration: InputDecoration(
          hintText: 'Введите 4-значный код',
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
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
      if (isConfirm &&
          _confirmPasswordController.text.isNotEmpty &&
          _newPasswordController.text != _confirmPasswordController.text)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              const Icon(Icons.error_outline,
                  size: 14, color: Color(0xFF991B1B)),
              const SizedBox(width: 4),
              Text(
                'Пароли не совпадают',
                style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
              ),
            ],
          ),
        ),
    ]);
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: onPressed == null
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}
