// lib/screens/search_messages_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/skeletons.dart';
import '../main.dart';

class SearchMessagesScreen extends StatefulWidget {
  const SearchMessagesScreen({super.key});

  @override
  State<SearchMessagesScreen> createState() => _SearchMessagesScreenState();
}

class _SearchMessagesScreenState extends State<SearchMessagesScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GradientScaffold(
      appBarTitle: 'Поиск сообщений',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: TextField(
              controller: _controller,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Поиск по чатам...',
                prefixIcon: Icon(Icons.search,
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF9CA3AF)),
                filled: true,
                fillColor: theme.brightness == Brightness.dark
                    ? const Color(0xFF1A2332)
                    : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: _results.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _results = []);
                        },
                      )
                    : null,
              ),
              onSubmitted: (query) => _searchMessages(query),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: ShimmerBlock(height: 200, borderRadius: 16)),
            )
          else
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        'Введите текст для поиска',
                        style: TextStyle(
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFF64748B)
                                : Colors.grey.shade500,
                            fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final msg = _results[index];
                        return ListTile(
                          leading: Icon(Icons.chat_bubble_outline,
                              color: theme.brightness == Brightness.dark
                                  ? AppColors.primaryLight
                                  : AppColors.primary),
                          title: Text(msg['text']!,
                              style: TextStyle(
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF1F2937))),
                          subtitle: Text('${msg['chat_name']} • ${msg['time']}',
                              style: TextStyle(
                                  color: theme.brightness == Brightness.dark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary)),
                          onTap: () {
                            final chatId = msg['chat_id'];
                            final msgId = msg['id'];
                            Navigator.pop(context);
                            Navigator.pushNamed(
                                context, '/chat/$chatId?around_id=$msgId');
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
        }

  Future<void> _searchMessages(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _results = [];
    });

    try {
      final allChats = await chatService.getChats();
      final results = <Map<String, dynamic>>[];
      final lowerQuery = query.toLowerCase();

      for (final chat in allChats) {
        final rawChatId = chat['id'];
        final chatId = rawChatId is num ? rawChatId.toInt() : (int.tryParse(rawChatId?.toString() ?? '') ?? 0);
        final chatName = _getChatTypeName(chat['chat_type'] ?? '', chat);

        try {
          final messages = await chatService.getMessages(chatId, limit: 100);
          if (messages == null) continue;

          for (final msg in messages) {
            final text = msg['text'] as String? ?? '';
            if (text.toLowerCase().contains(lowerQuery)) {
              results.add({
                'id': msg['id'],
                'chat_id': chatId,
                'chat_name': chatName,
                'text': text,
                'created_at': msg['created_at'],
                'time': _formatTime(msg['created_at']),
                'is_own': msg['is_own'] ?? false,
              });
            }
          }
        } catch (_) {
          continue;
        }
      }

      results.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at'] ?? '');
        final dateB = DateTime.tryParse(b['created_at'] ?? '');
        if (dateA != null && dateB != null) return dateB.compareTo(dateA);
        return 0;
      });

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка поиска: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getChatTypeName(String type, [Map<String, dynamic>? chat]) {
    switch (type) {
      case 'cabinet':
        return 'Шкаф управления';
      case 'support':
        return 'Общие вопросы';
      case 'notes':
        return 'Заметки';
      case 'project':
        return chat?['project_name']?.toString() ?? 'Проект';
      default:
        return 'Чат';
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final date = DateTime.parse(isoTime);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Только что';
      if (diff.inHours < 1) return '${diff.inMinutes} мин. назад';
      if (diff.inDays < 1) return '${diff.inHours} ч. назад';
      if (diff.inDays < 7) return '${diff.inDays} дн. назад';
      return '${date.day}.${date.month}';
    } catch (_) {
      return '';
    }
  }
}
