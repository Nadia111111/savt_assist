// lib/screens/chats_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_colors.dart';
import '../services/offline_service.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';
import '../widgets/skeletons.dart';
import '../widgets/responsive_layout.dart';
import '../main.dart';

class ChatsScreen extends StatefulWidget {
  final bool isTab;
  const ChatsScreen({super.key, this.isTab = false});

  @override
  State<ChatsScreen> createState() => ChatsScreenState();
}

class ChatsScreenState extends State<ChatsScreen> with SingleTickerProviderStateMixin {
  final int _currentIndex = 2;
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _isSelectionMode = false;
  final Set<int> _selectedChatIds = {};

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedChatIds.clear();
    });
  }

  void resetState() {
    print('🔵 [ChatsScreen] resetState called');
    if (mounted) {
      setState(() {
        _isSearchExpanded = false;
        _searchQuery = '';
        _isSelectionMode = false;
        _selectedChatIds.clear();
      });
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  String _error = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_isSelectionMode) {
          _exitSelectionMode();
        }
        loadChats();
      }
    });
    loadChats();
  }

  String? _getChatTypeForTab(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return 'cabinet';
      case 2:
        return 'service_request';
      case 3:
        return 'support';
      case 4:
        return 'notes';
      default:
        return null;
    }
  }

   Future<void> loadChats() async {
     print('🔵 [ChatsScreen] loadChats called, mounted=$mounted, isLoading=$_isLoading');
     setState(() {
       _isLoading = true;
       _error = '';
     });
     try {
       final token = await tokenStorage.getAccessToken();
       if (token == null || token.isEmpty) {
         if (mounted) {
           setState(() {
             _chats = [];
             _isLoading = false;
           });
         }
         return;
       }
       final tabIndex = _tabController.index;
       final chatType = _getChatTypeForTab(tabIndex);
       final isArchived = tabIndex == 5;
       final chats = await chatService.getChats(chatType: chatType, archived: isArchived);
       print('🔵 [ChatsScreen] loadChats got ${chats.length} chats');
       if (mounted) {
         setState(() {
           _chats = chats;
           _error = '';
           _isLoading = false;
         });
       }
     } catch (e) {
       print('🔴 [ChatsScreen] loadChats error: $e');
       final tabIndex = _tabController.index;
       final cached = await chatService.getCachedChatsFallback(
         chatType: _getChatTypeForTab(tabIndex),
         archived: tabIndex == 5,
       );
       if (mounted) {
         setState(() {
           if (cached.isNotEmpty) {
             _chats = cached;
             _error = '';
           } else {
             _error = e.toString().replaceFirst('Exception: ', '');
           }
           _isLoading = false;
         });
         if (cached.isNotEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Text('Сервер временно недоступен (ошибка 500). Показаны сохранённые чаты.'),
               backgroundColor: Colors.orange.shade800,
               behavior: SnackBarBehavior.floating,
             ),
           );
         }
       }
     }
   }

  Future<void> _onRefresh() async {
    try {
      final tabIndex = _tabController.index;
      final chatType = _getChatTypeForTab(tabIndex);
      final isArchived = tabIndex == 5;
      final chats = await chatService.getChats(chatType: chatType, archived: isArchived);
      setState(() {
        _chats = chats;
        _error = '';
      });
    } catch (e) {
      if (mounted) {
        final cleanMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cleanMsg),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  bool _anyChatUnpinned(Iterable<int> chatIds) {
    return chatIds.any((id) {
      final c = _chats.firstWhere(
        (chat) {
          final cId = chat['id'] is num
              ? (chat['id'] as num).toInt()
              : int.tryParse(chat['id']?.toString() ?? '');
          return cId == id;
        },
        orElse: () => <String, dynamic>{},
      );
      final isPinned = c['is_pinned'] == true ||
          c['isPinned'] == true ||
          c['pinned'] == true;
      return !isPinned;
    });
  }

  Future<void> _togglePinSelectedChats() async {
    final selectedIds = List<int>.from(_selectedChatIds);
    if (selectedIds.isEmpty) return;

    final bool shouldPin = _anyChatUnpinned(selectedIds);

    setState(() {
      _chats = _chats.map((c) {
        final cId = c['id'] is num
            ? (c['id'] as num).toInt()
            : int.tryParse(c['id']?.toString() ?? '');
        if (cId != null && selectedIds.contains(cId)) {
          final updated = Map<String, dynamic>.from(c);
          updated['is_pinned'] = shouldPin;
          updated['pinned'] = shouldPin;
          return updated;
        }
        return c;
      }).toList();
      _exitSelectionMode();
    });

    bool hasError = false;
    for (final id in selectedIds) {
      try {
        if (shouldPin) {
          await chatService.pinChat(id);
        } else {
          await chatService.unpinChat(id);
        }
        await chatService.updateLocalChatPinned(id, shouldPin);
      } catch (e) {
        hasError = true;
      }
    }

    if (mounted) {
      if (hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось изменить закрепление для некоторых чатов'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                shouldPin ? 'Чат(ы) закреплены' : 'Чат(ы) откреплены'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedChats() async {
    final toDelete = List<int>.from(_selectedChatIds);
    if (toDelete.isEmpty) return;

    final deletable = toDelete.where((id) {
      final c = _chats.firstWhere(
        (chat) {
          final cId = chat['id'] is num
              ? (chat['id'] as num).toInt()
              : int.tryParse(chat['id']?.toString() ?? '');
          return cId == id;
        },
        orElse: () => <String, dynamic>{},
      );
      return c['chat_type'] != 'support';
    }).toList();

    if (deletable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Чат техподдержки нельзя удалить'),
          backgroundColor: Colors.orange,
        ),
      );
      _exitSelectionMode();
      return;
    }

    final hasSupport = deletable.length < toDelete.length;
    final message = deletable.length == 1
        ? 'Вы уверены, что хотите удалить выбранный чат? Все сообщения будут безвозвратно удалены.'
        : 'Выбрано ${deletable.length} чат(ов). Вы уверены, что хотите удалить их из списка? Все сообщения будут безвозвратно удалены.${hasSupport ? '\n(Чат техподдержки не может быть удален)' : ''}';

    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить чаты?'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child:
                    const Text('Удалить', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm != true) return;

    _exitSelectionMode();

    bool hasError = false;
    for (final id in deletable) {
      try {
        await chatService.deleteChat(id);
      } catch (e) {
        hasError = true;
      }
    }

    await loadChats();

    if (!mounted) return;
    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось удалить некоторые чаты'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Чат(ы) успешно удалены'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredChats {
    List<Map<String, dynamic>> list = _chats;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((chat) {
        final chatType = chat['chat_type']?.toString() ?? '';
        final name = (chat['cabinet_name'] ?? chat['project_name'] ?? chatType)
            .toString()
            .toLowerCase();
        final lastMsg =
            (chat['last_message_text'] ?? '').toString().toLowerCase();
        return name.contains(query) || lastMsg.contains(query);
      }).toList();
    }

    final pinned = <Map<String, dynamic>>[];
    final unpinned = <Map<String, dynamic>>[];
    for (final c in list) {
      final isPinned = c['is_pinned'] == true ||
          c['isPinned'] == true ||
          c['pinned'] == true;
      if (isPinned) {
        pinned.add(c);
      } else {
        unpinned.add(c);
      }
    }
    return [...pinned, ...unpinned];
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unreadTotal = _chats.fold<int>(
        0, (sum, c) => sum + ((c['unread_count'] as num?)?.toInt() ?? 0));
    print('🔵 [ChatsScreen] unreadTotal=$unreadTotal');
    OfflineService().updateUnreadChatCount(unreadTotal);

    return GradientScaffold(
      appBarTitle: _isSelectionMode
          ? 'Выбрано: ${_selectedChatIds.length}'
          : 'Чаты',
      showBackButton: false,
      appBarLeading: _isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _exitSelectionMode,
            )
          : null,
      appBarAction: _isSelectionMode
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedChatIds.isNotEmpty) ...[
                  IconButton(
                    icon: Icon(
                      _anyChatUnpinned(_selectedChatIds)
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      color: Colors.white,
                    ),
                    tooltip: 'Закрепить/открепить',
                    onPressed: _togglePinSelectedChats,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    tooltip: 'Удалить выбранные',
                    onPressed: _deleteSelectedChats,
                  ),
                ],
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(_isSearchExpanded ? Icons.close : Icons.search,
                      color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isSearchExpanded = !_isSearchExpanded;
                      if (!_isSearchExpanded) _searchQuery = '';
                    });
                    if (_isSearchExpanded) {
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) {
                          FocusScope.of(this.context).requestFocus(_searchFocusNode);
                        }
                      });
                    } else {
                      FocusScope.of(context).unfocus();
                    }
                  },
                ),
              ],
            ),
      body: ResponsiveContainer(
        maxWidth: 600,
        child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
             padding: _isSearchExpanded
                 ? const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.sm)
                 : EdgeInsets.zero,
            child: _isSearchExpanded
                ? _buildSearchField()
                : const SizedBox.shrink(),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            dividerColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
            tabs: const [
              Tab(text: 'Все'),
              Tab(text: 'Шкафы'),
              Tab(text: 'Заявки'),
              Tab(text: 'Поддержка'),
              Tab(text: 'Заметки'),
              Tab(text: 'Архив'),
            ],
          ),
           Expanded(
              child: _isLoading
                  ? const SkeletonList()
                  : _error.isNotEmpty
                      ? RefreshIndicator(
                          onRefresh: loadChats,
                          color: const Color(0xFF0a7ac2),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 60),
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.cloud_off_rounded,
                                      size: 38,
                                      color: AppColors.error,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.base),
                                  Text(
                                    'Ошибка загрузки чатов',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    _error,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  ElevatedButton.icon(
                                    onPressed: loadChats,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Повторить попытку'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: const Color(0xFF0a7ac2),
                          child: _filteredChats.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height: MediaQuery.of(context).size.height * 0.6,
                                      child: _buildEmptyState(),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  cacheExtent: 250, controller: _scrollController,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.base, vertical: AppSpacing.sm),
                                  itemCount: _filteredChats.length,
                                  itemBuilder: (context, index) =>
                                      _buildChatCard(_filteredChats[index], index),
                                ),
                        ),
           ),
        ],
      ),
      ),
      bottomNavBar: widget.isTab
          ? null
          : BottomNavBar(
              currentIndex: _currentIndex,
              onTap: _onNavTapped,
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
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
        ),
      ),
    );
  }

  Widget _buildChatCard(Map<String, dynamic> chat, int index) {
    final theme = Theme.of(context);
    final int? chatId = chat['id'] is num
        ? (chat['id'] as num).toInt()
        : int.tryParse(chat['id']?.toString() ?? '');
    final bool isSelected = chatId != null && _selectedChatIds.contains(chatId);
    final int unreadCount = (chat['unread_count'] as num?)?.toInt() ?? 0;
    final bool hasUnread = unreadCount > 0;
    final chatType = chat['chat_type'] as String? ?? '';
    final name = chat['cabinet_name'] ?? _getChatTypeName(chatType, chat);
    final lastMessage = chat['last_message_text'] ?? 'Нет сообщений';
    final lastTime = _formatTime(chat['last_message_at']);
    final bool isPinned = chat['is_pinned'] == true ||
        chat['isPinned'] == true ||
        chat['pinned'] == true;

    return AnimatedCard(
      index: index,
      backgroundColor:
          isSelected ? theme.colorScheme.primary.withValues(alpha: 0.08) : null,
      onLongPress: () {
        if (_isSelectionMode || chatId == null) return;
        setState(() {
          _isSelectionMode = true;
          _selectedChatIds.add(chatId);
        });
      },
      onTap: () async {
        if (_isSelectionMode) {
          if (chatId == null) return;
          setState(() {
            if (isSelected) {
              _selectedChatIds.remove(chatId);
              if (_selectedChatIds.isEmpty) {
                _isSelectionMode = false;
              }
            } else {
              _selectedChatIds.add(chatId);
            }
          });
          return;
        }
        await Navigator.pushNamed(context, '/chat/${chat['id']}');
        loadChats(); // Обновляем список чатов после возврата
      },
      child: Row(
        children: [
          if (_isSelectionMode) ...[
            Checkbox(
              value: isSelected,
              activeColor: theme.colorScheme.primary,
              onChanged: (_) {
                if (chatId == null) return;
                setState(() {
                  if (isSelected) {
                    _selectedChatIds.remove(chatId);
                    if (_selectedChatIds.isEmpty) {
                      _isSelectionMode = false;
                    }
                  } else {
                    _selectedChatIds.add(chatId);
                  }
                });
              },
            ),
            const SizedBox(width: 8),
          ],
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: _getChatGradient(chatType),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: _getChatGradient(chatType)[0].withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Icon(_getChatIcon(chatType), color: Colors.white, size: 24),
              ),
              gapW12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight:
                                        hasUnread ? FontWeight.w700 : FontWeight.w600,
                                    color: theme.colorScheme.onSurface),
                              ),
                            ),
                            if (!_isSelectionMode && isPinned) ...[
                              const SizedBox(width: 6),
                              Transform.rotate(
                                angle: 0.4,
                                child: Icon(
                                  Icons.push_pin,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(lastTime,
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal)),
                    ],
                  ),
                   const SizedBox(height: AppSpacing.xs),
                   Text(
                     lastMessage,
                     style: TextStyle(
                         fontSize: 13,
                         color: hasUnread
                             ? theme.colorScheme.onSurface
                             : theme.colorScheme.onSurfaceVariant,
                         fontWeight:
                             hasUnread ? FontWeight.w500 : FontWeight.normal),
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                   ),
                 ],
               ),
             ),
             if (hasUnread)
               Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
                  ),
                child: Text('$unreadCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      );
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
      case 'service_request':
        final reqId = chat?['service_request_id'];
        final reqType = chat?['service_request_type']?.toString() ?? '';
        final typeText = _mapRequestTypeToText(reqType);
        return reqId != null ? 'Заявка №$reqId ($typeText)' : 'Заявка ($typeText)';
      default:
        return 'Чат';
    }
  }

  String _mapRequestTypeToText(String type) {
    switch (type) {
      case 'repair':
        return 'Ремонт';
      case 'diagnostics':
        return 'Диагностика';
      case 'remote_adjustment':
        return 'Наладка удалённо';
      case 'onsite_adjustment':
        return 'Наладка с выездом';
      case 'maintenance':
        return 'Обслуживание';
      case 'inspection':
        return 'Проверка';
      default:
        return type;
    }
  }

  IconData _getChatIcon(String type) {
    switch (type) {
      case 'cabinet':
        return Icons.devices_other;
      case 'support':
        return Icons.support_agent;
      case 'notes':
        return Icons.note_alt;
      case 'project':
        return Icons.folder;
      case 'service_request':
        return Icons.assignment;
      default:
        return Icons.chat;
    }
  }

  List<Color> _getChatGradient(String type) {
    switch (type) {
      case 'cabinet':
        return [const Color(0xFF7C3AED), const Color(0xFFA78BFA)];
      case 'support':
        return [const Color(0xFF054582), const Color(0xFF0a7ac2)];
      case 'notes':
        return [const Color(0xFF059669), const Color(0xFF34D399)];
      case 'project':
        return [const Color(0xFFD97706), const Color(0xFFFBBF24)];
      case 'service_request':
        return [const Color(0xFFEA580C), const Color(0xFFFDBA74)];
      default:
        return [const Color(0xFF054582), const Color(0xFF0a7ac2)];
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      String dateStr = isoTime;
      if (!dateStr.contains('Z') && !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(dateStr)) {
        dateStr = dateStr.replaceAll(' ', 'T');
        if (!dateStr.endsWith('Z')) {
          dateStr += 'Z';
        }
      }
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (date.month == now.month && date.year == now.year && now.day - date.day == 1) {
        return 'Вчера';
      } else {
        return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return '';
    }
  }

   Widget _buildEmptyState() {
     final theme = Theme.of(context);
     return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(Icons.chat_bubble_outline,
               size: 64, color: theme.colorScheme.outline),
           const SizedBox(height: 16),
           Text('Нет чатов',
               style: theme.textTheme.bodyMedium
                   ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
         ],
       ),
     );
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
