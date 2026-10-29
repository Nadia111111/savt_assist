// lib/auth/auth_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/animated_background.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/password_reset_request_screen.dart';
import '../main.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';

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
  final TextEditingController _contactPhoneController = TextEditingController();

  final FocusNode _fullNameFocusNode = FocusNode();
  final FocusNode _orgNameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  final FocusNode _loginPhoneFocusNode = FocusNode();
  final FocusNode _loginPasswordFocusNode = FocusNode();
  final FocusNode _contactPhoneFocusNode = FocusNode();

  String? _registrationToken;

  bool _isLoginMode = true;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String _userType = 'private';
  bool _rememberMe = true;
  bool _agreeToPolicy = false;
  bool _isAdult = false;

  static const _policySections = [
    {
      'title': '1. Общие положения',
      'content':
          '1.1. ООО «Системная автоматизация» уделяет особое внимание защите персональных данных при их обработке и с уважением относится к соблюдению прав субъектов персональных данных.\n\nПолитика конфиденциальности в отношении обработки персональных данных (далее – Политика) является одной из принимаемых ООО «Системная автоматизация» мер по защите персональных данных, предусмотренных статьей 17 Закона Республики Беларусь от 7 мая 2021 г. № 99-З «О защите персональных данных» (далее – Закон).\n\n1.2. Политика разъясняет субъектам персональных данных, как и для каких целей их персональные данные собираются, используются или иным образом обрабатываются, а также отражает имеющиеся в связи с этим у субъектов персональных данных права и механизм их реализации.\nПолитика не применяется к обработке персональных данных при обработке cookie-файлов на интернет-сайте ООО «Системная автоматизация».\n\n1.3. Почтовый адрес ООО «Системная автоматизация»: 212013, г. Могилев, ш. Гомельское, 53Б; адрес в сети Интернет: https://savt.by; e-mail: savt@savt.by\n\n1.4. В настоящей Политике используются термины и их определения в значении, определенной Законом.\n\n1.5. Настоящая Политика конфиденциальности при использовании мобильного приложения «SAVT AssistApp» распространяется на всю указанную в настоящей Политику информацию, которую ООО «Системная автоматизация» может получить о Вас при использовании Вами мобильного приложения «SAVT AssistApp» (далее – Приложение), а также в силу технологических особенностей использования указанного Приложения и которая может быть соотнесена с данным конкретным Пользователем.',
    },
    {
      'title': '2. Получение и использование информации',
      'content':
          'ООО «Системная автоматизация» имеет право собирать, систематизировать, хранить, изменять, использовать, обезличивать, сопоставлять с данными по Абонентскому номеру следующие категории информации о Пользователях:\n\n1) Абонентский номер, логин и пароль;\n2) Персональные данные, предоставляемые Пользователями Приложения при регистрации (создании учетной записи): Фамилия Имя Отчество, частное или юридическое лицо;\n3) Технические данные (сетевой IP-адрес, HTTP-заголовки, файлы cookie, информация об аппаратном и программном обеспечении, присвоенные учетным записям изображения);\n4) Дата и время осуществления доступа к Приложению;\n5) Информация о геолокации - данные о местоположении оборудования пользователя (координаты);\n6) Иная информация о пользователе Приложения, необходимая для обработки в соответствии с условиями, регулирующими использование Приложения;\n7) Любые действия, совершенные с использованием логина и пароля Пользователя Приложения, считаются осуществленными от имени и с одобрения Пользователя Приложения.\n\nСобираемая информация (в том числе персональные данные) сохраняется в привязке к логину и паролю, которые были указаны Пользователем при регистрации.\n\nВсю полученную информацию ООО «Системная автоматизация» использует с целью сделать Приложение максимально удобным и полезным для Пользователя и обеспечить работоспособность Приложения и оперативное решение проблем.\n\nВ частности, ООО «Системная автоматизация» обрабатывает Персональные данные Пользователей Приложения для следующих целей:\n• для предоставления доступа к учётной записи пользователя Приложения;\n• чтобы лучше понимать, как Вы взаимодействуете с Приложением;\n• чтобы совершенствовать, менять, персонализировать или иным образом улучшать Приложение и другие продукты ООО «Системная автоматизация» в интересах всех пользователей;\n• чтобы предлагать Вам другие продукты и сервисы ООО «Системная автоматизация»;\n• для осуществления связи с пользователем Приложения для направления уведомлений, запросов и информации, относящейся к работе Приложения, выполнения соглашений и обработки запросов и заявок Пользователя приложения;\n• для защиты прав пользователей Приложения и прав ООО «Системная автоматизация»;\n• для обезличивания полученных данных в научных и иных исследовательских целях.\n\nПредоставленная Пользователем информация обрабатывается с использованием средств автоматизации на срок использования Приложения и в течение 5 лет после завершения оказания услуг.',
    },
    {
      'title': '3. Ограничение обработки данных',
      'content':
          '3.1. В силу технологических особенностей использования Приложения для пользования Услугой без принятия Пользователями условий настоящей Политики в целом и без изъятий, в т.ч. в части согласия Пользователя на обработку персональных данных, работа услуги может быть невозможной со стороны ООО «Системная автоматизация».\nСогласие на обработку персональных данных может быть отозвано Вы в любое время путем подачи в ООО «Системная автоматизация» заявления в письменной форме либо иными способами, указанными в Политике обработки персональных данных в ООО «Системная автоматизация».\nВыражая отказ от обработки персональных данных, Пользователь подтверждает и соглашается, что не сможет использовать Приложение частично или полностью.\n\nВ порядке, предусмотренный Политикой обработки персональных данных в ООО «Системная автоматизация»:\nа) Пользователь имеет право на получение информации, касающейся обработки своих персональных данных;\nб) Пользователь имеет право внесения изменений в свои персональные данные в случае, если персональные данные являются неполными, устаревшими или неточными.',
    },
    {
      'title': '4. Защита информации (в том числе персональных данных)',
      'content':
          'ООО «Системная автоматизация» внедрила достаточные правовые, организационные и технические меры по обеспечению защиты персональных данных от несанкционированного или случайного доступа к ним, а также от иных неправомерных действий в отношении персональных данных.\n\nВ большинстве случаев информация (в том числе персональные данные) заявки и рекламации обрабатывают сотрудники ООО «Системная автоматизация» и видят имя, телефон, организацию.\nООО «Системная автоматизация» осуществляет сбор, обработку, предоставление, распространение персональных данных с использованием баз данных, находящихся на территории Республики Беларусь, Российской Федерации.\n\nЗа содействием в реализации прав, связанных с обработкой персональных данных ООО «Системная автоматизация», субъект персональных данных может обратиться к лицу, ответственному за осуществление внутреннего контроля за обработкой персональных данных в ООО «Системная автоматизация», направив сообщение на электронный адрес e-mail: savt@savt.by',
    },
    {
      'title':
          '5. Предоставление персональных данных третьим лицам и использование сторонних сервисов',
      'content':
          'Для обеспечения технической возможности авторизации и отправки уведомлений мы можем передавать ограниченный набор данных сторонним провайдерам:\n\n5.1. Интеграция с облачными сервисами (Yandex Cloud). Для обеспечения работы интеллектуальных функций бота (распознавание речи, анализ изображений и ведение контекстного диалога) наш сервис использует инфраструктуру ООО «Яндекс Облако». В процессе взаимодействия с ботом в Yandex Cloud могут передаваться следующие данные пользователей:\n• Контекст диалога: история последних сообщений в чате — исключительно для поддержания логики и контекста текущего диалога с искусственным интеллектом;\n• Голосовые сообщения: аудиозаписи, отправляемые пользователем в чат, — исключительно для их автоматического преобразования в текст (распознавания речи);\n• Фотоизображения: графические файлы, загружаемые пользователем, — исключительно для генерации их текстового описания или автоматического анализа контента.\nВсе передаваемые данные обрабатываются в зашифрованном виде и используются Yandex Cloud временно, только в момент выполнения соответствующего технического запроса.\n\n5.2. Интеграция с сервисом Telegram FZ-LLC. В частности, при использовании мессенджера Telegram для верификации или информирования, сервису Telegram FZ-LLC (или Telegram Group Inc.) передаются:\n• Идентификатор чата (Telegram Chat ID) — исключительно для распознавания адресата и доставки сообщений;\n• Одноразовые коды подтверждения — для верификации вашего аккаунта или совершения операций.\nДанные передаются в зашифрованном виде и не используются получателем для иных целей.\n\n5.3. Для интеграции с сервисом Google Firebase. Для оперативного информирования пользователей, отправки системных оповещений и сервисных сообщений наш сервис использует платформу Google Firebase Cloud Messaging (FCM). Для обеспечения технической доставки уведомлений на устройства пользователей, сервису Google LLC передаются следующие данные:\n• Токен устройства (FCM Device Token): уникальный технический идентификатор, который автоматически генерируется платформой Firebase для вашего конкретного устройства при установке приложения/активации уведомлений. Он используется исключительно в качестве адреса для доставки пуш-сообщения и не позволяет напрямую идентифицировать вашу личность;\n• Текст и содержимое уведомления (Push Payload): текстовое наполнение сообщения, заголовки, а также связанные с ним технические параметры (например, ссылка для перехода или ID чата), которые отображаются на экране вашего устройства.\nДанные передаются по защищенным каналам связи и обрабатываются Google в соответствии с его политикой конфиденциальности. Вы можете в любой момент отключить получение push-уведомлений в настройках своего устройства или приложения.\n\n5.4. Управление обращениями и клиентский сервис (Битрикс24). Для автоматизации обработки обращений, управления задачами и повышения качества клиентского сервиса мы используем CRM-платформу Битрикс24 (разработчик — ООО «1С-Битрикс»). В зависимости от типа вашего обращения, в систему Битрикс24 передаются и вносятся в карточки задач следующие данные:\n• При оформлении стандартных заявок: имя (или номер телефона) заявителя, а также наименование организации (для корпоративных клиентов) — исключительно с целью идентификации клиента, оперативной связи и выполнения условий заявки;\n• При оформлении рекламаций (претензий и жалоб): имя, номер телефона и адрес электронной почты (e-mail) контактного лица — для проведения детальной проверки по факту жалобы, направления официального ответа и разрешения спорных ситуаций.\nДанные хранятся в изолированном корпоративном контуре нашей компании на серверах Битрикс24 и не передаются третьим лицам.\n\n5.5. Отображение шрифтов и визуальное оформление (Google Fonts). Для обеспечения единообразного и корректного отображения текстовых шрифтов в нашем приложении, при запуске и загрузке страниц код приложения выполняет автоматический запрос к серверам компании Google. В процессе этого взаимодействия:\n• Передаваемые данные: На серверы Google автоматически передается ваш IP-адрес, а также технические данные о вашем браузере (User-Agent) — это технически необходимо для того, чтобы сервер Google определил, куда именно (на какое устройство) передать файлы шрифтов для их отображения.\n• Цель: Загрузка и кэширование необходимых веб-шрифтов на стороне пользователя для корректного визуального отображения интерфейса.\nДанные обрабатываются Google в соответствии с его глобальной политикой конфиденциальности. Наше приложение не сохраняет эти IP-адреса и не использует их для идентификации вашей личности.\n\nООО «Системная автоматизация» предпринимаются все возможные меры для обеспечения безопасности и защиты информации пользователей от несанкционированных попыток доступа, изменения, раскрытия или уничтожения, а также иных видов ненадлежащего использования.\nПользователь должен обеспечивать сохранность и конфиденциальность секретных параметров и другой информации, необходимой для доступа и совершения операций с использованием мобильного приложения, втайне от третьих лиц.\nПользователь обязуется незамедлительно сообщать ООО «Системная автоматизация» о любом случае подозрения несанкционированного использования его учетной записи.\nСоблюдение пользователем рекомендаций ООО «Системная автоматизация» позволит обеспечить максимальную сохранность предоставленной ООО «Системная автоматизация» информации.',
    },
    {
      'title': '6. Конфиденциальность детей',
      'content':
          'Приложение не ориентировано на детей и предназначено для использования лицами, достигшими 16 лет. Мы сознательно не осуществляем сбор и обработку персональных данных несовершеннолетних лиц младше 16 лет без согласия их законных представителей. Если нам станет известно, что мы случайно получили персональные данные лица младше 16 лет без надлежащего согласия, мы предпримем немедленные меры для удаления такой информации. Законные представители могут связаться с нами по адресу e-mail: savt@savt.by для удаления данных ребенка.',
    },
    {
      'title':
          '7. Порядок присоединения к Политике конфиденциальности, ее изменение и расторжение',
      'content':
          'Использование Пользователем Приложения означает согласие с настоящей Политикой и условиями обработки информации (в том числе персональных данных) Пользователя Приложения.\nООО «Системная автоматизация» имеет право вносить изменения в настоящую Политику по своему усмотрению, публикуя новую версию Политики.\nПользователь вправе в любое время отказаться от настоящей Политики при прекращении пользования Приложением.\nВсе вопросы, не отраженные в настоящей Политике конфиденциальности, регулируются законодательством Республики Беларусь.\nЕсли вам нужна дополнительная информация о нашей политике конфиденциальности и ее содержании, пожалуйста, напишите нам по адресу e-mail: savt@savt.by',
    },
  ];

  String _selectedCountryCode = '+375';
  final List<Map<String, dynamic>> _countries = [
    {'code': '+375', 'name': '🇧🇾 Беларусь', 'flag': '🇧🇾', 'length': 9},
    {'code': '+7', 'name': '🇷🇺 Россия', 'flag': '🇷🇺', 'length': 10},
  ];

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

  static const String _kRegDraftKey = 'reg_form_draft';

  @override
  void initState() {
    super.initState();
    _restoreRegistrationDraftIfAny();
    _fullNameController.addListener(_onFormFieldChanged);
    _orgNameController.addListener(_onFormFieldChanged);
    _contactPhoneController.addListener(_onFormFieldChanged);
    _passwordController.addListener(_onFormFieldChanged);
    _confirmPasswordController.addListener(_onFormFieldChanged);
  }

  void _onFormFieldChanged() {
    if (!_isLoginMode) {
      _saveRegistrationDraft(isWaitingCode: false);
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    try {
      return PreferencesService.prefs;
    } catch (_) {
      return await SharedPreferences.getInstance();
    }
  }

  Future<void> _saveRegistrationDraft(
      {bool isWaitingCode = false, Map<String, dynamic>? startResult}) async {
    try {
      final prefs = await _getPrefs();
      final data = <String, dynamic>{
        'full_name': _fullNameController.text,
        'user_type': _userType,
        'org_name': _orgNameController.text,
        'phone': _contactPhoneController.text,
        'country_code': _selectedCountryCode,
        'password': _passwordController.text,
        'confirm_password': _confirmPasswordController.text,
        'registration_token': _registrationToken,
        'is_waiting_code': isWaitingCode,
        if (startResult != null) 'start_result': startResult,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_kRegDraftKey, jsonEncode(data));
    } catch (e) {
      debugPrint('⚠️ Error saving registration draft: $e');
    }
  }

  Future<void> _clearRegistrationDraft({bool keepFields = false}) async {
    try {
      final prefs = await _getPrefs();
      if (keepFields) {
        final data = <String, dynamic>{
          'full_name': _fullNameController.text,
          'user_type': _userType,
          'org_name': _orgNameController.text,
          'phone': _contactPhoneController.text,
          'country_code': _selectedCountryCode,
          'password': _passwordController.text,
          'confirm_password': _confirmPasswordController.text,
          'registration_token': null,
          'is_waiting_code': false,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        await prefs.setString(_kRegDraftKey, jsonEncode(data));
      } else {
        await prefs.remove(_kRegDraftKey);
      }
    } catch (_) {}
  }

  Future<void> _restoreRegistrationDraftIfAny() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_kRegDraftKey);
      if (raw == null || raw.isEmpty) return;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int? ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > 24 * 60 * 60 * 1000) {
        await prefs.remove(_kRegDraftKey);
        return;
      }

      if (!mounted) return;
      final bool hasData = (data['full_name'] != null &&
              (data['full_name'] as String).isNotEmpty) ||
          (data['phone'] != null && (data['phone'] as String).isNotEmpty);

      setState(() {
        if (hasData) {
          _isLoginMode = false;
        }
        if (data['full_name'] != null)
          _fullNameController.text = data['full_name'];
        if (data['user_type'] != null) _userType = data['user_type'];
        if (data['org_name'] != null)
          _orgNameController.text = data['org_name'];
        if (data['phone'] != null) _contactPhoneController.text = data['phone'];
        if (data['country_code'] != null)
          _selectedCountryCode = data['country_code'];
        if (data['password'] != null)
          _passwordController.text = data['password'];
        if (data['confirm_password'] != null)
          _confirmPasswordController.text = data['confirm_password'];
        if (data['registration_token'] != null)
          _registrationToken = data['registration_token'];
      });

      final bool isWaitingCode = data['is_waiting_code'] == true;
      final dynamic startResultRaw = data['start_result'];
      final Map<String, dynamic>? startResult = startResultRaw is Map
          ? Map<String, dynamic>.from(startResultRaw)
          : null;

      if (isWaitingCode && _registrationToken != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final dialogData = startResult ??
              {
                'registration_token': _registrationToken,
                'deep_link': null,
              };
          _showCodeVerificationDialog(dialogData,
              rememberMe: _rememberMe, initialShowCodeInput: true);
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error restoring registration draft: $e');
    }
  }

  Future<void> _handleRegister() async {
    if (_fullNameController.text.trim().isEmpty) {
      _showErrorSnackBar('Введите ФИО');
      return;
    }
    if (_userType == 'organization' && _orgNameController.text.trim().isEmpty) {
      _showErrorSnackBar('Введите название организации');
      return;
    }
    if (_contactPhoneController.text.trim().isEmpty) {
      _showErrorSnackBar('Введите номер телефона');
      return;
    }
    final phoneError = _validatePhone(_contactPhoneController.text);
    if (phoneError != null) {
      _showErrorSnackBar(phoneError);
      return;
    }
    final cleanPhoneDigits =
        _contactPhoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final contactPhone = _selectedCountryCode + cleanPhoneDigits;
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('Пароли не совпадают');
      return;
    }
    final passError = _validatePassword(_passwordController.text);
    if (passError != null) {
      _showErrorSnackBar(passError);
      return;
    }
    if (!_agreeToPolicy) {
      _showErrorSnackBar('Необходимо согласие с политикой конфиденциальности');
      return;
    }
    if (!_isAdult) {
      _showErrorSnackBar(
          'Для регистрации необходимо подтвердить, что вам 16 лет или более');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await authService.registerStart(
        password: _passwordController.text,
        fullName: _fullNameController.text,
        userType: _userType == 'private' ? 'individual' : 'organization',
        organizationName:
            _userType == 'organization' ? _orgNameController.text : null,
        contactPhone: contactPhone,
      );
      _registrationToken = result['registration_token'];
      if (_registrationToken == null) {
        throw Exception('Не удалось получить токен регистрации');
      }
      await _saveRegistrationDraft(isWaitingCode: true, startResult: result);
      final success =
          await _showCodeVerificationDialog(result, rememberMe: _rememberMe);
      if (success) {
        await _clearRegistrationDraft();
        _showSuccessSnackBar('Регистрация успешна!');
        setState(() => _isLoginMode = true);
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showCodeVerificationDialog(Map<String, dynamic> startResult,
      {bool rememberMe = false, bool initialShowCodeInput = false}) async {
    final codeController = TextEditingController();
    final theme = Theme.of(context);
    String? currentDeepLink = startResult['deep_link'];
    bool showCodeInput = initialShowCodeInput || currentDeepLink == null;
    int resendSeconds = startResult['resend_after_seconds'] ?? 60;
    bool canResend = false;
    bool isSubmittingRequest = false;
    Timer? resendTimer;

    Future<void> submitRegisterRequest(
        void Function(void Function()) setStateDialog) async {
      setStateDialog(() => isSubmittingRequest = true);
      try {
        final cleanPhoneDigits =
            _contactPhoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
        final phone = _selectedCountryCode + cleanPhoneDigits;
        await authService.registerRequest(
          phone: phone,
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          userType: _userType == 'private' ? 'individual' : 'organization',
          organizationName: _userType == 'organization'
              ? _orgNameController.text.trim()
              : null,
          contactPhone: phone,
        );
        resendTimer?.cancel();
        await _clearRegistrationDraft();
        if (mounted) {
          Navigator.pop(context, false);
          _showSuccessSnackBar(
              'Заявка на регистрацию отправлена. Ожидайте одобрения администратором.');
          setState(() {
            _isLoginMode = true;
          });
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar(e.toString());
        }
      } finally {
        if (mounted) {
          setStateDialog(() => isSubmittingRequest = false);
        }
      }
    }

    void startTimer(void Function(void Function()) setDialogState) {
      canResend = false;
      resendTimer?.cancel();
      resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setDialogState(() {
          if (resendSeconds > 0) {
            resendSeconds--;
          } else {
            canResend = true;
            timer.cancel();
          }
        });
      });
    }

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setStateDialog) {
                if (!showCodeInput) {
                  return AlertDialog(
                    insetPadding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 24),
                    contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: Row(
                      children: [
                        const Icon(Icons.telegram,
                            color: Color(0xFF229ED9), size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Подключение Telegram',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Пожалуйста, откройте нашего бота в Telegram и обязательно нажмите кнопку «Отправить мой номер» (Share Contact) в чате. Без этого действия код подтверждения не будет создан.',
                          textAlign: TextAlign.start,
                          style: TextStyle(fontSize: 14, height: 1.35),
                        ),
                        const SizedBox(height: 16),
                        if (currentDeepLink != null) ...[
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _saveRegistrationDraft(
                                  isWaitingCode: true,
                                  startResult: startResult);
                              try {
                                final uri = Uri.parse(currentDeepLink!);
                                final launched = await launchUrl(uri,
                                    mode: LaunchMode
                                        .externalNonBrowserApplication);
                                if (!launched) {
                                  await launchUrl(uri,
                                      mode: LaunchMode.externalApplication);
                                }
                              } catch (_) {
                                try {
                                  await launchUrl(Uri.parse(currentDeepLink!),
                                      mode: LaunchMode.externalApplication);
                                } catch (e) {
                                  _showErrorSnackBar(
                                      'Не удалось открыть Telegram: $e');
                                }
                              }
                            },
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('Открыть Telegram-бот'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF229ED9),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        OutlinedButton(
                          onPressed: () {
                            setStateDialog(() {
                              showCodeInput = true;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Ввести код подтверждения',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: isSubmittingRequest
                                ? null
                                : () => submitRegisterRequest(setStateDialog),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: isSubmittingRequest
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Icon(Icons.person_add,
                                    color: theme.colorScheme.primary, size: 16),
                            label: Text(
                              'Нет Telegram? Отправьте заявку на регистрацию',
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          resendTimer?.cancel();
                          await _clearRegistrationDraft(keepFields: true);
                          if (context.mounted) Navigator.pop(context, false);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('Отмена',
                            style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    ],
                  );
                }

                if (resendTimer == null && !canResend) {
                  Future.delayed(Duration.zero, () {
                    startTimer(setStateDialog);
                  });
                }

                return AlertDialog(
                  insetPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  title: const Row(
                    children: [
                      Icon(Icons.telegram, color: Color(0xFF229ED9), size: 28),
                      SizedBox(width: 10),
                      Text('Код подтверждения'),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Введите 6-значный код подтверждения, который прислал бот в Telegram.',
                          style: TextStyle(fontSize: 14),
                          textAlign: TextAlign.start,
                        ),
                        const SizedBox(height: 20),
                        FutureBuilder<ClipboardData?>(
                          future: Clipboard.getData(Clipboard.kTextPlain),
                          builder: (context, snapshot) {
                            final clipText = snapshot.data?.text?.trim() ?? '';
                            if (RegExp(r'^\d{6}$').hasMatch(clipText)) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TextButton.icon(
                                  icon: const Icon(Icons.content_paste),
                                  label: Text('Вставить: $clipText'),
                                  onPressed: () {
                                    setStateDialog(() {
                                      codeController.text = clipText;
                                    });
                                  },
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        TextField(
                          controller: codeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: '••••••',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerLow,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: canResend
                              ? () async {
                                  if (_registrationToken == null) return;
                                  try {
                                    final res =
                                        await authService.resendRegisterCode(
                                            _registrationToken!);
                                    setStateDialog(() {
                                      resendSeconds =
                                          res['resend_after_seconds'] ?? 60;
                                      canResend = false;
                                      currentDeepLink = res['deep_link'];
                                      if (currentDeepLink != null) {
                                        showCodeInput = false;
                                        resendTimer?.cancel();
                                        resendTimer = null;
                                        _showErrorSnackBar(
                                            'Вернитесь в Telegram и подтвердите номер.');
                                      } else {
                                        _showSuccessSnackBar(
                                            'Код отправлен повторно в Telegram.');
                                      }
                                    });
                                    if (currentDeepLink == null) {
                                      startTimer(setStateDialog);
                                    }
                                  } catch (e) {
                                    _showErrorSnackBar(e.toString());
                                  }
                                }
                              : null,
                          child: Text(
                            canResend
                                ? 'Отправить повторно'
                                : 'Повторно через $resendSeconds сек',
                            style: TextStyle(color: theme.colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: isSubmittingRequest
                              ? null
                              : () => submitRegisterRequest(setStateDialog),
                          child: Text(
                            'Нет Telegram? Отправьте заявку на регистрацию',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        resendTimer?.cancel();
                        await _clearRegistrationDraft(keepFields: true);
                        if (context.mounted) Navigator.pop(context, false);
                      },
                      child: Text('Отмена',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (_registrationToken == null) return;
                        final code = codeController.text.trim();
                        if (code.length != 6) {
                          _showErrorSnackBar('Введите 6-значный код');
                          return;
                        }
                        try {
                          await authService.registerComplete(
                              _registrationToken!, code,
                              rememberMe: rememberMe);
                          resendTimer?.cancel();
                          await _clearRegistrationDraft();
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (e) {
                          if (e is AuthException) {
                            if (e.statusCode == 404) {
                              _showErrorSnackBar(
                                  'Регистрация истекла. Начните регистрацию заново.');
                              resendTimer?.cancel();
                              await _clearRegistrationDraft(keepFields: true);
                              if (context.mounted)
                                Navigator.pop(context, false);
                              return;
                            }
                            if (e.statusCode == 400 &&
                                e.message
                                    .contains('Номер ещё не подтверждён')) {
                              setStateDialog(() {
                                showCodeInput = false;
                                currentDeepLink =
                                    startResult['deep_link'] ?? currentDeepLink;
                                resendTimer?.cancel();
                                resendTimer = null;
                              });
                              _showErrorSnackBar(
                                  'Номер еще не подтвержден. Пожалуйста, вернитесь в Telegram и нажмите кнопку "Отправить мой номер".');
                              return;
                            }
                          }
                          _showErrorSnackBar(e.toString());
                          codeController.clear();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Подтвердить'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
  }

  Future<void> _handleLogin() async {
    final cleanLoginDigits =
        _loginPhoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final fullPhone = _selectedCountryCode + cleanLoginDigits;
    if (fullPhone.isEmpty || _loginPasswordController.text.isEmpty) {
      _showErrorSnackBar('Заполните все поля');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await authService.login(fullPhone, _loginPasswordController.text,
          rememberMe: _rememberMe);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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

  Future<void> _showPrivacyPolicyDialog() async {
    final theme = Theme.of(context);
    final expandedStates = List<bool>.filled(_policySections.length, false);
    final isWeb = kIsWeb;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dialog = AlertDialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: isWeb ? 40 : 16,
                vertical: isWeb ? 32 : 24,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Политика конфиденциальности',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: isWeb ? 560 : double.infinity,
                height:
                    MediaQuery.of(context).size.height * (isWeb ? 0.5 : 0.7),
                child: ListView.builder(
                  itemCount: _policySections.length,
                  itemBuilder: (context, index) {
                    final section = _policySections[index];
                    return Theme(
                      data: theme.copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: expandedStates[index],
                        onExpansionChanged: (expanded) {
                          setDialogState(() {
                            expandedStates[index] = expanded;
                          });
                        },
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        title: Text(
                          section['title']!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        children: [
                          SelectableText(
                            section['content']!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: [
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Я согласен(а) с политикой конфиденциальности',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          backgroundColor:
                              theme.colorScheme.surfaceContainerLow,
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Я не согласен(а) с политикой конфиденциальности',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ],
            );

            if (isWeb) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: dialog,
                ),
              );
            }
            return dialog;
          },
        );
      },
    );

    if (result != null) {
      setState(() => _agreeToPolicy = result);
    }
  }

  Future<void> _continueWithoutAuth() async {
    try {
      await authService.loginAsGuest();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/knowledge');
      }
    } catch (e) {
      _showErrorSnackBar('Не удалось войти как гость. Попробуйте позже.');
    }
  }

  @override
  void dispose() {
    _fullNameController.removeListener(_onFormFieldChanged);
    _orgNameController.removeListener(_onFormFieldChanged);
    _contactPhoneController.removeListener(_onFormFieldChanged);
    _passwordController.removeListener(_onFormFieldChanged);
    _confirmPasswordController.removeListener(_onFormFieldChanged);
    _fullNameController.dispose();
    _orgNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    _contactPhoneController.dispose();
    _fullNameFocusNode.dispose();
    _orgNameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _loginPhoneFocusNode.dispose();
    _loginPasswordFocusNode.dispose();
    _contactPhoneFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF054582),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          final isDesktop = screenWidth >= 900;
          return SizedBox(
            width: screenWidth,
            height: screenHeight,
            child: Stack(
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
                  child: SizedBox.expand(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 24 : 20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              children: [
                                const SizedBox(height: 40),
                                Image.asset(
                                  'assets/images/logo-small.png',
                                  width: 200,
                                  height: 100,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Image.network(
                                    'https://savt.by/wp-content/uploads/2025/10/logo-small.png',
                                    width: 200,
                                    height: 100,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 200,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [
                                          Colors.white70,
                                          Colors.white38
                                        ]),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Center(
                                          child: Text('SAVT',
                                              style: TextStyle(
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white))),
                                    ),
                                  ),
                                )
                                    .animate()
                                    .fadeIn(
                                        duration:
                                            const Duration(milliseconds: 800))
                                    .scale(
                                        begin: const Offset(0.8, 0.8),
                                        end: const Offset(1, 1),
                                        duration:
                                            const Duration(milliseconds: 800),
                                        curve: Curves.easeOutBack),
                                const SizedBox(height: 16),
                                Text('Добро пожаловать в SAVT Assist',
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white
                                                .withValues(alpha: 0.8),
                                            fontWeight: FontWeight.w500))
                                    .animate()
                                    .fadeIn(
                                        delay:
                                            const Duration(milliseconds: 400))
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
                                          color: Colors.black
                                              .withValues(alpha: 0.3),
                                          blurRadius: 30,
                                          offset: const Offset(0, 15),
                                          spreadRadius: -5),
                                      BoxShadow(
                                          color: const Color(0xFF054582)
                                              .withValues(alpha: 0.3),
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
                                        duration:
                                            const Duration(milliseconds: 300),
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
                                        delay:
                                            const Duration(milliseconds: 300),
                                        duration:
                                            const Duration(milliseconds: 600))
                                    .slideY(begin: 0.3, end: 0),
                                const SizedBox(height: 24),
                                TextButton(
                                  onPressed: _continueWithoutAuth,
                                  child: Text('Продолжить без входа →',
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
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
                ),
              ],
            ),
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
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
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
              focusNode: _loginPasswordFocusNode,
              isRegister: false),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen())),
                child: Text('Забыли пароль? Восстановите его через Telegram',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500))),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PasswordResetRequestScreen())),
                child: Text('Нет Telegram? Оставьте заявку на сброс пароля',
                    style: TextStyle(
                        fontSize: 12,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Номер телефона',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: _contactPhoneFocusNode.hasFocus
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Text(' *',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              _buildPhoneRow(
                  controller: _contactPhoneController,
                  focusNode: _contactPhoneFocusNode),
            ],
          ),
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
              onChanged: (_) {},
              title: 'Я согласен с политикой конфиденциальности',
              isPolicy: true,
              onTap: _showPrivacyPolicyDialog),
          const SizedBox(height: 12),
          _buildCheckbox(
              value: _isAdult,
              onChanged: (val) => setState(() => _isAdult = val ?? false),
              title: 'Я подтверждаю, что мне 16 лет или более'),
          const SizedBox(height: 20),
          _buildSubmitButton(
              text: 'Зарегистрироваться',
              onPressed: (!_agreeToPolicy || !_isAdult || _isLoading)
                  ? null
                  : _handleRegister),
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
              .map((country) => DropdownMenuItem<String>(
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
      key: ValueKey(_selectedCountryCode),
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.phone,
      inputFormatters: [PhoneInputFormatter(_selectedCountryCode)],
      decoration: const InputDecoration(hintText: 'Введите номер'),
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
        decoration: InputDecoration(hintText: 'Введите $label'),
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
      bool isPolicy = false,
      VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return Row(children: [
      SizedBox(
        width: 22,
        height: 22,
        child: Checkbox(
          value: value,
          onChanged: isPolicy ? (bool? v) {} : (bool? val) {
            if (val != null) {
              onChanged(val);
            }
          },
          activeColor: theme.colorScheme.primary,
          checkColor: Colors.white,
          fillColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return theme.colorScheme.primary;
            }
            return Colors.transparent;
          }),
          side: WidgetStateBorderSide.resolveWith((states) => BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          )),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      const SizedBox(width: 10),
      if (isPolicy)
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.primary,
                height: 1.3,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        )
      else
        Expanded(
            child: Text(title,
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
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
              shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4)),
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

class PhoneInputFormatter extends TextInputFormatter {
  final String countryCode;
  PhoneInputFormatter(this.countryCode);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    final clean = text.replaceAll(RegExp(r'[^0-9]'), '');

    String formatted = '';

    if (countryCode == '+375') {
      final digits = clean.substring(0, clean.length > 9 ? 9 : clean.length);
      final buffer = StringBuffer();
      if (digits.isNotEmpty) buffer.write('(');

      if (digits.length <= 7) {
        // Local 7-digit format: (XXX)-XX-XX
        for (int i = 0; i < digits.length; i++) {
          if (i == 3) buffer.write(')-');
          if (i == 5) buffer.write('-');
          buffer.write(digits[i]);
        }
      } else {
        // Mobile 9-digit format: (XX) XXX-XX-XX
        for (int i = 0; i < digits.length; i++) {
          if (i == 2) buffer.write(') ');
          if (i == 5) buffer.write('-');
          if (i == 7) buffer.write('-');
          buffer.write(digits[i]);
        }
      }
      formatted = buffer.toString();
    } else {
      // Russia: (XXX) XXX-XX-XX
      final digits = clean.substring(0, clean.length > 10 ? 10 : clean.length);
      final buffer = StringBuffer();
      if (digits.isNotEmpty) buffer.write('(');
      for (int i = 0; i < digits.length; i++) {
        if (i == 3) buffer.write(') ');
        if (i == 6) buffer.write('-');
        if (i == 8) buffer.write('-');
        buffer.write(digits[i]);
      }
      formatted = buffer.toString();
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
