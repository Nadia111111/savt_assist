import 'package:flutter/material.dart';

/// Цветовая палитра приложения.
/// Используйте через Theme.of(context).colorScheme или Theme.of(context).extension<AppColorsExtension>(),
/// а не напрямую.
class AppColors {
  // Основной синий
  static const primary = Color(0xFF054582);
  static const primaryLight = Color(0xFF0a7ac2);

  // Светлая тема
  static const lightBackground = Color(0xFFF8FAFC);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF1F2937);
  static const lightTextSecondary = Color(0xFF64748B);
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightInputBg = Color(0xFFF1F5F9);

  // Тёмная тема
  static const darkBackground = Color(0xFF0B1120);
  static const darkCard = Color(0xFF1A2332);
  static const darkText = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF94A3B8);
  static const darkBorder = Color(0xFF2A3A4D);
  static const darkInputBg = Color(0xFF151F2E);
  static const darkHeader = Color(0xFF021A38);

  // Общие
  static const error = Color(0xFF991B1B);
  static const success = Color(0xFF059669);
  static const warning = Color(0xFFF59E0B);
}

@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color primary;
  final Color primaryLight;
  final Color success;
  final Color warning;
  final Color error;

  const AppColorsExtension({
    required this.primary,
    required this.primaryLight,
    required this.success,
    required this.warning,
    required this.error,
  });

  static const light = AppColorsExtension(
    primary: AppColors.primary,
    primaryLight: AppColors.primaryLight,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
  );

  static const dark = AppColorsExtension(
    primary: AppColors.primaryLight,
    primaryLight: AppColors.primary,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
  );

  @override
  AppColorsExtension copyWith({
    Color? primary,
    Color? primaryLight,
    Color? success,
    Color? warning,
    Color? error,
  }) {
    return AppColorsExtension(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) {
      return this;
    }
    return AppColorsExtension(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }

  static AppColorsExtension of(BuildContext context) {
    return Theme.of(context).extension<AppColorsExtension>() ?? light;
  }
}
