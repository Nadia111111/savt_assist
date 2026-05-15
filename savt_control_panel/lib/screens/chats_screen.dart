// lib/screens/chats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';
import '../services/mock_data.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  int _currentIndex = 2;
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _allChats => MockData.allChats;

  List<Map<String, dynamic>> get _filteredChats {
    if (_searchQuery.isEmpty) return _allChats;
    return _allChats.where((chat) {
      return chat['name']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          chat['lastMessage']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBarTitle: 'Чаты',
      appBarAction: IconButton(
        icon: Icon(
          _isSearchExpanded ? Icons.close : Icons.search,
          color: Colors.white,
        ),
        onPressed: () {
          setState(() {
            _isSearchExpanded = !_isSearchExpanded;
            if (!_isSearchExpanded) {
              _searchQuery = '';
            }
          });
          if (_isSearchExpanded) {
            Future.delayed(const Duration(milliseconds: 100), () {
              FocusScope.of(context).requestFocus(_searchFocusNode);
            });
          } else {
            FocusScope.of(context).unfocus();
          }
        },
      ),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: _isSearchExpanded
                ? const EdgeInsets.fromLTRB(16, 12, 16, 8)
                : EdgeInsets.zero,
            child: _isSearchExpanded
                ? _buildSearchField()
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filteredChats.length,
              itemBuilder: (context, index) {
                return _buildChatCard(_filteredChats[index], index);
              },
            ),
          ),
        ],
      ),
      bottomNavBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTapped,
        unreadCounts: const {'chats': 3},
      ),
    );
  }

  Widget _buildSearchField() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        focusNode: _searchFocusNode,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Поиск по чатам...',
          hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
          prefixIcon: Icon(Icons.search,
              color: theme.colorScheme.onSurfaceVariant, size: 24),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildChatCard(Map<String, dynamic> chat, int index) {
    final theme = Theme.of(context);
    final hasUnread = chat['unread'] > 0;
    final isLocked = chat['isLocked'] as bool;
    final gradientColors = _getChatGradient(chat['type']);
    final String chatId = chat['id'] as String;
    final String chatType = chat['type'] as String;

    return AnimatedCard(
      index: index,
      onTap: isLocked
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Сначала обратитесь к ИИ Консультанту'),
                  backgroundColor: Color(0xFF054582),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          : () {
              if (chatType == 'notes') {
                Navigator.pushNamed(context, '/notes');
              } else {
                Navigator.pushNamed(context, '/chat/$chatId');
              }
            },
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradientColors[0].withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _getChatIcon(chatType),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat['name'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              hasUnread ? FontWeight.w700 : FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isLocked)
                      Icon(Icons.lock,
                          size: 14, color: theme.colorScheme.onSurfaceVariant)
                    else
                      Text(
                        chat['time'],
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  chat['lastMessage'] ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: hasUnread
                        ? (theme.colorScheme.onSurface)
                        : (theme.colorScheme.onSurfaceVariant),
                    fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (hasUnread && !isLocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF054582), Color(0xFF0a7ac2)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF054582).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${chat['unread']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getChatIcon(String type) {
    switch (type) {
      case 'ai':
        return Icons.auto_awesome;
      case 'general':
        return Icons.chat;
      case 'notes':
        return Icons.note_alt;
      case 'cabinet':
        return Icons.devices_other;
      case 'support':
        return Icons.support_agent;
      case 'tech':
        return Icons.build;
      case 'warranty':
        return Icons.shield;
      default:
        return Icons.chat;
    }
  }

  List<Color> _getChatGradient(String type) {
    switch (type) {
      case 'ai':
        return [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)];
      case 'support':
        return [const Color(0xFF054582), const Color(0xFF0a7ac2)];
      case 'tech':
        return [const Color(0xFF7C3AED), const Color(0xFFA78BFA)];
      case 'warranty':
        return [const Color(0xFF059669), const Color(0xFF34D399)];
      default:
        return [const Color(0xFF054582), const Color(0xFF0a7ac2)];
    }
  }

  void _onNavTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/shu-list');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/knowledge');
        break;
      case 2:
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }
}
