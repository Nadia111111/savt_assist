import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../widgets/gradient_scaffold.dart';

class OperatorPanelScreen extends StatefulWidget {
  const OperatorPanelScreen({super.key});

  @override
  State<OperatorPanelScreen> createState() => _OperatorPanelScreenState();
}

class _OperatorPanelScreenState extends State<OperatorPanelScreen> {
  final List<Map<String, String>> _activeChats = [
    {'user': 'Иван Петров', 'lastMsg': 'Проблема с ШУ-24М', 'time': '10:30'},
    {
      'user': 'Ольга Смирнова',
      'lastMsg': 'Не могу загрузить схему',
      'time': '09:15'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GradientScaffold(
      appBarTitle: 'Панель оператора',
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.base),
        itemCount: _activeChats.length,
        itemBuilder: (context, index) {
          final chat = _activeChats[index];
          return Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    theme.brightness == Brightness.dark ? const Color(0xFF2A3A4D) : Colors.grey.shade200,
                child: Icon(Icons.person,
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
              ),
              title: Text(chat['user']!,
                  style: TextStyle(
                      color: theme.colorScheme.onSurface)),
              subtitle: Text(chat['lastMsg']!,
                  style: TextStyle(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B))),
              trailing: Text(chat['time']!,
                  style: TextStyle(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8))),
              onTap: () {
                Navigator.pushNamed(context, '/chat/operator_$index');
              },
            ),
          );
        },
      ),
    );
  }
}
