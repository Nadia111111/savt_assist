// lib/screens/notes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/skeletons.dart';
import '../main.dart'; // chatService

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _notes = [];
  int? _notesChatId;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadNotesChat();
  }

  Future<void> _loadNotesChat() async {
    try {
      final chats = await chatService.getChats();
      // Ищем чат с типом 'notes'
      Map<String, dynamic>? notesChat;
      for (final chat in chats) {
        if (chat['chat_type'] == 'notes') {
          notesChat = chat;
          break;
        }
      }
      if (notesChat == null) {
        setState(() {
          _error = 'Чат заметок не найден';
          _isLoading = false;
        });
        return;
      }
      _notesChatId = notesChat['id'];
      await _loadNotes();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final messages = await chatService.getMessages(_notesChatId!, limit: 100);

      setState(() {
        if (messages != null) {
          _notes = messages.reversed.toList(); // от старых к новым
        } else {
          _notes = [];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addNote() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _notesChatId == null) return;

    setState(() => _isLoading = true);
    try {
      final newMsg = await chatService.sendTextMessage(_notesChatId!, text);
      setState(() {
        _notes.add(newMsg);
        _controller.clear();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Ошибка добавления заметки: $e');
    }
  }

  Future<void> _editNote(int index) async {
    final note = _notes[index];
    final editController = TextEditingController(text: note['text']);
    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать заметку'),
        content: TextField(
          controller: editController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Введите текст заметки...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Сохранить',
                style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
    if (result == true && editController.text.trim().isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await chatService.editMessage(
            _notesChatId!, note['id'], editController.text.trim());
        setState(() {
          note['text'] = editController.text.trim();
          note['created_at'] = DateTime.now().toIso8601String();
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        _showError('Ошибка редактирования: $e');
      }
    }
  }

  Future<void> _deleteNote(int index) async {
    final note = _notes[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      await chatService.deleteMessage(_notesChatId!, note['id']);
      setState(() {
        _notes.removeAt(index);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Ошибка удаления: $e');
    }
  }

  Future<void> _copyNote(int index) async {
    final note = _notes[index];
    await Clipboard.setData(ClipboardData(text: note['text']));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Текст заметки скопирован'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2)),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating),
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final date = DateTime.parse(isoTime);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GradientScaffold(
      appBarTitle: 'Мои заметки',
      body: _isLoading && _notes.isEmpty
          ? const SkeletonList()
          : _error.isNotEmpty
              ? Center(child: Text('Ошибка: $_error'))
              : Column(
                  children: [
                    Expanded(
                      child: _notes.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              reverse: false,
                              padding: const EdgeInsets.all(16),
                              itemCount: _notes.length,
                              itemBuilder: (context, index) {
                                final note = _notes[index];
                                return GestureDetector(
                                  onLongPress: () => _showContextMenu(index),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.75,
                                        ),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              theme.colorScheme.primary,
                                              theme.colorScheme.secondary
                                            ],
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(20),
                                            topRight: Radius.circular(20),
                                            bottomLeft: Radius.circular(20),
                                            bottomRight: Radius.circular(4),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.colorScheme.primary
                                                  .withValues(alpha: 0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(note['text'],
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14)),
                                            const SizedBox(height: 6),
                                            Text(
                                                _formatTime(note['created_at']),
                                                style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    _buildInputBar(),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_add_outlined,
              size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('Нет заметок',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Новая заметка...',
                  hintStyle:
                      TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _addNote(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _addNote,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary
                ]),
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.send, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContextMenu(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF054582)),
              title: const Text('Редактировать'),
              onTap: () {
                Navigator.pop(ctx);
                _editNote(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Color(0xFF054582)),
              title: const Text('Копировать'),
              onTap: () {
                Navigator.pop(ctx);
                _copyNote(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xFF991B1B)),
              title: const Text('Удалить',
                  style: TextStyle(color: Color(0xFF991B1B))),
              onTap: () {
                Navigator.pop(ctx);
                _deleteNote(index);
              },
            ),
          ],
        ),
      ),
    );
  }
}
