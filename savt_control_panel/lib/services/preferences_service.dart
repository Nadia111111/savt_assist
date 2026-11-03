// lib/services/preferences_service.dart
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static late SharedPreferences _prefs;
  static final ValueNotifier<int> fabPositionNotifier = ValueNotifier<int>(0);
  static String? lastUpdatedFabKey;

  // Chat Settings Notifiers
  static final ValueNotifier<double> bubbleRadiusNotifier = ValueNotifier<double>(17.0);
  static final ValueNotifier<double> fontSizeNotifier = ValueNotifier<double>(15.0);
  static final ValueNotifier<String> chatListModeNotifier = ValueNotifier<String>('two_line');
  static final ValueNotifier<String> nameColorNotifier = ValueNotifier<String>('#10B981');
  static final ValueNotifier<String> chatThemeNotifier = ValueNotifier<String>('purple');
  static final ValueNotifier<String> wallpaperUrlNotifier = ValueNotifier<String>('');

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    bubbleRadiusNotifier.value = _prefs.getDouble('chat_bubble_radius') ?? 17.0;
    fontSizeNotifier.value = _prefs.getDouble('chat_font_size') ?? 15.0;
    chatListModeNotifier.value = _prefs.getString('chat_list_mode') ?? 'two_line';
    nameColorNotifier.value = _prefs.getString('chat_name_color') ?? '#10B981';
    chatThemeNotifier.value = _prefs.getString('chat_theme_preset') ?? 'purple';
    wallpaperUrlNotifier.value = _prefs.getString('chat_wallpaper_url') ?? '';
  }

  static SharedPreferences get prefs => _prefs;

  // Knowledge Screen State
  static int getKnowledgeTab() => _prefs.getInt('knowledge_tab_index') ?? 0;
  static Future<void> saveKnowledgeTab(int index) => _prefs.setInt('knowledge_tab_index', index);

  static String getKnowledgeSortBy() => _prefs.getString('kb_sort_by') ?? 'created_at';
  static Future<void> saveKnowledgeSortBy(String value) => _prefs.setString('kb_sort_by', value);

  static String getKnowledgeSortOrder() => _prefs.getString('kb_sort_order') ?? 'desc';
  static Future<void> saveKnowledgeSortOrder(String value) => _prefs.setString('kb_sort_order', value);

  static List<int> getKnowledgeSelectedTags() {
    final list = _prefs.getStringList('kb_selected_tags') ?? [];
    return list.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0).toList();
  }
  static Future<void> saveKnowledgeSelectedTags(List<int> tags) {
    return _prefs.setStringList('kb_selected_tags', tags.map((e) => e.toString()).toList());
  }

  // Last opened chat ID
  static int? getLastChatId() {
    final val = _prefs.getInt('last_chat_id');
    return val == 0 ? null : val;
  }
  static Future<void> saveLastChatId(int? chatId) async {
    if (chatId == null) {
      await _prefs.remove('last_chat_id');
    } else {
      await _prefs.setInt('last_chat_id', chatId);
    }
  }

  // Theme Choice
  static bool? getThemeChoice() => _prefs.containsKey('theme_choice') ? _prefs.getBool('theme_choice') : null;
  static Future<void> saveThemeChoice(bool isDark) => _prefs.setBool('theme_choice', isDark);

  static String? getThemeModeString() => _prefs.getString('theme_mode');
  static Future<void> saveThemeModeString(String mode) => _prefs.setString('theme_mode', mode);

  // Floating Action Button normalized positions (0.0 to 1.0)
  static Offset? getFabNormalizedPosition(String key) {
    final x = _prefs.getDouble('${key}_norm_x');
    final y = _prefs.getDouble('${key}_norm_y');
    if (x != null && y != null) {
      return Offset(x, y);
    }
    return null;
  }

  static Future<void> saveFabNormalizedPosition(String key, double normX, double normY) async {
    await _prefs.setDouble('${key}_norm_x', normX);
    await _prefs.setDouble('${key}_norm_y', normY);
    lastUpdatedFabKey = key;
    fabPositionNotifier.value++;
  }

  // Bubble Radius
  static double getBubbleRadius() => _prefs.getDouble('chat_bubble_radius') ?? 17.0;
  static Future<void> saveBubbleRadius(double radius) async {
    await _prefs.setDouble('chat_bubble_radius', radius);
    bubbleRadiusNotifier.value = radius;
  }

  // Font Size
  static double getFontSize() => _prefs.getDouble('chat_font_size') ?? 15.0;
  static Future<void> saveFontSize(double size) async {
    await _prefs.setDouble('chat_font_size', size);
    fontSizeNotifier.value = size;
  }

  // Chat List Mode ('two_line' | 'three_line')
  static String getChatListMode() => _prefs.getString('chat_list_mode') ?? 'two_line';
  static Future<void> saveChatListMode(String mode) async {
    await _prefs.setString('chat_list_mode', mode);
    chatListModeNotifier.value = mode;
  }

  // Chat Name Color ('#3B82F6' - vibrant blue default)
  static String getNameColor() => _prefs.getString('chat_name_color') ?? '#3B82F6';
  static Future<void> saveNameColor(String colorHex) async {
    await _prefs.setString('chat_name_color', colorHex);
    nameColorNotifier.value = colorHex;
  }

  // Chat Theme Preset ('classic' - SAVT Синяя default)
  static String getChatThemePreset() => _prefs.getString('chat_theme_preset') ?? 'classic';
  static Future<void> saveChatThemePreset(String preset) async {
    await _prefs.setString('chat_theme_preset', preset);
    chatThemeNotifier.value = preset;
  }

  // Chat Wallpaper URL
  static String getWallpaperUrl() => _prefs.getString('chat_wallpaper_url') ?? '';
  static Future<void> saveWallpaperUrl(String url) async {
    await _prefs.setString('chat_wallpaper_url', url);
    wallpaperUrlNotifier.value = url;
  }
}
