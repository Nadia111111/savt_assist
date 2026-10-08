// lib/auth/auth_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/animated_background.dart';
import '../screens/shu_list_screen.dart';
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

  static const _policySections = [
    {
      'title': '1. ОБЩИЕ ПОЛОЖЕНИЯ',
      'content': '1.1. Настоящая Политика в отношении обработки персональных данных (далее - Политика) разработана во исполнение требований Закона Республики Беларусь от 7 мая 2021 г. № 99-3 «О защите персональных данных» (далее - Закон), а также иных требований законодательства в области обработки персональных данных.\n\n1.2. Настоящая Политика определяет цели, условия и способы обработки персональных данных, перечень субъектов персональных данных и обрабатываемых персональных данных, права субъектов персональных данных, а также реализуемые в Обществе с ограниченной ответственностью «Сфера Секьюрити» (далее - Общество, Оператор) требования к защите персональных данных.\n\n1.3. Настоящая Политика распространяет свое действие на все процессы Общества, связанные с обработкой персональных данных субъектов, за исключением обработки персональных данных пользователей сайта www.secur.by.\n\n1.4. Политика обязательна для применения всеми работниками Общества, осуществляющими обработку персональных данных согласно своим должностным обязанностями.\n\n1.5. При внесении изменений в акты законодательства, а также в случае принятия иных нормативных правовых актов по вопросам, регулируемым настоящей Политикой, необходимо руководствоваться такими изменениями, иными нормативными правовыми актами до внесения соответствующих изменений в Политику.\n\n1.6. Положения настоящей Политики служат основой для разработки локальных правовых актов, регламентирующих в Обществе вопросы обработки, защиты, обеспечения конфиденциальности персональных данных.\n\n1.7. Для целей настоящей Политики используются определения, содержащиеся в Законе о защите персональных данных.\n\n1.8. Политика определяется в соответствии со следующими нормативными правовыми актами:\n\nКонституция Республики Беларусь;\nТрудовой кодекс Республики Беларусь;\nЗакон о защите персональных данных;\nЗакон Республики Беларусь от 21.07.2008 № 418-З «О регистре населения»;\nЗакон Республики Беларусь от 10.11.2008 № 455-З «Об информации, информатизации и защите информации»;\nУстав Общества;\nиные нормативные правовые акты Республики Беларусь и нормативные документы уполномоченных органов государственной власти.',
    },
    {
      'title': '2. ЦЕЛИ ОБРАБОТКИ ПЕРСОНАЛЬНЫХ ДАННЫХ',
      'content': 'В процессе своей деятельности Общество осуществляет обработку персональных данных в следующих целях:\n\n2.1. осуществления функций, полномочий и обязанностей, возложенных законодательством Республики Беларусь на Общество, в том числе по предоставлению персональных данных в органы государственной власти, в Фонд социальной защиты населения Министерства труда и социальной защиты Республики Беларусь, а также в иные государственные органы и организации;\n\n2.2. регулирования трудовых отношений с работниками Общества;\n\n2.3. ведение бухгалтерского, налогового учета;\n\n2.4. проведения мероприятий и обеспечения участия в них субъектов персональных данных;\n\n2.5. обеспечения пропускного режима в Обществе;\n\n2.6. исполнения судебных актов, актов других органов или должностных лиц, подлежащих исполнению в соответствии с законодательством Республики Беларусь об исполнительном производстве;\n\n2.7. исполнение договоров, соглашений в рамках договорной работы;\n\n2.8. осуществление сервисного обслуживания потребителей;\n\n2.9. направление ответа на поступившее обращение;\n\n2.10. в иных законных целях.\n\n2.11. Обработка персональных данных работников Общества для целей, не предусмотренных законодательством и не связанных с исполнением работниками должностных обязанностей, осуществляется с согласия работников, если отсутствуют иные правовые основания для такой обработки.\n\n2.12. Общество осуществляет обработку только тех персональных данных, которые необходимы для выполнения заявленных целей и не допускает их избыточной обработки.',
    },
    {
      'title': '3. СУБЪЕКТЫ ПЕРСОНАЛЬНЫХ ДАННЫХ, ПЕРЕЧЕНЬ ОБРАБАТЫВАЕМЫХ ПЕРСОНАЛЬНЫХ ДАННЫХ',
      'content': 'Субъекты персональных данных\tПеречень обрабатываемых персональных данных\nРаботники, в том числе бывшие работники Общества\tДанные, предоставляемые работниками в рамках оформления и осуществления трудовых отношений\nЧлены семьи работников Общества\tФИО; степень родства; год рождения; иные персональные данные, предоставляемые работниками в соответствии с требованиями трудового законодательства.\nКандидаты на трудоустройство в Общество\tФИО; дата рождения; гражданство; данные об образовании; контактные данные; иные данные, которые могут быть указаны в резюме или анкете кандидата.\nРаботники и иные представители контрагентов - юридических лиц\tДанные, предоставляемые контрагентами в рамках заключения и исполнения договоров\nКонтрагенты - физические лица\tДанные, предоставляемые контрагентами в рамках заключения и исполнения договоров\nПотребители\tФИО; контактные данные; иные данные, необходимые для регистрации и анализа обращения.\n\n3.1. Содержание и объем обрабатываемых персональных данных должны соответствовать заявленным целям обработки, предусмотренным в разделе 2 Политики. Обрабатываемые персональные данные не должны быть избыточными по отношению к заявленным целям их обработки.\n\n3.2. Передавая Оператору персональные данные, субъект персональных данных подтверждает свое согласие на обработку соответствующей информации на условиях, изложенных в настоящей Политике.\n\n3.3. Обработка персональных данных прекращается при наступлении одного или нескольких из указанных событий:\n\nпоступил отзыв согласия на обработку его персональных данных в порядке, установленным Политикой (за исключением случаев, предусмотренных действующим законодательством);\nдостигнуты цели их обработки;\nистек срок действия согласия субъекта;\nобнаружена неправомерная обработка персональных данных;\nпрекращена деятельность Общества.\n\n3.4. Общество может предоставлять субъектам обработки персональных данных иную информацию, необходимую для обеспечения прозрачности процесса обработки персональных данных.\n\n3.5. Обработка Обществом биометрических персональных данных осуществляется в соответствии с законодательством Республики Беларусь.\n\n3.6. Перечень действий с персональными данными, на совершение которых дается согласие:\n\nсбор;\nсистематизацию;\nнакопление;\nхранение;\nуточнение (обновление, изменение);\nиспользование;\nпередачу третьим лицам, в том числе трансграничную передачу;\nпередачу по сетям связи общего пользования, информационно-телекоммуникационным сетям, в том числе трансграничную передачу;\nобезличивание;\nблокирование;\nуничтожение персональных данных;\nобработку в информационных системах и/или без их использования.\n\n3.7. Обществом не осуществляется обработка специальных персональных данных, касающихся расовой, национальной принадлежности, политических взглядов, религиозных или философских убеждений, состояния здоровья, интимной жизни, за исключением случаев, предусмотренных законодательством.',
    },
    {
      'title': '4. ПОРЯДОК И УСЛОВИЯ ОБРАБОТКИ ПЕРСОНАЛЬНЫХ ДАННЫХ',
      'content': '4.1. Доступ и обработка персональных данных разрешается только уполномоченным работникам Общества по работе с персональными данными.\n\n4.2. Персональные данные в Обществе обрабатываются с согласия субъекта персональных данных на обработку его персональных данных, если иное не предусмотрено законодательством Республики Беларусь в области персональных данных.\n\n4.3. Общество без согласия субъекта персональных данных не раскрывает третьим лицам и не распространяет персональные данные, если иное не предусмотрено законодательством Республики Беларусь.\n\n4.4. Персональные данные в Обществе обрабатываются, как правило, с использованием средств автоматизации. Допускается обработка в установленном порядке персональных данных без использования средств автоматизации, если при этом обеспечиваются поиск персональных данных и (или) доступ к ним по определенным критериям (журнал, список и др.).\n\n4.5. В целях внутреннего информационного обеспечения Общество может создавать справочники, адресные книги и другие источники, в которые с согласия субъекта персональных данных, если иное не предусмотрено законодательством, могут включаться его персональные данные.\n\n4.6. Общество в процессе своей деятельности вправе осуществлять трансграничную передачу персональных данных.',
    },
    {
      'title': '5. ПРАВА СУБЪЕКТОВ ПЕРСОНАЛЬНЫХ ДАННЫХ',
      'content': 'Права субъектов персональных данных\tОбязанности Общества по реализации прав\nполучение информации, касающейся обработки своих персональных данных, а именно: наименование и место нахождения Общества; подтверждение факта обработки персональных данных; его персональные данные и источник их получения; правовые основания и цели обработки персональных данных; срок, на который дано его согласие; наименование и место нахождения уполномоченного лица, которое является государственным органом, юридическим лицом Республики Беларусь, иной организацией, если обработка персональных данных поручена Обществу такому лицу\tОбщество в течение пяти рабочих дней после получения соответствующего запроса предоставит такому Субъекту запрашиваемую информацию либо уведомит его о причинах отказа в ее предоставлении.\nполучение информации о предоставлении персональных данных третьим лицам один раз в календарный год бесплатно\tОбщество в пятнадцатидневный срок после получения соответствующего запроса предоставит Субъекту информацию о том, какие персональные данные этого Субъекта и кому предоставлялись в течение года, предшествовавшего дате подачи заявления, либо уведомит Субъекта о причинах отказа в ее предоставлении.\nтребовать прекращения обработки персональных данных и (или) их удаления, включая их удаление, при отсутствии оснований для обработки персональных данных, предусмотренных Законом и иными законодательными актами\tОбщество в пятнадцатидневный срок после получения заявления Субъекта прекратит обработку персональных данных, а также осуществит их удаление (обеспечит прекращение обработки персональных данных, а также их удаление уполномоченным лицом) и уведомит об этом Субъекта. В случае отсутствия у Общества технической возможности удаления персональных данных, Общество примет меры по недопущению дальнейшей обработки персональных данных, включая их блокирование, и уведомить об этом Субъекта в тот же срок.\nвнесение изменений в свои персональные данные, если персональные данные являются неполными, устаревшими или неточными. Субъект к своему заявлению, содержащему такое требование, должен приложить соответствующие документы и (или) их заверенные в установленном порядке копии, подтверждающие необходимость внесения изменений в персональные данные\tОбщество в пятнадцатидневный срок после получения заявления Субъекта внесет соответствующие изменения в его персональные данные и уведомит об этом Субъекта либо уведомит Субъекта о причинах отказа во внесении таких изменений, если иной порядок внесения изменений в персональные данные не установлен законодательными актами.\nотзыв согласия субъекта персональных данных в любое время без объяснения посредством подачи Обществу соответствующего заявления, если для обработки персональных данных Общество обращалось к субъекту персональных данных за получением согласия. В этой связи право на отзыв согласия не может быть реализовано в случае, когда обработка осуществляется в случаях, предусмотренных законодательством.\tОбщество в пятнадцатидневный срок после получения заявления Субъекта в соответствии с его содержанием прекратит обработку персональных данных, осуществит их удаление и уведомит об этом Субъекта. При отсутствии технической возможности удаления персональных данных Общество примет меры по недопущению дальнейшей обработки персональных данных, включая их блокирование, и уведомить об этом Субъекта в тот же срок.\nобжалование действий (бездействия) и решений Общества, связанных с обработкой персональных данных, нарушающие его права при обработке персональных данных, в уполномоченный орган по защите прав субъектов персональных данных в порядке, установленном законодательством об обращениях граждан и юридических лиц.\t\n\n5.1. Субъект для реализации прав, указанных в настоящем разделе Политики, подает Обществу заявление:\n\nв письменной форме по адресу: 220118 г. Минск, ул. Машиностроителей, 29-117\nв виде электронного документа, содержащего электронную цифровую подпись субъекта персональных данных, на электронный адрес: pavel@secur.by.\n\n5.2. Заявление должно содержать:\nфамилию, собственное имя, отчество (если таковое имеется) Субъекта, адрес его места жительства (места пребывания);\nдату рождения Субъекта;\nидентификационный номер Субъекта, при отсутствии такого номера – номер документа, удостоверяющего личность Субъекта, в случаях, если эта информация указывалась Субъектом при даче своего согласия Обществу или обработка персональных данных осуществляется без согласия Субъекта;\nизложение сути требований Субъекта;\nличную подпись либо электронную цифровую подпись Субъекта.\n\n5.3. Общество направит ответ на заявление Субъекту в форме, соответствующей форме подачи заявления, если в самом заявлении не указано иное.',
    },
    {
      'title': '6. ЗАКЛЮЧИТЕЛЬНЫЕ ПОЛОЖЕНИЯ',
      'content': '6.1. Общество вправе вносить изменения в настоящую Политику. Политику, а также все вносимые в нее изменения и дополнения утверждает директор Общества.\n\n6.2. Внутренний контроль за соблюдением Обществом законодательства Республики Беларусь в области персональных данных, в том числе требований к защите персональных данных, осуществляется лицом, ответственным за осуществление внутреннего контроля за обработкой персональных данных в Обществе – заместителем директора по общим вопросам.\n\n6.3. Политика размещается в локальной сети Битрикс 24.\n\n6.4. Контакты Общества:\n220118, г. Минск, ул. Машиностроителей,29-117\nТел/факс: +375 17 341 50 50\nE-mail: info@secur.by',
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

  Future<void> _saveRegistrationDraft({bool isWaitingCode = false, Map<String, dynamic>? startResult}) async {
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
      final bool hasData = (data['full_name'] != null && (data['full_name'] as String).isNotEmpty) ||
          (data['phone'] != null && (data['phone'] as String).isNotEmpty);

      setState(() {
        if (hasData) {
          _isLoginMode = false;
        }
        if (data['full_name'] != null) _fullNameController.text = data['full_name'];
        if (data['user_type'] != null) _userType = data['user_type'];
        if (data['org_name'] != null) _orgNameController.text = data['org_name'];
        if (data['phone'] != null) _contactPhoneController.text = data['phone'];
        if (data['country_code'] != null) _selectedCountryCode = data['country_code'];
        if (data['password'] != null) _passwordController.text = data['password'];
        if (data['confirm_password'] != null) _confirmPasswordController.text = data['confirm_password'];
        if (data['registration_token'] != null) _registrationToken = data['registration_token'];
      });

      final bool isWaitingCode = data['is_waiting_code'] == true;
      final dynamic startResultRaw = data['start_result'];
      final Map<String, dynamic>? startResult = startResultRaw is Map
          ? Map<String, dynamic>.from(startResultRaw)
          : null;

      if (isWaitingCode && _registrationToken != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final dialogData = startResult ?? {
            'registration_token': _registrationToken,
            'deep_link': null,
          };
          _showCodeVerificationDialog(dialogData, rememberMe: _rememberMe, initialShowCodeInput: true);
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
    final cleanPhoneDigits = _contactPhoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
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
      _showErrorSnackBar('Необходимо согласие с политикой обработки данных');
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
      final success = await _showCodeVerificationDialog(result, rememberMe: _rememberMe);
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

  Future<bool> _showCodeVerificationDialog(Map<String, dynamic> startResult, {bool rememberMe = false, bool initialShowCodeInput = false}) async {
    final codeController = TextEditingController();
    final theme = Theme.of(context);
    String? currentDeepLink = startResult['deep_link'];
    bool showCodeInput = initialShowCodeInput || currentDeepLink == null;
    int resendSeconds = startResult['resend_after_seconds'] ?? 60;
    bool canResend = false;
    bool isSubmittingRequest = false;
    Timer? resendTimer;

    Future<void> submitRegisterRequest(void Function(void Function()) setStateDialog) async {
      setStateDialog(() => isSubmittingRequest = true);
      try {
        final cleanPhoneDigits = _contactPhoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
        final phone = _selectedCountryCode + cleanPhoneDigits;
        await authService.registerRequest(
          phone: phone,
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          userType: _userType == 'private' ? 'individual' : 'organization',
          organizationName: _userType == 'organization' ? _orgNameController.text.trim() : null,
          contactPhone: phone,
        );
        resendTimer?.cancel();
        await _clearRegistrationDraft();
        if (mounted) {
          Navigator.pop(context, false);
          _showSuccessSnackBar('Заявка на регистрацию отправлена. Ожидайте одобрения администратором.');
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
                    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Row(
                      children: [
                        const Icon(Icons.telegram, color: Color(0xFF229ED9), size: 26),
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
                              await _saveRegistrationDraft(isWaitingCode: true, startResult: startResult);
                              try {
                                final uri = Uri.parse(currentDeepLink!);
                                final launched = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
                                if (!launched) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              } catch (_) {
                                try {
                                  await launchUrl(Uri.parse(currentDeepLink!), mode: LaunchMode.externalApplication);
                                } catch (e) {
                                  _showErrorSnackBar('Не удалось открыть Telegram: $e');
                                }
                              }
                            },
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('Открыть Telegram-бот'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF229ED9),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                    child: CircularProgressIndicator(strokeWidth: 2),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('Отмена',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
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
                  insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                                    final res = await authService.resendRegisterCode(_registrationToken!);
                                    setStateDialog(() {
                                      resendSeconds = res['resend_after_seconds'] ?? 60;
                                      canResend = false;
                                      currentDeepLink = res['deep_link'];
                                      if (currentDeepLink != null) {
                                        showCodeInput = false;
                                        resendTimer?.cancel();
                                        resendTimer = null;
                                        _showErrorSnackBar('Вернитесь в Telegram и подтвердите номер.');
                                      } else {
                                        _showSuccessSnackBar('Код отправлен повторно в Telegram.');
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
                           await authService.registerComplete(_registrationToken!, code, rememberMe: rememberMe);
                          resendTimer?.cancel();
                          await _clearRegistrationDraft();
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (e) {
                          if (e is AuthException) {
                            if (e.statusCode == 404) {
                              _showErrorSnackBar('Регистрация истекла. Начните регистрацию заново.');
                              resendTimer?.cancel();
                              await _clearRegistrationDraft(keepFields: true);
                              if (context.mounted) Navigator.pop(context, false);
                              return;
                            }
                            if (e.statusCode == 400 && e.message.contains('Номер ещё не подтверждён')) {
                              setStateDialog(() {
                                showCodeInput = false;
                                currentDeepLink = startResult['deep_link'] ?? currentDeepLink;
                                resendTimer?.cancel();
                                resendTimer = null;
                              });
                              _showErrorSnackBar('Номер еще не подтвержден. Пожалуйста, вернитесь в Telegram и нажмите кнопку "Отправить мой номер".');
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
    final cleanLoginDigits = _loginPhoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final fullPhone = _selectedCountryCode + cleanLoginDigits;
    if (fullPhone.isEmpty || _loginPasswordController.text.isEmpty) {
      _showErrorSnackBar('Заполните все поля');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await authService.login(fullPhone, _loginPasswordController.text, rememberMe: _rememberMe);
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

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'Политика обработки персональных данных',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  children: [
                    Expanded(
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
                              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() => _agreeToPolicy = true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Я согласен(согласна) с политикой',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
                    padding:
                        EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 20),
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
                                        color: Colors.white.withValues(alpha: 0.8),
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
                                      color: Colors.black.withValues(alpha: 0.3),
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
                                      color: Colors.white.withValues(alpha: 0.7),
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
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
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
                  controller: _contactPhoneController, focusNode: _contactPhoneFocusNode),
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
              onChanged: (val) {},
              title: 'Я согласен с политикой обработки данных',
              isPolicy: true,
              onTap: _showPrivacyPolicyDialog),
          const SizedBox(height: 20),
          _buildSubmitButton(
              text: 'Зарегистрироваться',
              onPressed:
                  (!_agreeToPolicy || _isLoading) ? null : _handleRegister),
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
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: value,
            onChanged: isPolicy ? null : (bool? val) => onChanged(val ?? false),
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
      ]),
    );
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

