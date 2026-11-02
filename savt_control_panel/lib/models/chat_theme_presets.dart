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
      id: 'purple',
      name: 'Фиолетовая',
      emoji: '💜',
      ownBubbleGradient: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
      ownBubbleHex: '#8B5CF6',
      otherBubbleColor: Color(0xFF232328),
      otherBubbleColorLight: Color(0xFFF3F4F6),
      otherBubbleHex: '#232328',
      backgroundColor: Color(0xFF140F20),
      lightBackgroundColor: Color(0xFFFAF5FF),
      accentColor: Color(0xFFA855F7),
    ),
    ChatThemePreset(
      id: 'classic',
      name: 'Классическая',
      emoji: '🏡',
      ownBubbleGradient: [Color(0xFF0284C7), Color(0xFF38BDF8)],
      ownBubbleHex: '#0284C7',
      otherBubbleColor: Color(0xFF232328),
      otherBubbleColorLight: Color(0xFFF3F4F6),
      otherBubbleHex: '#232328',
      backgroundColor: Color(0xFF0C1929),
      lightBackgroundColor: Color(0xFFF0F9FF),
      accentColor: Color(0xFF0284C7),
    ),
    ChatThemePreset(
      id: 'spring',
      name: 'Весна',
      emoji: '🐥',
      ownBubbleGradient: [Color(0xFF059669), Color(0xFF34D399)],
      ownBubbleHex: '#059669',
      otherBubbleColor: Color(0xFF232328),
      otherBubbleColorLight: Color(0xFFF3F4F6),
      otherBubbleHex: '#232328',
      backgroundColor: Color(0xFF0C2417),
      lightBackgroundColor: Color(0xFFF0FDF4),
      accentColor: Color(0xFF10B981),
    ),
    ChatThemePreset(
      id: 'winter',
      name: 'Зима',
      emoji: '⛄',
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
      id: 'diamond',
      name: 'Алмаз',
      emoji: '💎',
      ownBubbleGradient: [Color(0xFF2563EB), Color(0xFF60A5FA)],
      ownBubbleHex: '#2563EB',
      otherBubbleColor: Color(0xFF232328),
      otherBubbleColorLight: Color(0xFFF3F4F6),
      otherBubbleHex: '#232328',
      backgroundColor: Color(0xFF0E172E),
      lightBackgroundColor: Color(0xFFEFF6FF),
      accentColor: Color(0xFF3B82F6),
    ),
    ChatThemePreset(
      id: 'rose',
      name: 'Тюльпан',
      emoji: '🌷',
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
      name: 'Янтарь',
      emoji: '👨‍🎓',
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
      name: 'Праздничная',
      emoji: '🎄',
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
    ChatNameColor(hex: '#10B981', name: 'Изумрудный', color: Color(0xFF10B981)),
    ChatNameColor(hex: '#06B6D4', name: 'Голубой', color: Color(0xFF06B6D4)),
    ChatNameColor(hex: '#A855F7', name: 'Фиолетовый', color: Color(0xFFA855F7)),
    ChatNameColor(hex: '#EC4899', name: 'Розовый', color: Color(0xFFEC4899)),
    ChatNameColor(hex: '#F59E0B', name: 'Оранжевый', color: Color(0xFFF59E0B)),
    ChatNameColor(hex: '#3B82F6', name: 'Синий', color: Color(0xFF3B82F6)),
    ChatNameColor(hex: '#EF4444', name: 'Красный', color: Color(0xFFEF4444)),
  ];

  static Color parse(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }
}
