// lib/models/chat_theme_presets.dart
import 'package:flutter/material.dart';

class ChatThemePreset {
  final String id;
  final String name;
  final String emoji;
  final List<Color> ownBubbleGradient;
  final String ownBubbleHex;
  final Color otherBubbleColor;
  final Color otherBubbleColorLight;
  final String otherBubbleHex;
  final Color backgroundColor;
  final Color lightBackgroundColor;
  final Color accentColor;

  const ChatThemePreset({
    required this.id,
    required this.name,
    required this.emoji,
    required this.ownBubbleGradient,
    required this.ownBubbleHex,
    required this.otherBubbleColor,
    this.otherBubbleColorLight = const Color(0xFFF3F4F6),
    required this.otherBubbleHex,
    required this.backgroundColor,
    required this.lightBackgroundColor,
    required this.accentColor,
  });

  static const List<ChatThemePreset> presets = [
    ChatThemePreset(
      id: 'classic',
      name: 'SAVT Синяя',
      emoji: '🏢',
      ownBubbleGradient: [Color(0xFF054582), Color(0xFF0A7AC2)],
      ownBubbleHex: '#054582',
      otherBubbleColor: Color(0xFF1E293B),
      otherBubbleColorLight: Color(0xFFF1F5F9),
      otherBubbleHex: '#1E293B',
      backgroundColor: Color(0xFF0B1426),
      lightBackgroundColor: Color(0xFFF0F6FC),
      accentColor: Color(0xFF0A7AC2),
    ),
    ChatThemePreset(
      id: 'diamond',
      name: 'Лазурная',
      emoji: '💎',
      ownBubbleGradient: [Color(0xFF0284C7), Color(0xFF38BDF8)],
      ownBubbleHex: '#0284C7',
      otherBubbleColor: Color(0xFF1E293B),
      otherBubbleColorLight: Color(0xFFF1F5F9),
      otherBubbleHex: '#1E293B',
      backgroundColor: Color(0xFF0C1929),
      lightBackgroundColor: Color(0xFFF0F9FF),
      accentColor: Color(0xFF0284C7),
    ),
    ChatThemePreset(
      id: 'spring',
      name: 'Изумрудная',
      emoji: '🌿',
      ownBubbleGradient: [Color(0xFF059669), Color(0xFF34D399)],
      ownBubbleHex: '#059669',
      otherBubbleColor: Color(0xFF1E293B),
      otherBubbleColorLight: Color(0xFFF1F5F9),
      otherBubbleHex: '#1E293B',
      backgroundColor: Color(0xFF0C2417),
      lightBackgroundColor: Color(0xFFF0FDF4),
      accentColor: Color(0xFF10B981),
    ),
    ChatThemePreset(
      id: 'graphite',
      name: 'Графитовая',
      emoji: '🖤',
      ownBubbleGradient: [Color(0xFF334155), Color(0xFF475569)],
      ownBubbleHex: '#334155',
      otherBubbleColor: Color(0xFF1E293B),
      otherBubbleColorLight: Color(0xFFF1F5F9),
      otherBubbleHex: '#1E293B',
      backgroundColor: Color(0xFF0F172A),
      lightBackgroundColor: Color(0xFFF8FAFC),
      accentColor: Color(0xFF64748B),
    ),
    ChatThemePreset(
      id: 'purple',
      name: 'Фиолетовая',
      emoji: '💜',
      ownBubbleGradient: [Color(0xFF7C3AED), Color(0xFFA855F7)],
      ownBubbleHex: '#7C3AED',
      otherBubbleColor: Color(0xFF232328),
      otherBubbleColorLight: Color(0xFFF3F4F6),
      otherBubbleHex: '#232328',
      backgroundColor: Color(0xFF140F20),
      lightBackgroundColor: Color(0xFFFAF5FF),
      accentColor: Color(0xFFA855F7),
    ),
    ChatThemePreset(
      id: 'winter',
      name: 'Бирюзовая',
      emoji: '❄️',
      ownBubbleGradient: [Color(0xFF0891B2), Color(0xFF22D3EE)],
      ownBubbleHex: '#0891B2',
      otherBubbleColor: Color(0xFF232328),
      otherBubbleColorLight: Color(0xFFF3F4F6),
      otherBubbleHex: '#232328',
      backgroundColor: Color(0xFF0A1E26),
      lightBackgroundColor: Color(0xFFECFEFF),
      accentColor: Color(0xFF06B6D4),
    ),
    ChatThemePreset(
      id: 'rose',
      name: 'Малиновая',
      emoji: '🌹',
      ownBubbleGradient: [Color(0xFFE11D48), Color(0xFFFB7185)],
      ownBubbleHex: '#E11D48',
      otherBubbleColor: Color(0xFF232328),
      otherBubbleColorLight: Color(0xFFF3F4F6),
      otherBubbleHex: '#232328',
      backgroundColor: Color(0xFF261016),
      lightBackgroundColor: Color(0xFFFFF1F2),
      accentColor: Color(0xFFF43F5E),
    ),
    ChatThemePreset(
      id: 'amber',
      name: 'Янтарная',
      emoji: '☀️',
      ownBubbleGradient: [Color(0xFFD97706), Color(0xFFFBBF24)],
      ownBubbleHex: '#D97706',
      otherBubbleColor: Color(0xFF232328),
      otherBubbleColorLight: Color(0xFFF3F4F6),
      otherBubbleHex: '#232328',
      backgroundColor: Color(0xFF261B0E),
      lightBackgroundColor: Color(0xFFFFFBEB),
      accentColor: Color(0xFFF59E0B),
    ),
    ChatThemePreset(
      id: 'festive',
      name: 'Зеленая',
      emoji: '🌲',
      ownBubbleGradient: [Color(0xFF15803D), Color(0xFF4ADE80)],
      ownBubbleHex: '#15803D',
      otherBubbleColor: Color(0xFF232328),
      otherBubbleColorLight: Color(0xFFF3F4F6),
      otherBubbleHex: '#232328',
      backgroundColor: Color(0xFF0F2615),
      lightBackgroundColor: Color(0xFFF0FDF4),
      accentColor: Color(0xFF22C55E),
    ),
  ];

  static ChatThemePreset getById(String id) {
    return presets.firstWhere(
      (p) => p.id == id,
      orElse: () => presets[0],
    );
  }
}

class ChatNameColor {
  final String hex;
  final String name;
  final Color color;

  const ChatNameColor({
    required this.hex,
    required this.name,
    required this.color,
  });

  static const List<ChatNameColor> palette = [
    ChatNameColor(hex: '#000000', name: 'Черный', color: Color(0xFF000000)),
    ChatNameColor(hex: '#334155', name: 'Графитовый', color: Color(0xFF334155)),
    ChatNameColor(hex: '#054582', name: 'SAVT Синий', color: Color(0xFF054582)),
    ChatNameColor(hex: '#0284C7', name: 'Лазурный', color: Color(0xFF0284C7)),
    ChatNameColor(hex: '#3B82F6', name: 'Синий', color: Color(0xFF3B82F6)),
    ChatNameColor(hex: '#06B6D4', name: 'Голубой', color: Color(0xFF06B6D4)),
    ChatNameColor(hex: '#14B8A6', name: 'Бирюзовый', color: Color(0xFF14B8A6)),
    ChatNameColor(hex: '#10B981', name: 'Изумрудный', color: Color(0xFF10B981)),
    ChatNameColor(hex: '#84CC16', name: 'Лаймовый', color: Color(0xFF84CC16)),
    ChatNameColor(hex: '#F59E0B', name: 'Янтарный', color: Color(0xFFF59E0B)),
    ChatNameColor(hex: '#F97316', name: 'Оранжевый', color: Color(0xFFF97316)),
    ChatNameColor(hex: '#EF4444', name: 'Красный', color: Color(0xFFEF4444)),
    ChatNameColor(hex: '#F43F5E', name: 'Малиновый', color: Color(0xFFF43F5E)),
    ChatNameColor(hex: '#EC4899', name: 'Розовый', color: Color(0xFFEC4899)),
    ChatNameColor(hex: '#A855F7', name: 'Фиолетовый', color: Color(0xFFA855F7)),
    ChatNameColor(hex: '#6366F1', name: 'Индиго', color: Color(0xFF6366F1)),
    ChatNameColor(hex: '#8B5CF6', name: 'Аметистовый', color: Color(0xFF8B5CF6)),
  ];

  static Color parse(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF054582);
    }
  }
}
