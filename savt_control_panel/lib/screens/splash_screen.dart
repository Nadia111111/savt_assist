import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../theme/app_spacing.dart';
import '../main.dart';
import '../services/preferences_service.dart';
import '../services/app_theme.dart';
import '../services/token_storage.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/cabinet_service.dart';
import '../services/chat_service.dart';
import '../services/upload_service.dart';
import '../services/knowledge_service.dart';
import '../services/favorites_service.dart';
import '../services/service_request_service.dart';
import '../services/reclamations_service.dart';
import '../services/offline_service.dart';
import '../services/push_service.dart';
import '../services/notification_service.dart' as notif;
import '../services/user_events_service.dart';
import '../widgets/savt_animated_logo.dart';
import '../widgets/animated_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Запуск приложения...';
  bool _hasError = false;
  String _errorMessage = '';
  bool _isInitialized = false;

  bool _isFirstLaunch = false;
  bool _readyToNavigate = false;
  String? _targetRoute;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      precacheImage(const AssetImage('assets/images/logo_letter_s.png'), context);
      precacheImage(const AssetImage('assets/images/logo_letter_avt.png'), context);
    } catch (_) {}
  }

  void _onLogoCycleCompleted() {
    // Срабатывает в конце каждого цикла, когда буквы AVT уже полностью нырнули обратно в букву S.
    // Если проверка авторизации/инициализация готова, выполняем переход в приложение!
    if (_readyToNavigate && _targetRoute != null) {
      _navigateToTarget();
    }
  }

  void _skipIntro() {
    if (_targetRoute != null) {
      _navigateToTarget();
    } else {
      _readyToNavigate = true;
    }
  }

  void _navigateToTarget() {
    if (!mounted || _targetRoute == null) return;

    Navigator.pushReplacementNamed(context, _targetRoute!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ControlPanelApp.onAppInitialized();
    });
  }

  Future<void> _initializeApp() async {
    if (_isInitialized) return;
    _isInitialized = true;

    setState(() {
      _hasError = false;
      _status = 'Инициализация настроек...';
    });

    try {
      // 1. Initialize SharedPreferences & determine if it's first launch (before onboarding)
      await PreferencesService.init();
      AppTheme.loadTheme();

      final bool isOnboardingShown =
          PreferencesService.prefs.getBool('is_onboarding_shown') ?? false;

      if (mounted) {
        setState(() {
          _isFirstLaunch = !isOnboardingShown;
        });
      }

      setState(() {
        _status = 'Настройка компонентов...';
      });

      // 2. Initialize Services
      tokenStorage = TokenStorage();
      apiClient = ApiClient(tokenStorage);
      authService = AuthService(apiClient, tokenStorage);
      cabinetService = CabinetService(apiClient);
      chatService = ChatService(apiClient);
      uploadService = UploadService(apiClient);
      knowledgeService = KnowledgeService(apiClient);
      favoritesService = FavoritesService(apiClient);
      serviceRequestService = ServiceRequestService(apiClient);
      reclamationsService = ReclamationsService(apiClient);
      userEventsService = UserEventsService(apiClient, tokenStorage);
      OfflineService().start();

      setState(() {
        _status = 'Проверка авторизации...';
      });

      // 3. Check Auth & Onboarding state
      final accessToken = await tokenStorage.getAccessToken();
      bool isLoggedIn = accessToken != null && accessToken.isNotEmpty;
      final isGuestMode = tokenStorage.isGuestMode;

      if (isLoggedIn && !isGuestMode) {
        setState(() {
          _status = 'Проверка учетной записи...';
        });

        bool tokenValid = false;

        try {
          await authService.getMe().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('⏱️ Таймаут проверки токена');
              throw Exception('Timeout');
            },
          );
          tokenValid = true;
          debugPrint('✅ Токен валидный');
        } catch (e) {
          debugPrint('❌ Ошибка проверки токена: $e');
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('401') ||
              errStr.contains('403') ||
              errStr.contains('unauthorized') ||
              errStr.contains('сессия истекла')) {
            await tokenStorage.clearTokens();
            isLoggedIn = false;
            tokenValid = false;
          } else {
            // При ошибке сети, таймауте или временном сбое сервера сохраняем авторизацию
            debugPrint('⚠️ Ошибка сети при проверке токена, продолжаем с сохраненной сессией');
            tokenValid = true;
            isLoggedIn = true;
          }
          try {
            await userEventsService.stop();
          } catch (_) {}
        }

        if (tokenValid && isLoggedIn) {
          setState(() {
            _status = 'Загрузка данных...';
          });

          try {
            await favoritesService.loadFavorites().timeout(
                  const Duration(seconds: 8),
                  onTimeout: () =>
                      throw Exception('Таймаут загрузки избранного'),
                );
          } catch (e) {
            debugPrint('Ошибка загрузки данных: $e');
          }

          // ⭐ Получаем количество непрочитанных
          try {
            final notifService = notif.NotificationService(apiClient);
            final count = await notifService.getUnreadCount().timeout(
                  const Duration(seconds: 5),
                  onTimeout: () => 0,
                );
            OfflineService().updateUnreadNotificationCount(count);
            debugPrint('✅ Загружено непрочитанных уведомлений: $count');
          } catch (e) {
            debugPrint('Ошибка загрузки количества непрочитанных: $e');
          }

          if (!kIsWeb) {
            try {
              await PushService(apiClient).registerToken().timeout(
                    const Duration(seconds: 15),
                    onTimeout: () =>
                        throw Exception('Таймаут регистрации пуш-токена'),
                  );
            } catch (e) {
              debugPrint('Ошибка регистрации пуш-токена: $e');
            }
          }

          try {
            await userEventsService.start();
          } catch (e) {
            debugPrint('Ошибка запуска user events: $e');
          }
        }
      }

      if (!mounted) return;

      // 4. Set target navigation route
      if (!isOnboardingShown) {
        _targetRoute = '/onboarding';
      } else if (isGuestMode) {
        _targetRoute = '/knowledge';
      } else if (isLoggedIn) {
        _targetRoute = '/shu-list';
      } else {
        _targetRoute = '/auth';
      }

      // 5. Помечаем готовность к переходу.
      // Переход произойдет СТРОГО в момент, когда буквы AVT завершат погружение в S!
      if (mounted) {
        setState(() {
          _readyToNavigate = true;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Ошибка инициализации приложения: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF054582),
      body: Stack(
        children: [
          // Фирменный фон с плавающими кругами/пузырями (как на страницах авторизации и регистрации)
          const Positioned.fill(
            child: AnimatedBackground(
              gradientColors: [
                Color(0xFF054582),
                Color(0xFF0a7ac2),
                Color(0xFF0d3a5c),
              ],
              floatUpwards: true,
              circleCount: 10,
            ),
          ),
          SafeArea(
            child: Stack(
            children: [
              // Кнопка "Пропустить" при первом запуске (интро перед онбордингом)
              if (_isFirstLaunch && !_hasError)
                Positioned(
                  top: 16,
                  right: 16,
                  child: TextButton(
                    onPressed: _skipIntro,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Пропустить',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 12),
                      ],
                    ),
                  ),
                ),

              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Анимированный логотип SAVT с адаптивным центрированием
                      SavtAnimatedLogo(
                        height: kIsWeb ? 82 : 68,
                        loop: true,
                        duration: kIsWeb
                            ? const Duration(milliseconds: 50000)
                            : const Duration(milliseconds: 3200),
                        onCycleCompleted: _onLogoCycleCompleted,
                      ),

                      if (!_hasError) ...[
                        // Текст статуса отображается при проверке авторизации
                        if (!_isFirstLaunch) ...[
                          const SizedBox(height: 28),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              _status,
                              key: ValueKey<String>(_status),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ] else ...[
                        const SizedBox(height: 32),
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 54,
                        ),
                        gapH16,
                        const Text(
                          'Не удалось запустить приложение',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        gapH8,
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red.shade100,
                            fontSize: 14,
                          ),
                        ),
                        gapH24,
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: theme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _hasError = false;
                              _errorMessage = '';
                              _isInitialized = false;
                              _readyToNavigate = false;
                              _targetRoute = null;
                            });
                            _initializeApp();
                          },
                          child: const Text('Повторить'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}
