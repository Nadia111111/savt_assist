// lib/screens/chat_settings_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/skeletons.dart';
import '../services/network_service.dart';
import '../main.dart';

class ChatSettingsScreen extends StatefulWidget {
  final String? chatId; // If null, global settings

  const ChatSettingsScreen({super.key, this.chatId});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  bool _isLoading = false;
  bool _isSaving = false;

  // Settings State
  String _ownBubbleColor = '#054582';
  String _otherBubbleColor = '#E2E8F0';
  String _botBubbleColor = '#F3F4F6';
  double _fontSize = 14.0;
  String _wallpaperUrl = '';

  // Preset Colors
  final List<Map<String, String>> _ownColorPresets = [
    {'name': 'SAVT Blue', 'hex': '#054582'},
    {'name': 'SAVT Light Blue', 'hex': '#0a7ac2'},
    {'name': 'Изумрудный', 'hex': '#10B981'},
    {'name': 'Фиолетовый', 'hex': '#8B5CF6'},
    {'name': 'Оранжевый', 'hex': '#F59E0B'},
    {'name': 'Темный', 'hex': '#374151'},
  ];

  final List<Map<String, String>> _otherColorPresets = [
    {'name': 'Светлый', 'hex': '#E2E8F0'},
    {'name': 'Мятный', 'hex': '#D1FAE5'},
    {'name': 'Лаванда', 'hex': '#EDE9FE'},
    {'name': 'Абрикос', 'hex': '#FEF3C7'},
    {'name': 'Серый', 'hex': '#F3F4F6'},
  ];

  final List<Map<String, String>> _botColorPresets = [
    {'name': 'Стандарт', 'hex': '#F3F4F6'},
    {'name': 'Светло-синий', 'hex': '#E0F2FE'},
    {'name': 'Светло-зеленый', 'hex': '#DCFCE7'},
    {'name': 'Светло-желтый', 'hex': '#FEF9C3'},
  ];

  final List<Map<String, String>> _solidWallpaperPresets = [
    {'name': 'По умолчанию', 'hex': ''},
    {'name': 'Темно-синий', 'hex': 'color:#1e293b'},
    {'name': 'Глубокий синий', 'hex': 'color:#0f172a'},
    {'name': 'Темный цинк', 'hex': 'color:#18181b'},
    {'name': 'Светлый серый', 'hex': 'color:#f4f4f5'},
    {'name': 'Светло-зеленый', 'hex': 'color:#f0fdf4'},
    {'name': 'Светло-фиолетовый', 'hex': 'color:#faf5ff'},
    {'name': 'Светло-синий', 'hex': 'color:#eff6ff'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  String get _cacheKey {
    if (widget.chatId != null) {
      return 'chat_settings_${widget.chatId}';
    }
    return 'chat_settings_global';
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    // 1. Try to load from local cache first
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(jsonDecode(cached));
        _applyLoadedSettings(data);
      }
    } catch (e) {
      debugPrint('Error loading cached settings: $e');
    }

    // 2. Fetch from server if online
    if (NetworkService.isOnline) {
      try {
        Map<String, dynamic> settings;
        final chatIdInt =
            widget.chatId != null ? int.tryParse(widget.chatId!) : null;
        if (chatIdInt != null) {
          settings = await chatService.getChatSettings(chatIdInt);
        } else {
          settings = await chatService.getGlobalSettings();
        }

        if (mounted) {
          setState(() {
            final merged = <String, dynamic>{
              'own_bubble_color': _ownBubbleColor,
              'other_bubble_color': _otherBubbleColor,
              'bot_bubble_color': _botBubbleColor,
              'font_size': _fontSize.toInt(),
              'wallpaper_url': _wallpaperUrl,
            };
            settings.forEach((key, value) {
              if (value != null && value.toString().isNotEmpty) {
                merged[key] = value;
              }
            });
            _applyLoadedSettings(merged);
          });

          // Update cache with merged settings
          final prefs = await SharedPreferences.getInstance();
          final dataToCache = {
            'own_bubble_color': _ownBubbleColor,
            'other_bubble_color': _otherBubbleColor,
            'bot_bubble_color': _botBubbleColor,
            'font_size': _fontSize.toInt(),
            'wallpaper_url': _wallpaperUrl,
          };
          await prefs.setString(_cacheKey, jsonEncode(dataToCache));
        }
      } catch (e) {
        debugPrint('Error fetching settings from server: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applyLoadedSettings(Map<String, dynamic> settings) {
    if (settings['own_bubble_color'] != null) {
      _ownBubbleColor = settings['own_bubble_color'].toString();
    }
    if (settings['other_bubble_color'] != null) {
      _otherBubbleColor = settings['other_bubble_color'].toString();
    }
    if (settings['bot_bubble_color'] != null) {
      _botBubbleColor = settings['bot_bubble_color'].toString();
    }
    if (settings['font_size'] != null) {
      _fontSize = double.tryParse(settings['font_size'].toString()) ?? 14.0;
    }
    if (settings['wallpaper_url'] != null) {
      _wallpaperUrl = settings['wallpaper_url'].toString();
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    final data = {
      'own_bubble_color': _ownBubbleColor,
      'other_bubble_color': _otherBubbleColor,
      'bot_bubble_color': _botBubbleColor,
      'font_size': _fontSize.toInt(),
      'wallpaper_url': _wallpaperUrl,
    };

    // 1. Save to local cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data));
      _showSuccess('Настройки успешно сохранены');
    } catch (e) {
      debugPrint('Error caching settings: $e');
      _showError('Ошибка локального сохранения настроек: $e');
    }

    // 2. Sync to server in background if online (ignored if server settings endpoints aren't implemented)
    if (NetworkService.isOnline) {
      try {
        final chatIdInt =
            widget.chatId != null ? int.tryParse(widget.chatId!) : null;
        if (chatIdInt != null) {
          await chatService.updateChatSettings(chatIdInt, data);
        } else {
          await chatService.updateGlobalSettings(data);
        }
      } catch (e) {
        debugPrint('Server settings sync failed (ignored): $e');
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _resetSettings() async {
    if (widget.chatId == null) return;
    setState(() => _isSaving = true);

    try {
      final chatIdInt = int.tryParse(widget.chatId!) ?? 0;
      if (chatIdInt != 0) {
        if (NetworkService.isOnline) {
          await chatService.resetChatSettings(chatIdInt);
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cacheKey);

        _showSuccess('Настройки чата сброшены к глобальным');
        _loadSettings();
      }
    } catch (e) {
      _showError('Ошибка сброса настроек: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), backgroundColor: Colors.green),
      );
    }
  }

  Color _parseColor(String hex) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPerChat = widget.chatId != null;

    return GradientScaffold(
      appBarTitle:
          isPerChat ? 'Настройки этого чата' : 'Глобальные настройки чатов',
      appBarLeading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      body: _isLoading
          ? const SkeletonDetail()
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Own Messages Color
                  _buildSectionHeader('Цвет ваших сообщений'),
                  _buildColorSelector(_ownColorPresets, _ownBubbleColor, (hex) {
                    setState(() => _ownBubbleColor = hex);
                  }),
                  const SizedBox(height: 20),

                  // Other Messages Color
                  _buildSectionHeader('Цвет сообщений собеседника'),
                  _buildColorSelector(_otherColorPresets, _otherBubbleColor,
                      (hex) {
                    setState(() => _otherBubbleColor = hex);
                  }),
                  const SizedBox(height: 20),

                  // Bot Messages Color
                  _buildSectionHeader('Цвет сообщений бота/системы'),
                  _buildColorSelector(_botColorPresets, _botBubbleColor, (hex) {
                    setState(() => _botBubbleColor = hex);
                  }),
                  const SizedBox(height: 20),

                  // Font Size
                  _buildSectionHeader(
                      'Размер шрифта сообщений: ${_fontSize.toInt()} px'),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: theme.colorScheme.primary,
                      thumbColor: theme.colorScheme.primary,
                    ),
                    child: Slider(
                      value: _fontSize,
                      min: 8,
                      max: 24,
                      divisions: 16,
                      label: '${_fontSize.toInt()}',
                      onChanged: (val) {
                        setState(() => _fontSize = val);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Wallpaper Selector
                  _buildSectionHeader('Обои чата'),
                  _buildWallpaperSelector(),
                  const SizedBox(height: 30),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveSettings,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Сохранить',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (isPerChat) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : _resetSettings,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Colors.red),
                              foregroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Сбросить',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildColorSelector(List<Map<String, String>> presets,
      String selectedHex, Function(String) onSelect) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        itemBuilder: (context, idx) {
          final p = presets[idx];
          final hex = p['hex']!;
          final isSelected = hex.toLowerCase() == selectedHex.toLowerCase();
          final color = _parseColor(hex);

          return GestureDetector(
            onTap: () => onSelect(hex),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: color.computeLuminance() > 0.6
                          ? Colors.black
                          : Colors.white,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickWallpaperFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final url = await uploadService.uploadAttachment(image.path);
      setState(() {
        _wallpaperUrl = url;
      });
      _showSuccess('Фото успешно загружено для обоев');
    } catch (e) {
      _showError('Ошибка загрузки фото: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildWallpaperSelector() {
    final theme = Theme.of(context);
    final isUrlWallpaper = _wallpaperUrl.startsWith('http') ||
        (!_wallpaperUrl.startsWith('color:#') && _wallpaperUrl.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _pickWallpaperFromGallery,
              icon: const Icon(Icons.photo_library, size: 18),
              label: const Text('Выбрать из галереи'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (isUrlWallpaper)
              Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: theme.colorScheme.primary, width: 2),
                      image: DecorationImage(
                        image: NetworkImage(_wallpaperUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _wallpaperUrl = '';
                        });
                      },
                      child: const CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Icon(Icons.close, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            else if (_wallpaperUrl.isEmpty)
              const Text('Обои по умолчанию',
                  style: TextStyle(color: Colors.grey, fontSize: 13))
            else
              const SizedBox.shrink(),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('Или выберите цвет фона:'),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _solidWallpaperPresets.length,
            itemBuilder: (context, idx) {
              final p = _solidWallpaperPresets[idx];
              final hexValue = p['hex']!;
              final isSelected = _wallpaperUrl == hexValue;

              Color color;
              if (hexValue.isEmpty) {
                color = Colors.grey.shade300;
              } else {
                color = _parseColor(hexValue.replaceFirst('color:', ''));
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _wallpaperUrl = hexValue;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 3.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: hexValue.isEmpty
                      ? const Icon(Icons.block, color: Colors.grey)
                      : (isSelected
                          ? Icon(
                              Icons.check,
                              color: color.computeLuminance() > 0.6
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : null),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
