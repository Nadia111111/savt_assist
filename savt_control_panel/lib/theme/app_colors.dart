import 'package:flutter/material.dart';

/// Цветовая палитра приложения.
/// Используйте через Theme.of(context).colorScheme, а не напрямую.
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
