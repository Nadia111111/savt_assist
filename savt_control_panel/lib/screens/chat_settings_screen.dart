// lib/screens/chat_settings_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/telegram_doodle_pattern.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/auth_image.dart';
import '../models/chat_theme_presets.dart';
import '../services/app_theme.dart';
import '../services/preferences_service.dart';
import '../services/network_service.dart';
import '../services/auth_service.dart';
import '../services/upload_service.dart';
import '../services/offline_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../main.dart';

class ChatSettingsScreen extends StatefulWidget {
  final String? chatId; // If null, global settings for all chats

  const ChatSettingsScreen({super.key, this.chatId});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  bool _isLoading = false;
  bool _isSaving = false;
  Timer? _debounceTimer;

  // Settings state
  String _activePresetId = 'classic';
  double _bubbleRadius = 17.0;
  double _fontSize = 15.0;
  String _chatListMode = 'two_line';
  String _nameColorHex = '#10B981';
  String _userName = 'Пользователь';
  String _wallpaperUrl = '';

  String? _customOwnColor;
  String? _customOtherColor;
  String? _customBotColor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppNavState.instance.pushConfig(
          id: this,
          showBottomBar: true,
          currentIndex: 2,
        );
      }
    });
    _loadAllSettings();
  }

  @override
  void dispose() {
    AppNavState.instance.removeConfig(this);
    _debounceTimer?.cancel();
    super.dispose();
  }

  bool get _isPerChat =>
      widget.chatId != null &&
      widget.chatId!.isNotEmpty &&
      widget.chatId != 'null';

  String get _cacheKey {
    if (_isPerChat) {
      return 'chat_settings_${widget.chatId}';
    }
    return 'chat_settings_global';
  }

  ChatThemePreset get _activePreset => ChatThemePreset.getById(_activePresetId);

  Future<void> _loadAllSettings() async {
    setState(() => _isLoading = true);

    // 1. Fetch user surname/name for the badge & preview
    try {
      final me = await authService.getMe();
      final lName = me['last_name']?.toString()?.trim();
      final fullName = me['full_name']?.toString()?.trim();
      final fName = me['first_name']?.toString()?.trim();

      if (lName != null && lName.isNotEmpty) {
        _userName = lName;
      } else if (fullName != null && fullName.isNotEmpty) {
        _userName = fullName.split(' ').first;
      } else if (fName != null && fName.isNotEmpty) {
        _userName = fName;
      }
      if (mounted) setState(() {});
    } catch (_) {}

    // 2. Load from SharedPreferences
    int? resolvedSupId;
    try {
      final prefs = await SharedPreferences.getInstance();

      if (widget.chatId == 'support') {
        try {
          resolvedSupId = await chatService.getSupportChatId();
        } catch (_) {}
      }

      final hasCustomDirect = prefs.getBool('chat_has_custom_${widget.chatId}') ?? false;
      final hasCustomSup = resolvedSupId != null && (prefs.getBool('chat_has_custom_$resolvedSupId') ?? false);
      final hasCustom = _isPerChat ? (hasCustomDirect || hasCustomSup) : false;

      if (_isPerChat && hasCustom) {
        String? chatCached = prefs.getString(_cacheKey);
        if (chatCached == null && resolvedSupId != null) {
          chatCached = prefs.getString('chat_settings_$resolvedSupId');
        }
        if (chatCached != null && chatCached.isNotEmpty) {
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(jsonDecode(chatCached));
          _applySettingsMap(data);
        }
      } else {
        // Global settings or initial values for uncustomized chat
        final globalCached = prefs.getString('chat_settings_global');
        if (globalCached != null && globalCached.isNotEmpty) {
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(jsonDecode(globalCached));
          _applySettingsMap(data);
        } else {
          _bubbleRadius = PreferencesService.getBubbleRadius();
          _fontSize = PreferencesService.getFontSize();
          _chatListMode = PreferencesService.getChatListMode();
          _nameColorHex = PreferencesService.getNameColor();
          _activePresetId = PreferencesService.getChatThemePreset();
          _wallpaperUrl = PreferencesService.getWallpaperUrl();
        }
      }
    } catch (e) {
      debugPrint('Error loading cached chat settings: $e');
    }

    // 3. Fetch from backend if online
    if (NetworkService.isOnline) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final hasCustomDirect = prefs.getBool('chat_has_custom_${widget.chatId}') ?? false;
        final hasCustomSup = resolvedSupId != null && (prefs.getBool('chat_has_custom_$resolvedSupId') ?? false);
        final hasCustom = _isPerChat ? (hasCustomDirect || hasCustomSup) : false;

        Map<String, dynamic> settings = {};
        if (_isPerChat) {
          if (hasCustom) {
            final chatIdInt = int.tryParse(widget.chatId!) ?? resolvedSupId;
            if (chatIdInt != null && chatIdInt > 0) {
              settings = await chatService.getChatSettings(chatIdInt);
            }
          }
        } else {
          settings = await chatService.getGlobalSettings();
        }

        if (mounted && settings.isNotEmpty) {
          setState(() {
            _applySettingsMap(settings);
          });
        }
      } catch (e) {
        debugPrint('Error fetching chat settings from server: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applySettingsMap(Map<String, dynamic> data) {
    if (data['theme_preset'] != null) {
      _activePresetId = data['theme_preset'].toString();
    }
    if (data['bubble_radius'] != null) {
      _bubbleRadius =
          (double.tryParse(data['bubble_radius'].toString()) ?? 17.0)
              .clamp(0.0, 24.0);
    }
    if (data['font_size'] != null) {
      _fontSize =
          (double.tryParse(data['font_size'].toString()) ?? 15.0).clamp(11.0, 24.0);
    }
    if (data['chat_list_mode'] != null) {
      _chatListMode = data['chat_list_mode'].toString();
    }
    if (data['name_color'] != null) {
      _nameColorHex = data['name_color'].toString();
    } else if (data['nick_color'] != null) {
      _nameColorHex = data['nick_color'].toString();
    }
    if (data['wallpaper_url'] != null) {
      _wallpaperUrl = data['wallpaper_url'].toString();
    }
    if (data['own_bubble_color'] != null) {
      _customOwnColor = data['own_bubble_color'].toString();
    }
    if (data['other_bubble_color'] != null) {
      _customOtherColor = data['other_bubble_color'].toString();
    }
    if (data['bot_bubble_color'] != null) {
      _customBotColor = data['bot_bubble_color'].toString();
    }
  }

  void _onSettingChanged({bool immediate = false}) {
    if (!_isPerChat) {
      PreferencesService.saveBubbleRadius(_bubbleRadius);
      PreferencesService.saveFontSize(_fontSize);
      PreferencesService.saveChatListMode(_chatListMode);
      PreferencesService.saveNameColor(_nameColorHex);
      PreferencesService.saveChatThemePreset(_activePresetId);
    }

    _debounceTimer?.cancel();
    if (immediate) {
      _saveSettings(manual: false);
    } else {
      _debounceTimer =
          Timer(const Duration(milliseconds: 500), () => _saveSettings(manual: false));
    }
  }

  Future<void> _saveSettings({bool manual = false}) async {
    if (manual) {
      setState(() => _isSaving = true);
    }

    final Map<String, dynamic> localData = {
      'theme_preset': _activePresetId,
      'bubble_radius': _bubbleRadius.toInt(),
      'font_size': _fontSize.toInt(),
      'chat_list_mode': _chatListMode,
      'name_color': _nameColorHex,
      'wallpaper_url': _wallpaperUrl,
      'own_bubble_color': _customOwnColor ?? _activePreset.ownBubbleHex,
      'other_bubble_color': _customOtherColor ?? _activePreset.otherBubbleHex,
      'bot_bubble_color': _customBotColor ?? '#2A2938',
    };

    final Map<String, dynamic> serverPayload = {
      'nick_color': _nameColorHex,
      'font_size': _fontSize.toInt(),
      'wallpaper_url': _wallpaperUrl.isNotEmpty &&
              !_wallpaperUrl.startsWith('data:') &&
              !_wallpaperUrl.startsWith('file:') &&
              !_wallpaperUrl.contains(':\\')
          ? _wallpaperUrl
          : null,
      'own_bubble_color': _customOwnColor ?? _activePreset.ownBubbleHex,
      'other_bubble_color': _customOtherColor ?? _activePreset.otherBubbleHex,
      'bot_bubble_color': _customBotColor ?? '#2A2938',
    };

    try {
      final prefs = await SharedPreferences.getInstance();

      if (_isPerChat) {
        // Save ONLY for this chat ID
        await prefs.setString(_cacheKey, jsonEncode(localData));
        await prefs.setBool('chat_has_custom_${widget.chatId}', true);

        final numId = int.tryParse(widget.chatId!);
        if (numId != null) {
          await prefs.setString('chat_settings_$numId', jsonEncode(localData));
          await prefs.setBool('chat_has_custom_$numId', true);
        }

        int? chatIdInt = numId;
        if (chatIdInt == null && widget.chatId == 'support') {
          try {
            final supId = await chatService.getSupportChatId();
            if (supId > 0) {
              chatIdInt = supId;
              await prefs.setString('chat_settings_$supId', jsonEncode(localData));
              await prefs.setBool('chat_has_custom_$supId', true);
            }
          } catch (_) {}
        }

        final targetChatId = chatIdInt;
        if (NetworkService.isOnline && targetChatId != null && targetChatId > 0) {
          try {
            await chatService.updateChatSettings(targetChatId, serverPayload);
            if (_wallpaperUrl.isNotEmpty &&
                !_wallpaperUrl.startsWith('data:') &&
                !_wallpaperUrl.startsWith('file:') &&
                !_wallpaperUrl.contains(':\\')) {
              await chatService.updateChatWallpaper(targetChatId, _wallpaperUrl);
            }
          } catch (e) {
            debugPrint('Server per-chat settings sync failed (ignored): $e');
          }
        }
      } else {
        // Global settings: Save as global base AND reset all individual chats
        await prefs.setString('chat_settings_global', jsonEncode(localData));
        PreferencesService.saveBubbleRadius(_bubbleRadius);
        PreferencesService.saveFontSize(_fontSize);
        PreferencesService.saveChatListMode(_chatListMode);
        PreferencesService.saveNameColor(_nameColorHex);
        PreferencesService.saveChatThemePreset(_activePresetId);
        PreferencesService.saveWallpaperUrl(_wallpaperUrl);

        // Clear all individual chat override caches so they follow the new global base
        final chatIdsToReset = <int>{};
        final allKeys = prefs.getKeys().toList();
        for (final k in allKeys) {
          if (k.startsWith('chat_settings_') && k != 'chat_settings_global') {
            final id = int.tryParse(k.replaceFirst('chat_settings_', ''));
            if (id != null) chatIdsToReset.add(id);
            await prefs.remove(k);
          } else if (k.startsWith('chat_has_custom_')) {
            final id = int.tryParse(k.replaceFirst('chat_has_custom_', ''));
            if (id != null) chatIdsToReset.add(id);
            await prefs.remove(k);
          }
        }

        try {
          final cached = await OfflineService().getCache('user_chats');
          if (cached is List) {
            for (final c in cached) {
              if (c is Map && c['id'] != null) {
                final id = int.tryParse(c['id'].toString());
                if (id != null) chatIdsToReset.add(id);
              }
            }
          }
        } catch (_) {}

        if (NetworkService.isOnline) {
          try {
            await chatService.updateGlobalSettings(serverPayload);
          } catch (e) {
            debugPrint('Server global settings sync failed (ignored): $e');
          }

          for (final cid in chatIdsToReset) {
            try {
              await chatService.resetChatSettings(cid);
            } catch (e) {
              debugPrint('Server resetChatSettings failed for $cid (ignored): $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error caching chat settings: $e');
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (manual) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isPerChat
                        ? 'Настройки для этого чата успешно сохранены!'
                        : 'Настройки сохранены и применены ко всем чатам!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF054582),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();

    if (_isPerChat) {
      try {
        int chatIdInt = int.tryParse(widget.chatId!) ?? 0;
        if (chatIdInt == 0 && widget.chatId == 'support') {
          try {
            chatIdInt = await chatService.getSupportChatId();
          } catch (_) {}
        }
        if (chatIdInt != 0 && NetworkService.isOnline) {
          await chatService.resetChatSettings(chatIdInt);
        }
        await prefs.remove(_cacheKey);
        await prefs.remove('chat_has_custom_${widget.chatId}');
        if (chatIdInt != 0) {
          await prefs.remove('chat_settings_$chatIdInt');
          await prefs.remove('chat_has_custom_$chatIdInt');
        }
      } catch (_) {}

      await _loadAllSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Настройки чата сброшены к общим'),
            backgroundColor: Color(0xFF054582),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      setState(() {
        _activePresetId = 'classic';
        _bubbleRadius = 17.0;
        _fontSize = 15.0;
        _chatListMode = 'two_line';
        _nameColorHex = '#10B981';
        _wallpaperUrl = '';
        _customOwnColor = null;
        _customOtherColor = null;
        _customBotColor = null;
      });

      await _saveSettings(manual: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Все настройки сброшены по умолчанию для всех чатов'),
            backgroundColor: Color(0xFF054582),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickWallpaperFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final bytes = await image.readAsBytes();
      String url = '';

      // On mobile, save a local copy so it works offline and renders immediately
      if (!kIsWeb) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final localFileName =
              'wallpaper_${widget.chatId ?? "global"}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final localFile = File('${appDir.path}/$localFileName');
          await localFile.writeAsBytes(bytes);
          url = localFile.path;
        } catch (e) {
          debugPrint('Local wallpaper copy failed: $e');
        }
      }

      // Try uploading to server to get permanent server URL
      try {
        String serverUrl = '';
        if (kIsWeb) {
          serverUrl = await uploadService.uploadAttachmentBytes(bytes, image.name);
        } else {
          serverUrl = await uploadService.uploadAttachment(image.path);
        }
        if (serverUrl.isNotEmpty) {
          url = serverUrl;
        }
      } catch (uploadError) {
        debugPrint('Upload wallpaper to server failed: $uploadError');
        // If on Web and upload failed, fallback to base64 data URI so user choice is preserved
        if (kIsWeb && url.isEmpty) {
          url = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        }
      }

      if (url.isNotEmpty) {
        AuthImage.cacheBytes(url, bytes);
        setState(() {
          _wallpaperUrl = url;
        });
        _onSettingChanged(immediate: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Обои успешно установлены'),
              backgroundColor: Color(0xFF054582),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception('Не удалось сохранить изображение');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки фото: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // SAVT Corporate Brand Palette
    final Color bgColor = isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
    final Color cardBg = isDark ? const Color(0xFF1A2332) : Colors.white;
    final Color cardInnerBg = isDark ? const Color(0xFF141D2B) : const Color(0xFFF1F5F9);
    final Color dividerColor = isDark ? const Color(0xFF2A3A4D) : const Color(0xFFE2E8F0);
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Brand Blue colors (replacing purple!)
    final Color brandPrimary = isDark ? const Color(0xFF0A7AC2) : const Color(0xFF054582);
    final Color brandAccent = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    final Color buttonBg = isDark ? const Color(0xFF0A7AC2) : const Color(0xFF054582);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isPerChat ? 'Настройки этого чата' : 'Настройки всех чатов',
              style: TextStyle(
                color: textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_isPerChat)
              Text(
                'Индивидуальные параметры чата',
                style: TextStyle(
                  color: brandAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textPrimary),
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: dividerColor),
            ),
            onSelected: (val) {
              if (val == 'reset') {
                _resetToDefaults();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt, color: textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _isPerChat
                          ? 'Сбросить к общим настройкам'
                          : 'Сбросить все настройки',
                      style: TextStyle(color: textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _saveSettings(manual: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonBg,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _isPerChat
                                  ? 'Сохранить для этого чата'
                                  : 'Сохранить для всех чатов',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: brandPrimary),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. LIVE CHAT PREVIEW AT TOP ("SAVT помощник")
                      _buildLivePreviewCard(isDark),

                      const SizedBox(height: 12),

                      // 2. WALLPAPER & NAME COLOR CARD
                      _buildWallpaperAndNameCard(
                        isDark: isDark,
                        cardBg: cardBg,
                        dividerColor: dividerColor,
                        textPrimary: textPrimary,
                        accentColor: brandAccent,
                      ),

                      const SizedBox(height: 12),

                      // 3. COLOR THEME PRESETS CAROUSEL CARD (No stickers!)
                      _buildThemePresetsCard(
                        isDark: isDark,
                        cardBg: cardBg,
                        dividerColor: dividerColor,
                        textPrimary: textPrimary,
                        accentColor: brandAccent,
                        selectionBorderColor: brandAccent,
                      ),

                      const SizedBox(height: 12),

                      // 4. FONT SIZE SLIDER CARD (NEW!)
                      _buildFontSizeSliderCard(
                        isDark: isDark,
                        cardBg: cardBg,
                        textPrimary: textPrimary,
                        accentColor: brandAccent,
                      ),

                      const SizedBox(height: 12),

                      // 5. BUBBLE CORNER RADIUS SLIDER CARD
                      _buildBubbleCornerRadiusCard(
                        isDark: isDark,
                        cardBg: cardBg,
                        textPrimary: textPrimary,
                        accentColor: brandAccent,
                      ),

                      const SizedBox(height: 12),

                      // 6. CHAT LIST MODE CARD (Two-line / Three-line)
                      _buildChatListModeCard(
                        isDark: isDark,
                        cardBg: cardBg,
                        cardInnerBg: cardInnerBg,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        accentColor: brandAccent,
                        selectionBorderColor: brandAccent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ---------------------------------------------------------
  // 1. LIVE CHAT PREVIEW AREA ("SAVT помощник")
  // ---------------------------------------------------------
  Widget _buildLivePreviewCard(bool isDark) {
    final preset = _activePreset;
    final nameColor = ChatNameColor.parse(_nameColorHex);
    final isCustomImage = _wallpaperUrl.isNotEmpty &&
        !_wallpaperUrl.startsWith('color:#') &&
        !_wallpaperUrl.startsWith('pattern:');
    final isColorOnly = _wallpaperUrl.startsWith('color:#');

    Color bgColor = isDark ? preset.backgroundColor : preset.lightBackgroundColor;
    if (isColorOnly) {
      bgColor = ChatNameColor.parse(_wallpaperUrl.replaceFirst('color:', ''));
    }

    final double effectiveRadius = _bubbleRadius;
    final double smallRadius = (effectiveRadius * 0.25).clamp(2.0, 6.0);

    return Container(
      height: 165,
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
      ),
      child: Stack(
        children: [
          // Background: image or vector doodle pattern (no hearts!)
          Positioned.fill(
            child: _buildWallpaperPreview(
              wallpaperUrl: _wallpaperUrl,
              isDark: isDark,
              bgColor: bgColor,
            ),
          ),

          // Outgoing message bubble aligned to the top-right
          Positioned(
            top: 20,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              constraints: const BoxConstraints(maxWidth: 270),
              decoration: BoxDecoration(
                gradient: _customOwnColor == null
                    ? LinearGradient(
                        colors: preset.ownBubbleGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: _customOwnColor != null
                    ? ChatNameColor.parse(_customOwnColor!)
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(effectiveRadius),
                  topRight: Radius.circular(effectiveRadius),
                  bottomLeft: Radius.circular(effectiveRadius),
                  bottomRight: Radius.circular(smallRadius),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // User's Surname / Name header with chosen name color
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2.5),
                    child: Text(
                      _userName,
                      style: TextStyle(
                        color: nameColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          'SAVT помощник',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: _fontSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 1.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '09:57',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(
                              Icons.done_all,
                              size: 15,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWallpaperPreview({
    required String wallpaperUrl,
    required bool isDark,
    required Color bgColor,
  }) {
    if (wallpaperUrl.isEmpty) {
      return TelegramDoodlePattern(
        backgroundColor: bgColor,
        doodleColor: isDark ? Colors.white : const Color(0xFF334155),
        opacity: isDark ? 0.14 : 0.10,
      );
    }

    if (wallpaperUrl.startsWith('color:#')) {
      final color = ChatNameColor.parse(wallpaperUrl.replaceFirst('color:', ''));
      return Container(color: color);
    }

    if (wallpaperUrl.startsWith('data:image')) {
      try {
        final base64Str = wallpaperUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }

    if (!kIsWeb &&
        (wallpaperUrl.startsWith('/') ||
            wallpaperUrl.startsWith('file://') ||
            wallpaperUrl.contains(':\\'))) {
      try {
        final clean = wallpaperUrl.replaceFirst('file://', '');
        final file = File(clean);
        if (file.existsSync()) {
          return Image.file(file, fit: BoxFit.cover);
        }
      } catch (_) {}
    }

    final cached = AuthImage.getCachedBytes(wallpaperUrl);
    if (cached != null) {
      return Image.memory(cached, fit: BoxFit.cover);
    }

    return AuthImage(
      url: wallpaperUrl,
      fit: BoxFit.cover,
    );
  }

  // ---------------------------------------------------------
  // 2. WALLPAPER & NAME COLOR CARD
  // ---------------------------------------------------------
  Widget _buildWallpaperAndNameCard({
    required bool isDark,
    required Color cardBg,
    required Color dividerColor,
    required Color textPrimary,
    required Color accentColor,
  }) {
    final nameColor = ChatNameColor.parse(_nameColorHex);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: Icon(
                Icons.wallpaper_rounded,
                color: accentColor,
                size: 24,
              ),
              title: Text(
                'Изменить обои',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white38 : Colors.black38,
                size: 20,
              ),
              onTap: () => _showWallpaperBottomSheet(context, isDark, cardBg, textPrimary, accentColor, dividerColor),
            ),
            Divider(height: 1, indent: 56, color: dividerColor),

            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: Icon(
                Icons.palette_outlined,
                color: accentColor,
                size: 24,
              ),
              title: Text(
                'Изменить цвет имени',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: nameColor == const Color(0xFF000000) && isDark
                      ? Colors.white.withValues(alpha: 0.85)
                      : nameColor.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: nameColor == const Color(0xFF000000) && isDark
                        ? Colors.white
                        : nameColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  _userName,
                  style: TextStyle(
                    color: nameColor == const Color(0xFF000000) && isDark
                        ? Colors.black
                        : nameColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              onTap: () => _showNameColorBottomSheet(context, isDark, cardBg, textPrimary, accentColor, dividerColor),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 3. COLOR THEME PRESETS CAROUSEL (No stickers!)
  // ---------------------------------------------------------
  Widget _buildThemePresetsCard({
    required bool isDark,
    required Color cardBg,
    required Color dividerColor,
    required Color textPrimary,
    required Color accentColor,
    required Color selectionBorderColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Цветовая тема',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Horizontal Carousel of Presets (clean without stickers)
            SizedBox(
              height: 125,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: ChatThemePreset.presets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final preset = ChatThemePreset.presets[index];
                  final isSelected = _activePresetId == preset.id;
                  final Color presetBg = isDark ? preset.backgroundColor : preset.lightBackgroundColor;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _activePresetId = preset.id;
                        _customOwnColor = null;
                        _customOtherColor = null;
                      });
                      _onSettingChanged();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 76,
                      height: 122,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? selectionBorderColor : (isDark ? Colors.transparent : Colors.black12),
                          width: isSelected ? 2.5 : 1.0,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Doodle Pattern Background (no hearts)
                            TelegramDoodlePattern(
                              backgroundColor: presetBg,
                              doodleColor: isDark ? Colors.white : const Color(0xFF334155),
                              opacity: isDark ? 0.12 : 0.10,
                            ),

                            // Mock message bubbles without stickers
                            Padding(
                              padding: const EdgeInsets.all(7.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 4),

                                  // Outgoing bubble pill
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      width: 50,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: preset.ownBubbleGradient,
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Incoming bubble pill
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      width: 44,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF26252E).withValues(alpha: 0.9)
                                            : const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),

                                  const Spacer(),

                                  // Clean indicator / checkmark at bottom (NO EMOJI STICKERS)
                                  Center(
                                    child: isSelected
                                        ? Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: accentColor,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              size: 13,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const SizedBox(height: 19),
                                  ),
                                  const SizedBox(height: 5),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
            Divider(height: 1, indent: 16, color: dividerColor),

            // Toggle Day/Night Theme Tile
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              leading: Icon(
                isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                color: accentColor,
                size: 24,
              ),
              title: Text(
                isDark
                    ? 'Переключить на дневную тему'
                    : 'Переключить на ночную тему',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                AppTheme.themeNotifier.value = newMode;
                AppTheme.saveTheme(newMode);
                PreferencesService.saveThemeChoice(!isDark);
              },
            ),

            Divider(height: 1, indent: 56, color: dividerColor),

            // Theme Settings Tile
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              leading: Icon(
                Icons.brush_outlined,
                color: accentColor,
                size: 24,
              ),
              title: Text(
                'Настройки темы',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white38 : Colors.black38,
                size: 20,
              ),
              onTap: () => _showThemeSettingsBottomSheet(context, isDark, cardBg, textPrimary, accentColor, dividerColor),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 4. FONT SIZE SLIDER CARD (Just like Bubble Corner Radius!)
  // ---------------------------------------------------------
  Widget _buildFontSizeSliderCard({
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
    required Color accentColor,
  }) {
    final inactiveColor = isDark ? const Color(0xFF2A3A4D) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Размер текста сообщений',
            style: TextStyle(
              color: accentColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: accentColor,
                    thumbColor: accentColor,
                    inactiveTrackColor: inactiveColor,
                    trackHeight: 3.5,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16),
                    overlayColor: accentColor.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _fontSize,
                    min: 11,
                    max: 24,
                    divisions: 13,
                    onChanged: (val) {
                      setState(() => _fontSize = val);
                      _onSettingChanged();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Text(
                  '${_fontSize.toInt()} px',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 5. BUBBLE CORNER RADIUS SLIDER CARD
  // ---------------------------------------------------------
  Widget _buildBubbleCornerRadiusCard({
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
    required Color accentColor,
  }) {
    final inactiveColor = isDark ? const Color(0xFF2A3A4D) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Углы блоков с сообщениями',
            style: TextStyle(
              color: accentColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: accentColor,
                    thumbColor: accentColor,
                    inactiveTrackColor: inactiveColor,
                    trackHeight: 3.5,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16),
                    overlayColor: accentColor.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _bubbleRadius,
                    min: 0,
                    max: 24,
                    divisions: 24,
                    onChanged: (val) {
                      setState(() => _bubbleRadius = val);
                      _onSettingChanged();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                child: Text(
                  '${_bubbleRadius.toInt()}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 6. CHAT LIST MODE CARD (Two-line / Three-line)
  // ---------------------------------------------------------
  Widget _buildChatListModeCard({
    required bool isDark,
    required Color cardBg,
    required Color cardInnerBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color accentColor,
    required Color selectionBorderColor,
  }) {
    final isTwoLine = _chatListMode == 'two_line';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Список чатов',
            style: TextStyle(
              color: accentColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Two-line Option
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _chatListMode = 'two_line');
                    _onSettingChanged();
                  },
                  child: Column(
                    children: [
                      Container(
                        height: 74,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: cardInnerBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                isTwoLine ? selectionBorderColor : (isDark ? Colors.transparent : Colors.black12),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            // 2-line graphic
                            Expanded(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildMockChatLine(linesCount: 1, isDark: isDark),
                                  _buildMockChatLine(linesCount: 1, isDark: isDark),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Radio button
                            _buildRadioIndicator(isSelected: isTwoLine, accentColor: accentColor, isDark: isDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Двустрочный',
                        style: TextStyle(
                          color: isTwoLine ? textPrimary : textSecondary,
                          fontSize: 13,
                          fontWeight:
                              isTwoLine ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Three-line Option
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _chatListMode = 'three_line');
                    _onSettingChanged();
                  },
                  child: Column(
                    children: [
                      Container(
                        height: 74,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: cardInnerBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                !isTwoLine ? selectionBorderColor : (isDark ? Colors.transparent : Colors.black12),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            // 3-line graphic
                            Expanded(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildMockChatLine(linesCount: 2, isDark: isDark),
                                  _buildMockChatLine(linesCount: 2, isDark: isDark),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Radio button
                            _buildRadioIndicator(isSelected: !isTwoLine, accentColor: accentColor, isDark: isDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Трехстрочный',
                        style: TextStyle(
                          color: !isTwoLine ? textPrimary : textSecondary,
                          fontSize: 13,
                          fontWeight:
                              !isTwoLine ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMockChatLine({required int linesCount, required bool isDark}) {
    final avatarColor = isDark ? const Color(0xFF2A3A4D) : const Color(0xFFCBD5E1);
    final titleBarColor = isDark ? const Color(0xFF3B4F68) : const Color(0xFF94A3B8);
    final subBarColor = isDark ? const Color(0xFF223042) : const Color(0xFFE2E8F0);

    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: avatarColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: titleBarColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 65,
                height: 3.5,
                decoration: BoxDecoration(
                  color: subBarColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (linesCount == 2) ...[
                const SizedBox(height: 2.5),
                Container(
                  width: 50,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: subBarColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRadioIndicator({required bool isSelected, required Color accentColor, required bool isDark}) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? accentColor : (isDark ? const Color(0xFF475569) : const Color(0xFF9CA3AF)),
          width: 2,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                ),
              ),
            )
          : null,
    );
  }

  // ---------------------------------------------------------
  // MODAL BOTTOM SHEETS
  // ---------------------------------------------------------
  void _showWallpaperBottomSheet(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color accentColor,
    Color dividerColor,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Обои чата',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Gallery Picker Button
                Material(
                  color: cardBg,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.photo_library_outlined, color: accentColor),
                    ),
                    title: Text('Выбрать из галереи',
                        style: TextStyle(color: textPrimary, fontSize: 15)),
                    trailing: Icon(Icons.chevron_right,
                        color: isDark ? Colors.white38 : Colors.black38, size: 20),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickWallpaperFromGallery();
                    },
                  ),
                ),

                Divider(color: dividerColor, height: 16),
                Text(
                  'Однотонный фон',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),

                // Solid Colors List
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildWallpaperColorCircle('', 'По умолчанию', isDark, accentColor),
                      _buildWallpaperColorCircle('#0B1120', 'SAVT Темный', isDark, accentColor),
                      _buildWallpaperColorCircle('#1E293B', 'Синий сланец', isDark, accentColor),
                      _buildWallpaperColorCircle('#064E3B', 'Изумруд', isDark, accentColor),
                      _buildWallpaperColorCircle('#054582', 'SAVT Синий', isDark, accentColor),
                      _buildWallpaperColorCircle('#FFFFFF', 'Белый', isDark, accentColor),
                      _buildWallpaperColorCircle('#F1F5F9', 'Светло-серый', isDark, accentColor),
                    ],
                  ),
                ),

                if (_wallpaperUrl.isNotEmpty) ...[
                  Divider(color: dividerColor, height: 20),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => _wallpaperUrl = '');
                        _onSettingChanged(immediate: true);
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 18),
                      label: const Text(
                        'Сбросить обои к стандартным',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWallpaperColorCircle(String hex, String label, bool isDark, Color accentColor) {
    final isSelected = hex.isEmpty
        ? _wallpaperUrl.isEmpty
        : _wallpaperUrl == 'color:$hex';
    final color =
        hex.isEmpty ? (isDark ? const Color(0xFF1A2332) : const Color(0xFFE2E8F0)) : ChatNameColor.parse(hex);

    return GestureDetector(
      onTap: () {
        setState(() {
          _wallpaperUrl = hex.isEmpty ? '' : 'color:$hex';
        });
        _onSettingChanged();
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? accentColor : (isDark ? Colors.white24 : Colors.black12),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? Icon(Icons.check,
                color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                size: 20)
            : (hex.isEmpty
                ? Icon(Icons.block,
                    color: isDark ? Colors.white38 : Colors.black38, size: 18)
                : null),
      ),
    );
  }

  void _showNameColorBottomSheet(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color accentColor,
    Color dividerColor,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentColor = ChatNameColor.parse(_nameColorHex);
            final innerBg = isDark ? const Color(0xFF141D2B) : const Color(0xFFF1F5F9);

            return SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Цвет имени',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Preview badge banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: innerBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: currentColor == const Color(0xFF000000) && isDark
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : currentColor.withValues(alpha: isDark ? 0.2 : 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: currentColor == const Color(0xFF000000) && isDark
                                    ? Colors.white
                                    : currentColor.withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                            ),
                            child: Text(
                              _userName,
                              style: TextStyle(
                                color: currentColor == const Color(0xFF000000) && isDark
                                    ? Colors.black
                                    : currentColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Фамилия над вашими сообщениями будет окрашена этим цветом',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Palette circles
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: ChatNameColor.palette.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, idx) {
                          final item = ChatNameColor.palette[idx];
                          final isSelected =
                              item.hex.toLowerCase() == _nameColorHex.toLowerCase();

                          return GestureDetector(
                            onTap: () {
                              setSheetState(() => _nameColorHex = item.hex);
                              setState(() => _nameColorHex = item.hex);
                              _onSettingChanged();
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: item.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : (item.color == const Color(0xFF000000) && isDark
                                          ? Colors.white24
                                          : Colors.transparent),
                                  width: isSelected ? 3 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: item.color.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      color: item.color.computeLuminance() > 0.5
                                          ? Colors.black
                                          : Colors.white,
                                      size: 22,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showThemeSettingsBottomSheet(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color accentColor,
    Color dividerColor,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Настройки темы',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Custom bubble color pickers
                    Text(
                      'Цвет исходящих сообщений',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildColorChoice(
                            hex: _activePreset.ownBubbleHex,
                            name: 'По теме',
                            isSelected: _customOwnColor == null,
                            isDark: isDark,
                            onSelect: () {
                              setSheetState(() => _customOwnColor = null);
                              setState(() => _customOwnColor = null);
                              _onSettingChanged();
                            },
                          ),
                          _buildColorChoice(
                            hex: '#054582',
                            name: 'SAVT Blue',
                            isSelected: _customOwnColor == '#054582',
                            isDark: isDark,
                            onSelect: () {
                              setSheetState(() => _customOwnColor = '#054582');
                              setState(() => _customOwnColor = '#054582');
                              _onSettingChanged();
                            },
                          ),
                          _buildColorChoice(
                            hex: '#0A7AC2',
                            name: 'SAVT Light',
                            isSelected: _customOwnColor == '#0A7AC2',
                            isDark: isDark,
                            onSelect: () {
                              setSheetState(() => _customOwnColor = '#0A7AC2');
                              setState(() => _customOwnColor = '#0A7AC2');
                              _onSettingChanged();
                            },
                          ),
                          _buildColorChoice(
                            hex: '#10B981',
                            name: 'Изумруд',
                            isSelected: _customOwnColor == '#10B981',
                            isDark: isDark,
                            onSelect: () {
                              setSheetState(() => _customOwnColor = '#10B981');
                              setState(() => _customOwnColor = '#10B981');
                              _onSettingChanged();
                            },
                          ),
                          _buildColorChoice(
                            hex: '#F59E0B',
                            name: 'Оранж',
                            isSelected: _customOwnColor == '#F59E0B',
                            isDark: isDark,
                            onSelect: () {
                              setSheetState(() => _customOwnColor = '#F59E0B');
                              setState(() => _customOwnColor = '#F59E0B');
                              _onSettingChanged();
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorChoice({
    required String hex,
    required String name,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onSelect,
  }) {
    final color = ChatNameColor.parse(hex);

    return GestureDetector(
      onTap: onSelect,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? (isDark ? Colors.white : Colors.black87) : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
