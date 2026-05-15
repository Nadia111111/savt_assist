import 'package:flutter/material.dart';

class SearchMessagesScreen extends StatefulWidget {
  const SearchMessagesScreen({super.key});

  @override
  State<SearchMessagesScreen> createState() => _SearchMessagesScreenState();
}

class _SearchMessagesScreenState extends State<SearchMessagesScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> _results = [];

  final List<Map<String, String>> _allMessages = [
    {
      'chat': 'ИИ Консультант',
      'text': 'Помогите с настройками',
      'time': '10:00'
    },
    {
      'chat': 'Общие вопросы',
      'text': 'Как продлить гарантию?',
      'time': 'Вчера'
    },
    {'chat': 'ШУ-24М • ОБ-2024-001', 'text': 'Ошибка связи', 'time': 'Пн'},
    {
      'chat': 'ШУ-18К • ОБ-2024-002',
      'text': 'Гарантия продлена',
      'time': '10:30'
    },
  ];

  void _search(String query) {
    setState(() {
      _results = _allMessages
          .where((msg) =>
              msg['text']!.toLowerCase().contains(query.toLowerCase()) ||
              msg['chat']!.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor:
          theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Поиск сообщений'),
        backgroundColor:
            theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              style: TextStyle(
                  color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Поиск по чатам...',
                prefixIcon: Icon(Icons.search,
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF9CA3AF)),
                filled: true,
                fillColor:
                    theme.brightness == Brightness.dark ? const Color(0xFF1A2332) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: _search,
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      'Ничего не найдено',
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
                                ? const Color(0xFF0a7ac2)
                                : const Color(0xFF054582)),
                        title: Text(msg['text']!,
                            style: TextStyle(
                                color: theme.brightness == Brightness.dark
                                    ? Colors.white
                                    : const Color(0xFF1F2937))),
                        subtitle: Text('${msg['chat']} • ${msg['time']}',
                            style: TextStyle(
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B))),
                        onTap: () {
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
