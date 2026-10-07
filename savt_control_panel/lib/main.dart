// lib/main.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'theme/app_colors.dart';
import 'auth/auth_page.dart';
import 'screens/chat_screen.dart';
import 'screens/shu_detail_screen.dart';
import 'screens/service_request_screen.dart';
import 'screens/service_request_detail_screen.dart';
import 'screens/request_detail_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/search_messages_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/operator_panel_screen.dart';
import 'screens/my_documents_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/register_request_screen.dart';
import 'screens/password_reset_request_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/change_phone_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/chat_settings_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/navigation_container.dart';
import 'screens/create_reclamation_screen.dart';
import 'screens/reclamation_detail_screen.dart';
import 'screens/requests_hub_screen.dart';
import 'widgets/connection_notification_wrapper.dart';
import 'services/app_theme.dart';
import 'services/preferences_service.dart';
import 'services/token_storage.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/cabinet_service.dart';
import 'services/chat_service.dart';
import 'services/upload_service.dart';
import 'services/knowledge_service.dart';
import 'services/favorites_service.dart';
import 'services/service_request_service.dart';
import 'services/reclamations_service.dart';
import 'services/user_events_service.dart';
import 'services/deep_link_service.dart';
import 'package:app_links/app_links.dart';

late TokenStorage tokenStorage;
late ApiClient apiClient;
late AuthService authService;
late CabinetService cabinetService;
late ChatService chatService;
late UploadService uploadService;
late KnowledgeService knowledgeService;
late FavoritesService favoritesService;
late ServiceRequestService serviceRequestService;
late ReclamationsService reclamationsService;
late UserEventsService userEventsService;

final FlutterLocalNotificationsPlugin _backgroundLocalNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    final title = message.notification?.title ??
        message.data['title'] ??
        message.data['message_title'] ??
        'Новое уведомление';
    final body = message.notification?.body ??
        message.data['body'] ??
        message.data['message_body'] ??
        message.data['message'] ??
        '';

    const androidDetails = AndroidNotificationDetails(
      'main_channel',
      'Основной канал',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Only show local notification for data-only messages to avoid duplicates
    // when the system already displays the notification from the 'notification' field.
    if (message.notification == null) {
      await _backgroundLocalNotifications.show(
        id: title.hashCode ^ body.hashCode,
        title: title,
        body: body,
        notificationDetails: details,
      );
    }

    debugPrint("Handling a background message: ${message.messageId}");
  } catch (e) {
    debugPrint("Background message handler error: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Глобальный обработчик ошибок Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('❌ Flutter Error: ${details.exception}');
    debugPrint('❌ Stack trace: ${details.stack}');
    FlutterError.dumpErrorToConsole(details);
  };

  // ✅ Обработка ошибок в изолятах
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('❌ Platform Error: $error');
    return true;
  };

  // Блокируем смену ориентации экрана (только на мобильных платформах)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Предварительная инициализация базовых сервисов, чтобы гарантировать готовность к DeepLink и роутам
  try {
    await PreferencesService.init();
    AppTheme.loadTheme();
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
  } catch (e) {
    debugPrint('⚠️ Ошибка предварительной инициализации сервисов: $e');
  }

  // Инициализируем Firebase (только на нативных платформах без отдельной веб-конфигурации)
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );
      await _backgroundLocalNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final data = jsonDecode(response.payload!);
              if (data is Map<String, dynamic>) {
                handleNotificationNavigation(data);
              }
            } catch (_) {}
          }
        },
      );

      if (Firebase.apps.isNotEmpty) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }
      debugPrint('✅ Firebase initialized successfully');
    } catch (e) {
      debugPrint('❌ Firebase initialization error: $e');
    }
  }

  runApp(const ControlPanelApp());
}

PageRouteBuilder<T> _buildRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
    transitionDuration: const Duration(milliseconds: 150),
    opaque: true,
  );
}

void handleNotificationNavigation(Map<String, dynamic> data) {
  Map<String, dynamic> resolved = Map<String, dynamic>.from(data);
  if (resolved['data'] is Map) {
    resolved.addAll(Map<String, dynamic>.from(resolved['data']));
  } else if (resolved['data'] is String && (resolved['data'] as String).isNotEmpty) {
    try {
      resolved.addAll(Map<String, dynamic>.from(jsonDecode(resolved['data'])));
    } catch (_) {}
  }
  if (resolved['payload'] is Map) {
    resolved.addAll(Map<String, dynamic>.from(resolved['payload']));
  } else if (resolved['payload'] is String && (resolved['payload'] as String).isNotEmpty) {
    try {
      resolved.addAll(Map<String, dynamic>.from(jsonDecode(resolved['payload'])));
    } catch (_) {}
  }

  final chatId = resolved['chat_id']?.toString() ?? resolved['chatId']?.toString();
  final type = resolved['type']?.toString();
  final entityType = resolved['entity_type']?.toString() ?? resolved['entityType']?.toString();
  final reclamationId = resolved['reclamation_id']?.toString() ??
      resolved['reclamationId']?.toString() ??
      ((type == 'reclamation' || type == 'reclamation_status' || entityType == 'reclamation')
          ? (resolved['id']?.toString() ?? resolved['entity_id']?.toString())
          : null);
  final requestId =
      resolved['request_id']?.toString() ?? resolved['requestId']?.toString();
  final cabinetId =
      resolved['cabinet_id']?.toString() ?? resolved['shu_id']?.toString() ?? resolved['cabinetId']?.toString();

  if (chatId != null && chatId.isNotEmpty) {
    ControlPanelApp.navigatorKey.currentState?.pushNamed('/chat/$chatId');
  } else if (reclamationId != null && reclamationId.isNotEmpty) {
    ControlPanelApp.navigatorKey.currentState
        ?.pushNamed('/reclamation-detail/$reclamationId');
  } else if (requestId != null && requestId.isNotEmpty) {
    ControlPanelApp.navigatorKey.currentState
        ?.pushNamed('/service-request-detail/$requestId');
  } else if (type == 'reclamation' || type == 'reclamations') {
    ControlPanelApp.navigatorKey.currentState?.pushNamed('/reclamations');
  } else if (type == 'request_status' || type == 'service_request') {
    ControlPanelApp.navigatorKey.currentState?.pushNamed('/my-requests');
  } else if (cabinetId != null && cabinetId.isNotEmpty) {
    ControlPanelApp.navigatorKey.currentState
        ?.pushNamed('/shu-detail/$cabinetId');
  } else if (type == 'chat_message') {
    ControlPanelApp.navigatorKey.currentState?.pushNamed('/chats');
  } else if (type == 'warranty_expiring') {
    ControlPanelApp.navigatorKey.currentState?.pushNamed('/notifications');
  } else if (type == 'cabinet_alarm') {
    if (cabinetId != null && cabinetId.isNotEmpty) {
      ControlPanelApp.navigatorKey.currentState
          ?.pushNamed('/shu-detail/$cabinetId');
    } else {
      ControlPanelApp.navigatorKey.currentState?.pushNamed('/notifications');
    }
  } else {
    ControlPanelApp.navigatorKey.currentState?.pushNamed('/notifications');
  }
}

class ControlPanelApp extends StatefulWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static bool isAppInitialized = false;
  static String? pendingDeepLink;

  static void onAppInitialized() {
    isAppInitialized = true;
    if (pendingDeepLink != null) {
      final link = pendingDeepLink!;
      pendingDeepLink = null;
      print('🔗 [main.dart] Запуск отложенной ссылки после инициализации: "$link"');
      DeepLinkService.handleDeepLinkString(link);
    }
  }

  const ControlPanelApp({super.key});

  @override
  State<ControlPanelApp> createState() => _ControlPanelAppState();
}

class _ControlPanelAppState extends State<ControlPanelApp> {
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initPushNotificationHandling();
    _initDeepLinking();
  }

  void _initPushNotificationHandling() {
    if (kIsWeb) return;
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('Firebase not initialized, skipping push handling');
        return;
      }

      // Обработка push-уведомлений на переднем плане (foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('Foreground push received: ${message.data}');
        final title = message.notification?.title ??
            message.data['title'] ??
            message.data['message_title'] ??
            'Новое уведомление';
        final body = message.notification?.body ??
            message.data['body'] ??
            message.data['message_body'] ??
            message.data['message'] ??
            '';

        const androidDetails = AndroidNotificationDetails(
          'main_channel',
          'Основной канал',
          importance: Importance.max,
          priority: Priority.high,
        );
        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
        const details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        await _backgroundLocalNotifications.show(
          id: title.hashCode ^ body.hashCode,
          title: title,
          body: body,
          notificationDetails: details,
          payload: jsonEncode(message.data),
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from notification: ${message.data}');
        handleNotificationNavigation(message.data);
      });

      FirebaseMessaging.instance
          .getInitialMessage()
          .then((RemoteMessage? message) {
        if (message != null) {
          debugPrint('Initial message received: ${message.data}');
          Future.delayed(const Duration(milliseconds: 500), () {
            handleNotificationNavigation(message.data);
          });
        }
      }).catchError((e) {
        debugPrint('Error getting initial message: $e');
      });
    } catch (e) {
      debugPrint('Firebase messaging not initialized or unavailable: $e');
    }
  }

  void _initDeepLinking() async {
    if (kIsWeb) return;
    _appLinks = AppLinks();

    // 1. Проверяем начальную ссылку (Cold start)
    try {
      final initialString = await _appLinks.getInitialLinkString();
      if (initialString != null && initialString.isNotEmpty) {
        print('🔗 [main.dart] Холодный старт, ссылка (строка): "$initialString"');
        _handleDeepLink(initialString);
      } else {
        final initialUri = await _appLinks.getInitialLink();
        if (initialUri != null) {
          print('🔗 [main.dart] Холодный старт, ссылка (Uri): "$initialUri"');
          _handleDeepLink(initialUri.toString());
        }
      }
    } catch (e) {
      print('⚠️ [main.dart] Ошибка getInitialLink: $e');
    }

    // 2. Слушаем стрим ссылок как сырые строки (onNewIntent / Warm start)
    _appLinks.stringLinkStream.listen((linkString) {
      if (linkString.isNotEmpty) {
        print('🔗 [main.dart] Ссылка из stringLinkStream: "$linkString"');
        _handleDeepLink(linkString);
      }
    }, onError: (err) {
      print('⚠️ [main.dart] Ошибка в stringLinkStream: $err');
    });

    // 3. Дополнительно слушаем uriLinkStream
    _appLinks.uriLinkStream.listen((uri) {
      print('🔗 [main.dart] Ссылка из uriLinkStream: "$uri"');
      _handleDeepLink(uri.toString());
    }, onError: (err) {
      print('⚠️ [main.dart] Ошибка в uriLinkStream: $err');
    });
  }

  void _handleDeepLink(String link) {
    final clean = link.trim();
    if (clean.isEmpty) return;
    print('🔗 [main.dart] _handleDeepLink: "$clean", isAppInitialized=${ControlPanelApp.isAppInitialized}');
    if (!ControlPanelApp.isAppInitialized) {
      print('⏳ [main.dart] Приложение еще не готово (SplashScreen), откладываем ссылку: "$clean"');
      ControlPanelApp.pendingDeepLink = clean;
      return;
    }
    DeepLinkService.handleDeepLinkString(clean);
  }

  bool get _isGuestModeSafe {
    try {
      return tokenStorage.isGuestMode;
    } catch (_) {
      return false;
    }
  }

  ThemeData _buildLightTheme() {
    const primary = Color(0xFF054582);
    const surface = Color(0xFFF8FAFC);
    const onSurface = Color(0xFF1F2937);
    const outline = Color(0xFFE2E8F0);
    const error = Color(0xFF991B1B);
    final cs = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: const Color(0xFF0a7ac2),
      onSecondary: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: Colors.white,
      onSurfaceVariant: const Color(0xFF64748B),
      outline: outline,
      error: error,
      onError: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: cs,
      scaffoldBackgroundColor: surface,
      primaryColor: primary,
      fontFamily: GoogleFonts.inter().fontFamily,
      extensions: const <ThemeExtension<dynamic>>[
        AppColorsExtension.light,
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20))),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24))),
      ),
      dividerTheme: const DividerThemeData(color: outline, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: outline, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return const Color(0xFF94A3B8);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.35);
          }
          return const Color(0xFFD1D5DB);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: primary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: outline, width: 1.5),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: onSurface,
        iconColor: const Color(0xFF64748B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        headlineSmall:
            TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const primary = Color(0xFF0a7ac2);
    const surface = Color(0xFF0B1120);
    const onSurface = Color(0xFFFFFFFF);
    const outline = Color(0xFF2A3A4D);
    const error = Color(0xFF991B1B);
    final cs = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: Colors.white,
      secondary: const Color(0xFF054582),
      onSecondary: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: const Color(0xFF1A2332),
      onSurfaceVariant: const Color(0xFF94A3B8),
      outline: outline,
      error: error,
      onError: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: surface,
      primaryColor: primary,
      fontFamily: GoogleFonts.inter().fontFamily,
      extensions: const <ThemeExtension<dynamic>>[
        AppColorsExtension.dark,
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF021A38),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1A2332),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20))),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF1A2332),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24))),
      ),
      dividerTheme: const DividerThemeData(color: outline, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF151F2E),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: outline, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: outline, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return const Color(0xFF64748B);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.35);
          }
          return const Color(0xFF2A3A4D);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1A2332),
        selectedColor: primary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: outline, width: 1.5),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: onSurface,
        iconColor: const Color(0xFF94A3B8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        headlineSmall:
            TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          navigatorKey: ControlPanelApp.navigatorKey,
          title: 'SAVT Assist',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          initialRoute: '/',
          onGenerateInitialRoutes: (initialRouteName) {
            return [_buildRoute(const SplashScreen())];
          },
          builder: (context, child) {
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
              },
              child: ConnectionNotificationWrapper(
                child: child!,
              ),
            );
          },
          onGenerateRoute: (settings) {
            if (settings.name?.startsWith('/chat/') == true) {
              final uri = Uri.parse(settings.name!);
              final chatIdStr = uri.pathSegments.last;
              final aroundIdStr = uri.queryParameters['around_id'];
              final aroundId =
                  aroundIdStr != null ? int.tryParse(aroundIdStr) : null;
              if (chatIdStr.isNotEmpty) {
                return _buildRoute(
                    ChatScreen(chatId: chatIdStr, aroundId: aroundId));
              }
            }
            if (settings.name?.startsWith('/chat-settings/') == true) {
              final chatIdStr = settings.name!.split('/').last;
              return _buildRoute(ChatSettingsScreen(chatId: chatIdStr));
            }
            if (settings.name == '/chat-settings') {
              return _buildRoute(const ChatSettingsScreen());
            }
            if (settings.name?.startsWith('/shu-detail/') == true) {
              final parts = settings.name!.split('/');
              final shuId = parts[2];
              int initialTab = 0;
              if (parts.length > 3) {
                initialTab = int.tryParse(parts[3]) ?? 0;
              }
              return _buildRoute(
                  ShuDetailScreen(shuId: shuId, initialTab: initialTab));
            }
            if (settings.name?.startsWith('/reclamation-detail/') == true ||
                (settings.name?.startsWith('/reclamations/') == true &&
                    settings.name != '/reclamations')) {
              final idStr = settings.name!.split('/').last;
              final recId = int.tryParse(idStr) ?? 0;
              return _buildRoute(ReclamationDetailScreen(reclamationId: recId));
            }
            if (settings.name?.startsWith('/create-reclamation') == true) {
              final args = settings.arguments as Map<String, dynamic>?;
              return _buildRoute(CreateReclamationScreen(
                initialCabinetId: args?['cabinet_id'] as int?,
                initialCabinetNumber: args?['cabinet_number'] as String?,
              ));
            }
            if (settings.name?.startsWith('/service-request-detail/') == true ||
                settings.name?.startsWith('/request-detail/') == true) {
              final reqId = settings.name!.split('/').last;
              final args = settings.arguments;
              final requestMap = args is Map<String, dynamic>
                  ? args
                  : (args is Map ? Map<String, dynamic>.from(args) : null);
              return _buildRoute(RequestDetailScreen(
                requestId: int.tryParse(reqId) ?? 0,
                request: requestMap,
              ));
            }
            if (settings.name?.startsWith('/service-request-comments/') ==
                true) {
              final reqId = settings.name!.split('/').last;
              return _buildRoute(ServiceRequestDetailScreen(requestId: reqId));
            }
            if (settings.name?.startsWith('/service-request/') == true) {
              final raw = settings.name!.split('/').last;
              final parts = raw.split('?');
              final shuId = parts.first;
              final queryParams =
                  parts.length > 1 ? parts.sublist(1) : <String>[];
              final params = <String, String>{};
              for (final param in queryParams) {
                final kv = param.split('=');
                if (kv.length == 2) params[kv[0]] = kv[1];
              }
              return _buildRoute(ServiceRequestScreen(
                shuId: shuId,
                requestType: params['type'],
              ));
            }
            switch (settings.name) {
              case '/':
                return _buildRoute(const SplashScreen());
              case '/onboarding':
                return _buildRoute(const OnboardingScreen());
              case '/auth':
                return _buildRoute(const AuthPage());
              case '/forgot-password':
                return _buildRoute(const ForgotPasswordScreen());
              case '/register-request':
                return _buildRoute(const RegisterRequestScreen());
              case '/password-reset-request':
                return _buildRoute(const PasswordResetRequestScreen());
              case '/change-password':
                return _buildRoute(const ChangePasswordScreen());
              case '/change-phone':
                return _buildRoute(const ChangePhoneScreen());
              case '/edit-profile':
                return _buildRoute(const EditProfileScreen());
              case '/favorites':
                return _buildRoute(const FavoritesScreen());
              case '/knowledge':
                return _buildRoute(
                    const MainNavigationContainer(initialTab: 1));
              case '/about-us':
                return _buildRoute(
                    const MainNavigationContainer(initialTab: 1));
              case '/chats':
                if (_isGuestModeSafe) {
                  return _buildRoute(
                      const MainNavigationContainer(initialTab: 0));
                }
                return _buildRoute(
                    const MainNavigationContainer(initialTab: 2));
              case '/profile':
                if (_isGuestModeSafe) {
                  return _buildRoute(
                      const MainNavigationContainer(initialTab: 0));
                }
                return _buildRoute(
                    const MainNavigationContainer(initialTab: 3));
              case '/shu-list':
              case '/home':
                if (_isGuestModeSafe) {
                  return _buildRoute(
                      const MainNavigationContainer(initialTab: 0));
                }
                return _buildRoute(
                    const MainNavigationContainer(initialTab: 0));
              case '/notes':
                if (_isGuestModeSafe) {
                  return _buildRoute(
                      const MainNavigationContainer(initialTab: 0));
                }
                return _buildRoute(const NotesScreen());
              case '/search-messages':
                if (_isGuestModeSafe) {
                  return _buildRoute(
                      const MainNavigationContainer(initialTab: 0));
                }
                return _buildRoute(const SearchMessagesScreen());
              case '/all-documents':
                if (_isGuestModeSafe) {
                  return _buildRoute(
                      const MainNavigationContainer(initialTab: 0));
                }
                return _buildRoute(const MyDocumentsScreen());
              case '/notifications':
                if (_isGuestModeSafe) {
                  return _buildRoute(
                      const MainNavigationContainer(initialTab: 0));
                }
                return _buildRoute(const NotificationsScreen());
              case '/operator-panel':
                if (_isGuestModeSafe) {
                  return _buildRoute(
                      const MainNavigationContainer(initialTab: 0));
                }
                return _buildRoute(const OperatorPanelScreen());
              case '/qr-scanner':
                final args = settings.arguments;
                ScannerTarget target = ScannerTarget.project;
                String? code;
                if (args is Map) {
                  if (args['target'] == 'cabinet') {
                    target = ScannerTarget.cabinet;
                  }
                  code = args['code']?.toString();
                } else if (args is String && args == 'cabinet') {
                  target = ScannerTarget.cabinet;
                }
                return _buildRoute(QRScannerScreen(
                  initialTarget: target,
                  initialCode: code,
                ));
              case '/requests-hub':
                if (_isGuestModeSafe) {
                  return _buildRoute(
                      const MainNavigationContainer(initialTab: 0));
                }
                return _buildRoute(const RequestsHubScreen());
              case '/my-requests':
                if (_isGuestModeSafe) {
                  return _buildRoute(
                      const MainNavigationContainer(initialTab: 0));
                }
                return _buildRoute(const RequestsHubScreen(initialTab: 0));
              case '/reclamations':
                if (_isGuestModeSafe) {
                  return _buildRoute(
                      const MainNavigationContainer(initialTab: 0));
                }
                return _buildRoute(const RequestsHubScreen(initialTab: 1));
              default:
                if (!ControlPanelApp.isAppInitialized) {
                  return _buildRoute(const SplashScreen());
                }
                if (settings.name != null) {
                  final uri = Uri.tryParse(settings.name!);
                  if (uri != null) {
                    if (uri.path.startsWith('/add/cabinet/')) {
                      final code = uri.pathSegments.length > 2
                          ? uri.pathSegments[2]
                          : null;
                      return _buildRoute(QRScannerScreen(
                        initialTarget: ScannerTarget.cabinet,
                        initialCode: code,
                      ));
                    } else if (uri.path.startsWith('/add/project/')) {
                      final code = uri.pathSegments.length > 2
                          ? uri.pathSegments[2]
                          : null;
                      return _buildRoute(QRScannerScreen(
                        initialTarget: ScannerTarget.project,
                        initialCode: code,
                      ));
                    }
                  }
                }
                if (_isGuestModeSafe) {
                  return _buildRoute(
                      const MainNavigationContainer(initialTab: 0));
                }
                return _buildRoute(
                    const MainNavigationContainer(initialTab: 1));
            }
          },
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
        );
      },
    );
  }
}
