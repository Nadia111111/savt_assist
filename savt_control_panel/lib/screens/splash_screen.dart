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

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (_isInitialized) return;
    _isInitialized = true;

    setState(() {
      _hasError = false;
      _status = 'Инициализация настроек...';
    });

    try {
      // 1. Initialize SharedPreferences
      await PreferencesService.init();
      AppTheme.loadTheme();

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

          // ⭐ Используем новый метод для получения количества непрочитанных
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

      // 4. Check onboarding
      final bool isOnboardingShown =
          PreferencesService.prefs.getBool('is_onboarding_shown') ?? false;

      if (!mounted) return;

      // 5. Navigate
      if (!isOnboardingShown) {
        Navigator.pushReplacementNamed(context, '/onboarding');
      } else if (isGuestMode) {
        Navigator.pushReplacementNamed(context, '/knowledge');
      } else if (isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/shu-list');
      } else {
        Navigator.pushReplacementNamed(context, '/auth');
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ControlPanelApp.onAppInitialized();
      });
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/images/logo-small.png',
                height: 90,
                width: 90,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.network(
                  'https://savt.by/wp-content/uploads/2025/10/logo-small.png',
                  height: 90,
                  width: 90,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 90,
                    width: 90,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.business, size: 48, color: Colors.white),
                  ),
                ),
              ),
              gapH32,
              if (!_hasError) ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                gapH24,
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else ...[
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 60),
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
    );
  }
}
