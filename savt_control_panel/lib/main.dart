// lib/main.dart (замените полностью)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth/auth_page.dart';
import 'screens/knowledge_screen.dart';
import 'screens/chats_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/shu_detail_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/photo_upload_screen.dart';
import 'screens/service_request_screen.dart';
import 'screens/shu_list_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/search_messages_screen.dart';
import 'screens/operator_panel_screen.dart';
import 'screens/my_requests_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/change_password_screen.dart';
import 'services/offline_service.dart';
import 'services/app_theme.dart';
import 'services/network_service.dart';

void main() {
  OfflineService().start();
  // FCM token mock
  print('FCM token получен (mock)');
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
    opaque: false,
  );
}

class ControlPanelApp extends StatelessWidget {
  const ControlPanelApp({super.key});

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
      surfaceContainerHighest: Colors.white, // карточки
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
      dividerTheme: DividerThemeData(color: outline, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
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
            return primary.withOpacity(0.35);
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
      surfaceContainerHighest: const Color(0xFF1A2332), // карточки
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
      dividerTheme: DividerThemeData(color: outline, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF151F2E),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
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
            return primary.withOpacity(0.35);
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'SAVT Assist',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          initialRoute: '/auth',
          // Глобальный баннер офлайн-режима
          builder: (context, child) {
            return ValueListenableBuilder<bool>(
              valueListenable: NetworkService.isOnlineNotifier,
              builder: (context, isOnline, child) {
                return Column(
                  children: [
                    if (!isOnline)
                      Container(
                        width: double.infinity,
                        color: Colors.orange.shade100,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: const Text(
                          'Нет подключения к интернету',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    Expanded(child: child!),
                  ],
                );
              },
              child: child,
            );
          },
          onGenerateRoute: (settings) {
            if (settings.name?.startsWith('/chat/') == true) {
              final chatId = settings.name!.split('/').last;
              return _buildRoute(ChatScreen(chatId: chatId));
            }
            if (settings.name?.startsWith('/shu-detail/') == true) {
              final shuId = settings.name!.split('/').last;
              return _buildRoute(ShuDetailScreen(shuId: shuId));
            }
            if (settings.name?.startsWith('/service-request/') == true) {
              final shuId = settings.name!.split('/').last;
              return _buildRoute(ServiceRequestScreen(shuId: shuId));
            }

            switch (settings.name) {
              case '/auth':
                return _buildRoute(const AuthPage());
              case '/forgot-password':
                return _buildRoute(const ForgotPasswordScreen());
              case '/change-password':
                return _buildRoute(const ChangePasswordScreen());
              case '/favorites':
                return _buildRoute(const FavoritesScreen());
              case '/knowledge':
                return _buildRoute(const KnowledgeScreen());
              case '/chats':
                return _buildRoute(const ChatsScreen());
              case '/profile':
                return _buildRoute(const ProfileScreen());
              case '/qr-scanner':
                return _buildRoute(const QRScannerScreen());
              case '/photo-upload':
                return _buildRoute(const PhotoUploadScreen());
              case '/shu-list':
                return _buildRoute(const ShuListScreen());
              case '/notes':
                return _buildRoute(const NotesScreen());
              case '/search-messages':
                return _buildRoute(const SearchMessagesScreen());
              case '/operator-panel':
                return _buildRoute(const OperatorPanelScreen());
              case '/my-requests':
                return _buildRoute(const MyRequestsScreen());
              default:
                return _buildRoute(const KnowledgeScreen());
            }
          },
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
        );
      },
    );
  }
}
