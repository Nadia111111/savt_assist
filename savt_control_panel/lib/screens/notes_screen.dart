// lib/screens/notes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';

class NoteModel {
  String id;
  String text;
  String time;

  NoteModel({required this.id, required this.text, required this.time});
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  // Статический список для доступа из других экранов (например, из чата)
  static List<NoteModel> notes = [];

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _controller = TextEditingController();

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _addNote() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      NotesScreen.notes.insert(
        0,
        NoteModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          time: _getCurrentTime(),
        ),
      );
      _controller.clear();
    });
  }

  void _editNote(int index) {
    final note = NotesScreen.notes[index];
    final editController = TextEditingController(text: note.text);
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text('Редактировать заметку'),
          content: TextField(
            controller: editController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Введите текст заметки...',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Отмена',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () {
                final newText = editController.text.trim();
                if (newText.isNotEmpty) {
                  setState(() {
                    note.text = newText;
                    note.time = _getCurrentTime(); // обновляем время
                  });
                }
                Navigator.pop(ctx);
              },
              child: Text('Сохранить',
                  style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        );
      },
    );
  }

  void _deleteNote(int index) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text('Удалить заметку?'),
          content: Text('Это действие нельзя отменить.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Отмена',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () {
                setState(() => NotesScreen.notes.removeAt(index));
                Navigator.pop(ctx);
              },
              child: Text('Удалить',
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        );
      },
    );
  }

  void _copyNote(int index) {
    final note = NotesScreen.notes[index];
    Clipboard.setData(ClipboardData(text: note.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Текст заметки скопирован в буфер обмена'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = NotesScreen.notes;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Мои заметки'),
      ),
      body: Column(
        children: [
          Expanded(
            child: notes.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    reverse: false,
                    padding: const EdgeInsets.all(16),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return GestureDetector(
                        onLongPress: () => _showContextMenu(index),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
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
                                        .withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    note.text,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    note.time,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 10),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(
                                delay: Duration(milliseconds: 30 * index)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Поле ввода
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.1),
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
                        hintStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
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
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary
                        ],
                      ),
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
          ),
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
          Text(
            'Нет заметок',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // Контекстное меню (долгое нажатие)
  void _showContextMenu(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
