import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/animated_background.dart';
import '../screens/shu_list_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/knowledge_screen.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _loginPhoneController = TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();

  final FocusNode _fullNameFocusNode = FocusNode();
  final FocusNode _orgNameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  final FocusNode _loginPhoneFocusNode = FocusNode();
  final FocusNode _loginPasswordFocusNode = FocusNode();

  bool _isLoginMode = true;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String _userType = 'private';
  bool _rememberMe = false;
  bool _agreeToPolicy = false;

  String _selectedCountryCode = '+375';
  final List<Map<String, dynamic>> _countries = [
    {'code': '+375', 'name': '🇧🇾 Беларусь', 'flag': '🇧🇾', 'length': 7},
    {'code': '+7', 'name': '🇷🇺 Россия', 'flag': '🇷🇺', 'length': 10},
  ];

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
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Код подтверждения отправлен (mock: 1234)'),
          backgroundColor: Colors.green),
    );
  }

  Future<void> _handleRegister() async {
    // Валидация всех полей формы
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Введите ФИО'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_userType == 'organization' && _orgNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Введите название организации'),
            backgroundColor: Colors.red),
      );
      return;
    }

    if (_validatePhone(_phoneController.text) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Введите корректный номер телефона'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Валидация совпадения паролей
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Пароли не совпадают'), backgroundColor: Colors.red),
      );
      return;
    }

    // Проверка длины пароля
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Пароль должен быть не менее 6 символов'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Проверка согласия с политикой
    if (!_agreeToPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Необходимо согласие с политикой обработки данных'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Отправляем SMS-код и показываем диалог подтверждения
    await _sendSmsCode();
    await _showCodeVerificationDialog();
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const ShuListScreen(),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  Future<void> _showCodeVerificationDialog() async {
    final codeController = TextEditingController();
    final theme = Theme.of(context);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.sms, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Подтверждение номера'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Введите код из SMS, отправленный на ваш номер телефона.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '••••',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLow,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Отмена',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code == '1234') {
                // Верный код – выполняем регистрацию
                Navigator.pop(context);
                await _performRegistration();
              } else {
                // Неверный код – показываем ошибку
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Неверный код. Попробуйте снова (код: 1234)',
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
                codeController.clear();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
  }

  Future<void> _performRegistration() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);
    _showSuccessSnackBar('Регистрация успешна! Ваш аккаунт на модерации');
    setState(() => _isLoginMode = true);
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _continueWithoutAuth() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const KnowledgeScreen()),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _orgNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    _fullNameFocusNode.dispose();
    _orgNameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _loginPhoneFocusNode.dispose();
    _loginPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isDesktop = screenWidth >= 900;

          return Stack(
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
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 24 : 20,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            Image.network(
                              'https://savt.by/wp-content/uploads/2025/10/logo-small.png',
                              width: 200,
                              height: 100,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                width: 200,
                                height: 100,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: [Colors.white70, Colors.white38]),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                    child: Text('SAVT',
                                        style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white))),
                              ),
                            )
                                .animate()
                                .fadeIn(
                                    duration: const Duration(milliseconds: 800))
                                .scale(
                                    begin: const Offset(0.8, 0.8),
                                    end: const Offset(1, 1),
                                    duration: const Duration(milliseconds: 800),
                                    curve: Curves.easeOutBack),
                            const SizedBox(height: 16),
                            Text('Добро пожаловать в SAVT Assist',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white.withOpacity(0.8),
                                        fontWeight: FontWeight.w500))
                                .animate()
                                .fadeIn(
                                    delay: const Duration(milliseconds: 400))
                                .slideY(begin: 0.3, end: 0),
                            const SizedBox(height: 32),
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                      spreadRadius: -5),
                                  BoxShadow(
                                      color: const Color(0xFF054582)
                                          .withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8)),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerLow,
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Row(
                                        children: [
                                          Expanded(
                                              child: _buildModeButton(
                                                  'Вход', true)),
                                          Expanded(
                                              child: _buildModeButton(
                                                  'Регистрация', false)),
                                        ],
                                      ),
                                    )
                                        .animate()
                                        .fadeIn(
                                            delay: const Duration(
                                                milliseconds: 200))
                                        .slideX(begin: -0.2, end: 0),
                                  ),
                                  AnimatedCrossFade(
                                    duration: const Duration(milliseconds: 300),
                                    crossFadeState: _isLoginMode
                                        ? CrossFadeState.showFirst
                                        : CrossFadeState.showSecond,
                                    firstChild: _buildLoginForm(),
                                    secondChild: _buildRegisterForm(),
                                  ),
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(
                                    delay: const Duration(milliseconds: 300),
                                    duration: const Duration(milliseconds: 600))
                                .slideY(begin: 0.3, end: 0),
                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: _continueWithoutAuth,
                              child: Text('Продолжить без входа →',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                            ).animate().fadeIn(
                                delay: const Duration(milliseconds: 600)),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModeButton(String text, bool isLogin) {
    final theme = Theme.of(context);
    final isSelected = _isLoginMode == isLogin;
    return GestureDetector(
      onTap: () => setState(() => _isLoginMode = isLogin),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          Text('Вход в аккаунт',
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface))
              .animate()
              .fadeIn()
              .slideY(begin: 0.2),
          const SizedBox(height: 8),
          Text('Введите номер телефона и пароль',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
              .animate()
              .fadeIn(delay: const Duration(milliseconds: 100)),
          const SizedBox(height: 24),
          _buildPhoneRow(
              controller: _loginPhoneController,
              focusNode: _loginPhoneFocusNode),
          const SizedBox(height: 16),
          _buildPasswordField(
              controller: _loginPasswordController,
              focusNode: _loginPasswordFocusNode),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen()),
                    ),
                child: Text('Забыли пароль?',
                    style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500))),
          ),
          const SizedBox(height: 16),
          _buildSubmitButton(text: 'Войти', onPressed: _handleLogin),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          Text('Создать аккаунт',
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface))
              .animate()
              .fadeIn()
              .slideY(begin: 0.2),
          const SizedBox(height: 8),
          Text('Заполните форму для регистрации',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
              .animate()
              .fadeIn(delay: const Duration(milliseconds: 100)),
          const SizedBox(height: 24),
          _buildTextField(
              controller: _fullNameController,
              focusNode: _fullNameFocusNode,
              label: 'ФИО',
              isRequired: true),
          const SizedBox(height: 16),
          _buildUserTypeSelector(),
          const SizedBox(height: 16),
          if (_userType == 'organization') ...[
            _buildTextField(
                controller: _orgNameController,
                focusNode: _orgNameFocusNode,
                label: 'Название организации',
                isRequired: true),
            const SizedBox(height: 16),
          ],
          _buildPhoneRow(
              controller: _phoneController, focusNode: _phoneFocusNode),
          const SizedBox(height: 16),
          _buildPasswordField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              isRegister: true),
          const SizedBox(height: 16),
          _buildPasswordField(
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocusNode,
              isRegister: true,
              isConfirm: true),
          const SizedBox(height: 20),
          _buildCheckbox(
              value: _rememberMe,
              onChanged: (val) => setState(() => _rememberMe = val ?? false),
              title: 'Запомнить меня'),
          const SizedBox(height: 12),
          _buildCheckbox(
              value: _agreeToPolicy,
              onChanged: (val) => setState(() => _agreeToPolicy = val ?? false),
              title: 'Я согласен с политикой обработки данных',
              isPolicy: true),
          const SizedBox(height: 20),
          _buildSubmitButton(
              text: 'Зарегистрироваться',
              onPressed: (!_agreeToPolicy || _isLoading)
                  ? null
                  : () async => await _handleRegister()),
        ],
      ),
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
                  isActive: _userType == 'private',
                  onTap: () => setState(() => _userType = 'private'))),
          const SizedBox(width: 12),
          Expanded(
              child: _buildUserTypeButton(
                  title: 'Организация',
                  icon: Icons.business_outlined,
                  isActive: _userType == 'organization',
                  onTap: () => setState(() => _userType = 'organization'))),
        ])
            .animate()
            .fadeIn(delay: const Duration(milliseconds: 200))
            .slideX(begin: 0.2),
      ],
    );
  }

  Widget _buildUserTypeButton(
      {required String title,
      required IconData icon,
      required bool isActive,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withOpacity(0.15)
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

  Widget _buildPhoneRow(
      {required TextEditingController controller,
      required FocusNode focusNode}) {
    return Row(children: [
      _buildCountryDropdown(),
      const SizedBox(width: 12),
      Expanded(
          child:
              _buildPhoneField(controller: controller, focusNode: focusNode)),
    ]);
  }

  Widget _buildCountryDropdown() {
    final theme = Theme.of(context);
    return Container(
      width: 110,
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
          onChanged: (value) => setState(() => _selectedCountryCode = value!),
        ),
      ),
    );
  }

  Widget _buildPhoneField(
      {required TextEditingController controller,
      required FocusNode focusNode}) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        hintText: 'Введите номер',
      ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required FocusNode focusNode,
      required String label,
      bool isRequired = false}) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label,
            style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: focusNode.hasFocus
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant)),
        if (isRequired && controller.text.isEmpty)
          Text(' *',
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
      ]),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: 'Введите $label',
        ),
      ),
    ]);
  }

  Widget _buildPasswordField(
      {required TextEditingController controller,
      required FocusNode focusNode,
      bool isRegister = false,
      bool isConfirm = false}) {
    final theme = Theme.of(context);
    final label = isConfirm ? 'Подтверждение пароля' : 'Пароль';
    final bool passwordsMismatch = isConfirm &&
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text != _confirmPasswordController.text;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label,
            style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant)),
        if (isRegister && !isConfirm && controller.text.isEmpty)
          Text(' *',
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
      ]),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: !_isPasswordVisible,
        decoration: InputDecoration(
          hintText: isConfirm ? 'Подтвердите пароль' : 'Введите пароль',
          errorText: passwordsMismatch ? 'Пароли не совпадают' : null,
          suffixIcon: IconButton(
              icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20),
              onPressed: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible)),
        ),
      ),
    ]);
  }

  Widget _buildCheckbox(
      {required bool value,
      required void Function(bool?) onChanged,
      required String title,
      bool isPolicy = false}) {
    final theme = Theme.of(context);
    return Row(children: [
      SizedBox(
        width: 22,
        height: 22,
        child: Checkbox(
          value: value,
          onChanged: (bool? val) => onChanged(val ?? false),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
          child: Text(title,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: isPolicy ? 12 : 14,
                  color: value
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                  height: 1.3))),
    ]);
  }

  Widget _buildSubmitButton(
      {required String text, required Future<void> Function()? onPressed}) {
    final theme = Theme.of(context);
    return AnimatedScale(
      scale: _isLoading ? 0.97 : 1,
      duration: const Duration(milliseconds: 150),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              shadowColor: theme.colorScheme.primary.withOpacity(0.4)),
          child: _isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: theme.colorScheme.onPrimary))
              : Text(text,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
        ),
      ),
    );
  }
}
