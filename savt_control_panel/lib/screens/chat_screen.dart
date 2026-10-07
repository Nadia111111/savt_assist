// lib/screens/chat_screen.dart
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import '../services/file_save_helper.dart';
import '../services/api_client.dart';
import 'package:open_file/open_file.dart';
import '../utils/download_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/offline_service.dart';
import '../services/db_service.dart';
import '../services/network_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/auth_image.dart';
import '../widgets/voice_message_player.dart';
import '../widgets/offline_aware_button.dart';
import '../services/preferences_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/keep_alive_wrapper.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/chat_video_bubble.dart';
import 'fullscreen_image_viewer.dart';
import 'image_editor_screen.dart';
import 'shared_media_screen.dart';
import '../models/chat_message.dart';
import '../main.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final int? aroundId;

  const ChatScreen({super.key, required this.chatId, this.aroundId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessage> _messages = [];
  List<ChatMessage> _pinnedMessages = [];
  int _currentPinnedIndex = 0;
  Map<String, dynamic> _chatSettings = {};
  ChatMessage? _replyTo;
  ChatMessage? _editingMessage;
  
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isRecordLocked = false;
  Timer? _recordTimer;
  int _recordDurationSeconds = 0;
  String? _currentRecordingPath;

  bool _isLoading = true;
  int? _myUserId;
  String _chatTitle = 'Чат';
  int _realChatId = 0;
  Map<String, dynamic>? _chatDetail;
  bool _isChatArchived = false;

  bool _showScrollToBottom = false;
  int _unreadMessagesCount = 0;
  String? _highlightedMessageId;
  final Map<String, GlobalKey> _messageKeys = {};
  final Map<String, Set<String>> _myReactions = {};

  final Set<String> _selectedMessages = {};
  final Set<String> _deletedMessageIds = {};
  bool _isSelectionMode = false;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final List<int> _matchingIndices = [];
  int _currentMatchIndex = 0;
  
  bool _isLoadingMoreMessages = false;
  bool _hasMoreMessages = true;

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _realChatId = int.tryParse(widget.chatId) ?? 0;
    if (_realChatId > 0) {
      PreferencesService.saveLastChatId(_realChatId);
    }
    _loadInitialData();

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final show = _scrollController.offset > 200;
        if (show != _showScrollToBottom) {
          setState(() {
            _showScrollToBottom = show;
            if (!show) {
              _unreadMessagesCount = 0;
            }
          });
        }

        if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 200) {
          _loadMoreMessages();
        }
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        if (mounted) {
          setState(() {});
        }
      }
    });

    OfflineService().syncCompletedNotifier.addListener(_onSyncCompleted);
  }

  void _onSyncCompleted() {
    _reloadMessagesFromCache();
  }

   void _cancelPendingMessage(String tempId) {
     final removed = OfflineService().removeMessageFromQueue(widget.chatId, tempId);
     if (removed) {
       setState(() {
         _messages.removeWhere((m) => m.id == tempId);
       });
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text('Отправка отменена'),
           backgroundColor: Colors.orange,
           behavior: SnackBarBehavior.floating,
           duration: Duration(seconds: 2),
         ),
       );
     }
   }

  void _showCancelPendingDialog(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.cancel, color: Colors.red),
          title: const Text('Отменить отправку', style: TextStyle(color: Colors.red)),
          onTap: () {
            Navigator.pop(context);
            _cancelPendingMessage(msg.id);
          },
        ),
      ),
    );
  }

  Future<void> _pinMessage(ChatMessage msg) async {
    final msgId = int.tryParse(msg.id);
    final chatIdToUse = _realChatId > 0 ? _realChatId : (int.tryParse(widget.chatId) ?? 0);
    if (msgId != null && chatIdToUse > 0) {
      try {
        final rawPinned = await chatService.pinMessage(chatIdToUse, msgId);
        setState(() {
          if (rawPinned.isNotEmpty) {
            _pinnedMessages = rawPinned.map((m) => ChatMessage.fromJson(m, _myUserId ?? 0)).toList();
          } else {
            if (!_pinnedMessages.any((m) => m.id == msg.id)) {
              _pinnedMessages.insert(0, msg);
            }
          }
          _currentPinnedIndex = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Сообщение закреплено')),
          );
        }
      } catch (e) {
        _showError('Не удалось закрепить сообщение: $e');
      }
    }
  }

  Future<void> _unpinMessage(ChatMessage msg) async {
    final msgId = int.tryParse(msg.id);
    final chatIdToUse = _realChatId > 0 ? _realChatId : (int.tryParse(widget.chatId) ?? 0);
    if (msgId != null && chatIdToUse > 0) {
      try {
        final rawPinned = await chatService.unpinMessage(chatIdToUse, msgId);
        setState(() {
          _pinnedMessages.removeWhere((m) => m.id == msg.id);
          if (rawPinned.isNotEmpty) {
            _pinnedMessages = rawPinned.map((m) => ChatMessage.fromJson(m, _myUserId ?? 0)).toList();
          }
          _currentPinnedIndex = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Сообщение откреплено')),
          );
        }
      } catch (e) {
        _showError('Не удалось открепить сообщение: $e');
      }
    }
  }

  Widget _buildPinnedMessagesBar(ThemeData theme) {
    if (_pinnedMessages.isEmpty) return const SizedBox.shrink();
    if (_currentPinnedIndex >= _pinnedMessages.length) {
      _currentPinnedIndex = 0;
    }
    final msg = _pinnedMessages[_currentPinnedIndex];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.pin_drop, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _scrollToMessage(msg.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Закрепленное сообщение ${_pinnedMessages.length > 1 ? "(${_currentPinnedIndex + 1} из ${_pinnedMessages.length})" : ""}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    msg.text.isNotEmpty
                        ? msg.text
                        : (msg.attachments.any((a) => a.isLocation)
                            ? '📍 Геолокация'
                            : (msg.attachments.isNotEmpty ? 'Вложение' : 'Голосовое сообщение')),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_pinnedMessages.length > 1)
            IconButton(
              icon: const Icon(Icons.navigate_next, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                setState(() {
                  _currentPinnedIndex = (_currentPinnedIndex + 1) % _pinnedMessages.length;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _unpinMessage(msg),
          ),
        ],
      ),
    );
  }

  Future<void> _reloadMessagesFromCache() async {
    final cached = await DbService.instance.getCachedMessages(_realChatId);
    final loadedMessages = <ChatMessage>[];
    if (cached != null) {
      final tempMessages = cached.map((m) => ChatMessage.fromJson(m, _myUserId ?? 0)).toList();
      loadedMessages.addAll(tempMessages.map((msg) {
        if (msg.replyTo == null && msg.replyToId != null) {
          final replyMsg = tempMessages.firstWhere(
            (m) => m.id == msg.replyToId,
            orElse: () => ChatMessage(id: msg.replyToId!, text: 'Сообщение', isOwn: false, time: ''),
          );
          return msg.copyWith(replyTo: replyMsg);
        }
        return msg;
      }).toList());
    }

    final pendingRaw = OfflineService().getPendingMessagesForChat(widget.chatId);
    final List<ChatMessage> pendingMsgs = [];
    for (var pm in pendingRaw) {
      ChatMessage? replyToMsg;
      final replyToIdStr = pm['replyToId']?.toString();
      if (replyToIdStr != null) {
        replyToMsg = loadedMessages.firstWhere(
          (m) => m.id == replyToIdStr,
          orElse: () => ChatMessage(id: replyToIdStr, text: 'Сообщение', isOwn: false, time: ''),
        );
      }
      pendingMsgs.add(ChatMessage(
        id: pm['tempId'] ?? '',
        text: pm['text'] ?? '',
        isOwn: true,
        time: pm['time'] ?? '',
        replyTo: replyToMsg,
        replyToId: replyToIdStr,
        isPending: true,
      ));
    }

    if (mounted) {
      setState(() {
        _messages = [...pendingMsgs, ...loadedMessages];
      });
    }
  }

  void _startMessagePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_realChatId == 0) return;

      try {
        final rawMessages = await chatService.getMessages(_realChatId, limit: 40);
        List<Map<String, dynamic>>? rawPinned;
        try {
          rawPinned = await chatService.getPinnedMessages(_realChatId);
        } catch (_) {}

        bool shouldSetState = false;

        // 1. Live Sync Pinned Messages
        if (rawPinned != null) {
          final freshPinned = rawPinned.map((m) => ChatMessage.fromJson(m, _myUserId ?? 0)).toList();
          bool pinnedChanged = freshPinned.length != _pinnedMessages.length;
          if (!pinnedChanged) {
            for (int i = 0; i < freshPinned.length; i++) {
              if (freshPinned[i].id != _pinnedMessages[i].id ||
                  freshPinned[i].text != _pinnedMessages[i].text ||
                  !mapEquals(freshPinned[i].reactions, _pinnedMessages[i].reactions)) {
                pinnedChanged = true;
                break;
              }
            }
          }
          if (pinnedChanged) {
            _pinnedMessages = freshPinned;
            if (_currentPinnedIndex >= _pinnedMessages.length) {
              _currentPinnedIndex = 0;
            }
            shouldSetState = true;
          }
        }

        // 2. Live Sync Messages and Reactions
        if (rawMessages != null && rawMessages.isNotEmpty) {
          for (var rawMsg in rawMessages) {
            final msgId = rawMsg['id']?.toString() ?? '';
            if (msgId.isNotEmpty && (rawMsg['deleted_at'] != null || _deletedMessageIds.contains(msgId))) {
              _deletedMessageIds.add(msgId);
              if (_messages.any((m) => m.id == msgId)) {
                _messages.removeWhere((m) => m.id == msgId);
                _pinnedMessages.removeWhere((m) => m.id == msgId);
                shouldSetState = true;
              }
            }
          }

          final activeRaw = rawMessages
              .where((m) {
                final msgId = m['id']?.toString() ?? '';
                return m['deleted_at'] == null && !_deletedMessageIds.contains(msgId);
              })
              .map((m) => Map<String, dynamic>.from(m as Map))
              .toList();

          final parsedIncoming = activeRaw.map((m) => ChatMessage.fromJson(m, _myUserId ?? 0)).toList();
          final List<ChatMessage> newMessages = [];

          for (final incoming in parsedIncoming) {
            final enriched = _enrichMessageReactions(incoming);
            final existingIndex = _messages.indexWhere((m) => m.id == enriched.id);

            if (existingIndex != -1) {
              final existing = _messages[existingIndex];
              final reactionsChanged = !mapEquals(existing.reactions, enriched.reactions);
              final contentChanged = existing.text != enriched.text ||
                  existing.isEdited != enriched.isEdited ||
                  existing.isRead != enriched.isRead ||
                  existing.transcription != enriched.transcription;

              if (reactionsChanged || contentChanged) {
                _messages[existingIndex] = existing.copyWith(
                  reactions: enriched.reactions,
                  text: enriched.text,
                  isEdited: enriched.isEdited,
                  isRead: enriched.isRead,
                  transcription: enriched.transcription,
                );
                shouldSetState = true;
                if (reactionsChanged) {
                  DbService.instance.updateMessageReactions(_realChatId, enriched.id, enriched.reactions).catchError((_) {});
                }
              }
            } else {
              if (!enriched.isDeleted && !_deletedMessageIds.contains(enriched.id)) {
                if (enriched.replyTo == null && enriched.replyToId != null) {
                  final replyMsg = [..._messages, ...parsedIncoming].firstWhere(
                    (m) => m.id == enriched.replyToId,
                    orElse: () => ChatMessage(id: enriched.replyToId!, text: 'Сообщение', isOwn: false, time: ''),
                  );
                  newMessages.add(enriched.copyWith(replyTo: replyMsg));
                } else {
                  newMessages.add(enriched);
                }
              }
            }
          }

          if (newMessages.isNotEmpty) {
            final hasOtherNewMsg = newMessages.any((m) => !m.isOwn);
            _messages.insertAll(0, newMessages);
            shouldSetState = true;
            await DbService.instance.cacheMessages(_realChatId, activeRaw);

            if (mounted && hasOtherNewMsg) {
              HapticFeedback.lightImpact();
            }
          }
        }

        if (shouldSetState && mounted) {
          setState(() {});
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.chatId == 'support') {
        _realChatId = await chatService.getSupportChatId();
      } else if (widget.chatId.startsWith('operator_')) {
        try {
          _realChatId = await chatService.getSupportChatId();
        } catch (_) {
          _realChatId = 0;
        }
      } else {
        _realChatId = int.tryParse(widget.chatId) ?? 0;
      }

      // Сначала быстро загружаем ID пользователя из локального кэша для мгновенного восстановления реакций
      try {
        final cachedMe = await OfflineService().getCache('user_me');
        if (cachedMe != null && cachedMe is Map) {
          final rawMyId = cachedMe['id'];
          _myUserId = rawMyId is num ? rawMyId.toInt() : int.tryParse(rawMyId?.toString() ?? '');
          if (_myUserId != null) {
            await _loadMyReactions();
          }
        }
      } catch (e) {
        debugPrint('Ошибка загрузки ID пользователя из кэша: $e');
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('chat_settings_$_realChatId');
        if (cached != null) {
          _chatSettings = Map<String, dynamic>.from(jsonDecode(cached));
        }
      } catch (e) {
        debugPrint('Ошибка загрузки кэшированных настроек: $e');
      }

      Map<String, dynamic>? me;
      try {
        me = await authService.getMe();
      } catch (e) {
        debugPrint('Failed to getMe: $e');
      }
      final rawMyId = me?['id'];
      _myUserId = rawMyId is num ? rawMyId.toInt() : int.tryParse(rawMyId?.toString() ?? '');

      try {
        await _loadMyReactions();
      } catch (e) {
        debugPrint('Failed to load reactions: $e');
      }

      List<dynamic> chats = [];
      try {
        chats = await chatService.getChats();
        final foundActive = chats.any((c) {
          final idVal = c['id'];
          final parsedId = idVal is num ? idVal.toInt() : int.tryParse(idVal?.toString() ?? '');
          return parsedId == _realChatId;
        });
        if (!foundActive) {
          final archivedChats = await chatService.getChats(archived: true);
          chats = [...chats, ...archivedChats];
        }
      } catch (e) {
        debugPrint('Failed to load chats: $e');
      }
      final chat = chats.firstWhere(
        (c) {
          final idVal = c['id'];
          final parsedId = idVal is num ? idVal.toInt() : int.tryParse(idVal?.toString() ?? '');
          return parsedId == _realChatId;
        },
        orElse: () => <String, dynamic>{},
      );
      _chatDetail = chat;
      _isChatArchived = chat['archived'] == true || chat['archived_at'] != null;
      _chatTitle = chat['cabinet_name'] ?? _getChatTypeName(chat['chat_type'] ?? '', chat);
      
      final rawUnread = chat['unread_count'];
      final unreadCount = rawUnread is num ? rawUnread.toInt() : (int.tryParse(rawUnread?.toString() ?? '') ?? 0);

      List<dynamic> rawMessages = [];
      try {
        rawMessages = widget.aroundId != null
            ? await chatService.getMessages(_realChatId, aroundId: widget.aroundId, limit: 100) ?? []
            : await chatService.getMessages(_realChatId, limit: 100) ?? [];
        if (rawMessages.isNotEmpty) {
          final mapped = rawMessages.map((e) => Map<String, dynamic>.from(e)).toList();
          await DbService.instance.cacheMessages(_realChatId, mapped);
        }
      } catch (e) {
        debugPrint('Failed to load messages from server, falling back to cache: $e');
        final cached = await DbService.instance.getCachedMessages(_realChatId);
        if (cached != null) {
          rawMessages = cached;
        } else {
          rethrow;
        }
      }
      final tempMessages = rawMessages
          .map((m) => ChatMessage.fromJson(m, _myUserId ?? 0))
          .where((m) => !m.isDeleted && !_deletedMessageIds.contains(m.id))
          .toList();
      final loadedMessages = tempMessages.map((msg) {
        final enriched = _enrichMessageReactions(msg);
        if (enriched.replyTo == null && enriched.replyToId != null) {
          final replyMsg = tempMessages.firstWhere(
            (m) => m.id == enriched.replyToId,
            orElse: () => ChatMessage(id: enriched.replyToId!, text: 'Сообщение', isOwn: false, time: ''),
          );
          return enriched.copyWith(replyTo: replyMsg);
        }
        return enriched;
      }).toList();

      final pendingRaw = OfflineService().getPendingMessagesForChat(widget.chatId);
      final List<ChatMessage> pendingMsgs = [];
      for (var pm in pendingRaw) {
        ChatMessage? replyToMsg;
        final replyToIdStr = pm['replyToId']?.toString();
        if (replyToIdStr != null) {
          replyToMsg = loadedMessages.firstWhere(
            (m) => m.id == replyToIdStr,
            orElse: () => ChatMessage(id: replyToIdStr, text: 'Сообщение', isOwn: false, time: ''),
          );
        }
        pendingMsgs.add(ChatMessage(
          id: pm['tempId'] ?? '',
          text: pm['text'] ?? '',
          isOwn: true,
          time: pm['time'] ?? '',
          replyTo: replyToMsg,
          replyToId: replyToIdStr,
          isPending: true,
        ));
      }

      _messages = [...pendingMsgs, ...loadedMessages];

      if (widget.aroundId != null) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            _scrollToMessage(widget.aroundId.toString());
          }
        });
      }

      try {
        final rawPinned = await chatService.getPinnedMessages(_realChatId);
        _pinnedMessages = rawPinned.map((m) => ChatMessage.fromJson(m, _myUserId ?? 0)).toList();
      } catch (e) {
        debugPrint('Ошибка загрузки закрепленных сообщений: $e');
      }

      try {
        final settings = await chatService.getChatSettings(_realChatId);
        final merged = Map<String, dynamic>.from(_chatSettings);
        settings.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            merged[key] = value;
          }
        });
        setState(() {
          _chatSettings = merged;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('chat_settings_$_realChatId', jsonEncode(merged));
      } catch (e) {
        debugPrint('Ошибка загрузки настроек чата: $e');
      }

      if (_realChatId > 0) {
        chatService.markAsRead(_realChatId).catchError((_) {});
        _startMessagePolling();

        try {
          final chats = await chatService.getChats();
          final total = chats.fold<int>(0, (sum, c) => sum + ((c['unread_count'] as num?)?.toInt() ?? 0));
          print('🔵 [ChatScreen] opened chat $_realChatId, total unread=$total');
          OfflineService().updateUnreadChatCount(total);
        } catch (e) {
          debugPrint('Failed to update chat unread count: $e');
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (unreadCount > 0 && unreadCount <= _messages.length) {
          _scrollToUnread(unreadCount - 1);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading initial data: $e');
      debugPrintStack(stackTrace: stackTrace);
      _showError('Ошибка загрузки: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _messageKeys.clear();
    _pollingTimer?.cancel();
    PreferencesService.saveLastChatId(null);
    OfflineService().syncCompletedNotifier.removeListener(_onSyncCompleted);
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

void _showError(String message) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
     }
   }

   void _enterSelectionMode(String messageId) {
     setState(() {
       _isSelectionMode = true;
       _selectedMessages.add(messageId);
     });
   }

   void _toggleMessageSelection(String messageId) {
     setState(() {
       if (_selectedMessages.contains(messageId)) {
         _selectedMessages.remove(messageId);
         if (_selectedMessages.isEmpty) {
           _isSelectionMode = false;
         }
       } else {
         _selectedMessages.add(messageId);
       }
     });
   }

   void _exitSelectionMode() {
     setState(() {
       _isSelectionMode = false;
       _selectedMessages.clear();
     });
   }

Future<void> _deleteSelectedMessages() async {
      if (_selectedMessages.isEmpty) return;
      final ownSelected = _messages.where((m) => _selectedMessages.contains(m.id) && m.isOwn).toList();
      final otherSelected = _messages.where((m) => _selectedMessages.contains(m.id) && !m.isOwn).toList();
      if (ownSelected.isEmpty) {
        _showError('Нельзя удалить чужие сообщения');
        _exitSelectionMode();
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Удалить сообщения'),
          content: Text('Удалить ${ownSelected.length} сообщение(я)?${otherSelected.isNotEmpty ? " (${otherSelected.length} чужое сообщение${otherSelected.length > 1 ? "а" : ""})" : ""}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Удалить'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final idsToDelete = <int>[];
      final stringIdsToDelete = <String>[];
      for (final msg in ownSelected) {
        final msgId = msg.id;
        stringIdsToDelete.add(msgId);
        _deletedMessageIds.add(msgId);
        final msgIdInt = int.tryParse(msgId);
        if (msgIdInt != null) {
          idsToDelete.add(msgIdInt);
        }
        if (msg.isPending) {
          OfflineService().removeMessageFromQueue(widget.chatId, msgId);
        }
      }

      final chatIdToUse = _realChatId > 0 ? _realChatId : (int.tryParse(widget.chatId) ?? 0);

      // Optimistic remove from UI immediately
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => ownSelected.any((om) => om.id == m.id));
          _pinnedMessages.removeWhere((m) => ownSelected.any((om) => om.id == m.id));
          _exitSelectionMode();
        });
      }

      // Remove from cache
      await DbService.instance.deleteCachedMessages(chatIdToUse, stringIdsToDelete);

      if (idsToDelete.isNotEmpty && chatIdToUse > 0) {
        try {
          await chatService.deleteMessages(chatIdToUse, idsToDelete);
        } catch (e) {
          debugPrint('Error deleting messages: $e');
          for (final id in stringIdsToDelete) {
            _deletedMessageIds.remove(id);
          }
          if (mounted) {
            _showError('Не удалось удалить сообщения: $e');
          }
        }
      }
    }

  Future<void> _launchURL(String urlString) async {
    String targetUrl = urlString;
    if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
      targetUrl = 'https://$targetUrl';
    }
    final uri = Uri.parse(targetUrl);
    try {
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success) {
        final fallbackSuccess = await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (!fallbackSuccess) {
          _showError('Не удалось открыть ссылку: $targetUrl');
        }
      }
    } catch (e) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (ex) {
        _showError('Ошибка при открытии ссылки: $ex');
      }
    }
  }

  Future<void> _openMapLocation(double lat, double lon) async {
    final yandexUri = Uri.parse('https://yandex.ru/maps/?pt=$lon,$lat&z=16&l=map');
    final geoUri = Uri.parse('geo:$lat,$lon?q=$lat,$lon');
    try {
      final launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        final webLaunched = await launchUrl(yandexUri, mode: LaunchMode.externalApplication);
        if (!webLaunched) {
          await launchUrl(yandexUri, mode: LaunchMode.platformDefault);
        }
      }
    } catch (_) {
      try {
        await launchUrl(yandexUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        _showError('Не удалось открыть карту: $e');
      }
    }
  }

  bool _messageMatchesQuery(ChatMessage msg, String query) {
    final q = query.toLowerCase();
    if (q.isEmpty) return false;

    if (msg.text.toLowerCase().contains(q)) return true;

    if (msg.transcription != null && msg.transcription!.toLowerCase().contains(q)) return true;

    for (final att in msg.attachments) {
      if (att.fileName.toLowerCase().contains(q)) return true;
      if (att.fileUrl != null && att.fileUrl!.toLowerCase().contains(q)) return true;
      if (att.isLocation) {
        if ('геолокация'.contains(q) || 'местоположение'.contains(q) || 'карта'.contains(q) || 'локация'.contains(q)) {
          return true;
        }
      }
    }

    final hasLocation = msg.attachments.any((a) => a.isLocation);
    if ((q == 'гео' || q == 'геолокация' || q == 'локация' || q == 'карта' || q == 'место') && hasLocation) return true;

    final cleanPath = msg.attachments.isNotEmpty 
        ? (msg.attachments.first.fileUrl ?? msg.attachments.first.localPath ?? '').toLowerCase().split('?').first
        : '';
    final hasImage = msg.attachments.isNotEmpty && (
        cleanPath.endsWith('.jpg') || cleanPath.endsWith('.jpeg') || cleanPath.endsWith('.png') ||
        cleanPath.endsWith('.gif') || cleanPath.endsWith('.webp') ||
        msg.attachments.first.fileName.toLowerCase().endsWith('.jpg') ||
        msg.attachments.first.fileName.toLowerCase().endsWith('.jpeg') ||
        msg.attachments.first.fileName.toLowerCase().endsWith('.png') ||
        msg.attachments.first.fileName.toLowerCase().endsWith('.gif') ||
        msg.attachments.first.fileName.toLowerCase().endsWith('.webp') ||
        (msg.attachments.first.mimeType?.startsWith('image/') ?? false)
    );

    final hasAudio = (msg.voiceUrl != null || msg.voicePath != null) || (
        msg.attachments.isNotEmpty && (
            cleanPath.endsWith('.mp3') || cleanPath.endsWith('.m4a') || cleanPath.endsWith('.wav') ||
            cleanPath.endsWith('.ogg') || cleanPath.endsWith('.aac') || cleanPath.endsWith('.amr') ||
            cleanPath.endsWith('.flac') ||
            msg.attachments.first.fileName.toLowerCase().endsWith('.mp3') ||
            msg.attachments.first.fileName.toLowerCase().endsWith('.m4a') ||
            msg.attachments.first.fileName.toLowerCase().endsWith('.wav') ||
            msg.attachments.first.fileName.toLowerCase().endsWith('.ogg') ||
            msg.attachments.first.fileName.toLowerCase().endsWith('.aac') ||
            msg.attachments.first.fileName.toLowerCase().endsWith('.amr') ||
            msg.attachments.first.fileName.toLowerCase().endsWith('.flac') ||
            (msg.attachments.first.mimeType?.startsWith('audio/') ?? false)
        )
    );

    final hasFile = msg.attachments.isNotEmpty && !hasImage && !hasAudio && !hasLocation;
    final hasLink = msg.text.contains(RegExp(r'https?://[^\s]+'));

    if ((q == 'фото' || q == 'photo' || q == 'картинка' || q == 'image') && hasImage) return true;
    if ((q == 'голос' || q == 'голосовое' || q == 'voice' || q == 'audio' || q == 'аудио') && hasAudio) return true;
    if ((q == 'файл' || q == 'file' || q == 'документ' || q == 'doc' || q == 'документы') && hasFile) return true;
    if ((q == 'ссылка' || q == 'link' || q == 'ссылки') && hasLink) return true;

    return false;
  }

  Widget _buildMessageTextWithLinks(String text, bool isOwn, ThemeData theme, Color textColor) {
    final linkRegex = RegExp(r'https?://[^\s]+');
    final matches = linkRegex.allMatches(text);
    final double fontSize = _chatSettings['font_size'] != null 
        ? (double.tryParse(_chatSettings['font_size'].toString()) ?? 14.0)
        : 14.0;
    
    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
        ),
      );
    }
    
    final List<InlineSpan> spans = [];
    int start = 0;
    
    final linkColor = textColor == Colors.white ? Colors.cyanAccent : const Color(0xFF054582);
    
    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
          ),
        ));
      }
      
      final urlString = match.group(0)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: () => _launchURL(urlString),
          child: Text(
            urlString,
            style: TextStyle(
              color: linkColor,
              decoration: TextDecoration.underline,
              fontSize: fontSize,
            ),
          ),
        ),
      ));
      
      start = match.end;
    }
    
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
        ),
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMoreMessages || !_hasMoreMessages) return;
    setState(() {
      _isLoadingMoreMessages = true;
    });

    try {
      int? oldestId;
      for (final m in _messages) {
        final idVal = int.tryParse(m.id);
        if (idVal != null) {
          if (oldestId == null || idVal < oldestId) {
            oldestId = idVal;
          }
        }
      }

      final rawMessages = await chatService.getMessages(_realChatId, beforeId: oldestId, limit: 100) ?? [];
      
      if (rawMessages.isEmpty) {
        setState(() {
          _hasMoreMessages = false;
        });
        return;
      }

      final tempMessages = rawMessages.map((m) {
        final msg = ChatMessage.fromJson(m, _myUserId ?? 0);
        return _enrichMessageReactions(msg);
      }).toList();
      
      setState(() {
        final existingIds = _messages.map((m) => m.id).toSet();
        for (final msg in tempMessages) {
          if (!existingIds.contains(msg.id) && !_deletedMessageIds.contains(msg.id) && !msg.isDeleted) {
            _messages.add(msg);
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading more messages: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMoreMessages = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_isChatArchived) {
      _showError('Чат перенесен в архив. Отправка сообщений недоступна.');
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty && _editingMessage == null) return;

    if (_editingMessage != null) {
      final msgId = int.tryParse(_editingMessage!.id);
      if (msgId != null) {
        try {
          await chatService.editMessage(_realChatId, msgId, text);
          setState(() {
            final index = _messages.indexWhere((m) => m.id == _editingMessage!.id);
            if (index != -1) {
              _messages[index] = _messages[index].copyWith(text: text, isEdited: true);
            }
            _editingMessage = null;
          });
        } catch (e) {
          _showError('Ошибка изменения: $e');
        }
      }
    } else {
      if (!NetworkService.isOnline) {
        final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
        final timeStr = DateFormat('HH:mm').format(DateTime.now());
        
        final tempMsg = ChatMessage(
          id: tempId,
          text: text,
          isOwn: true,
          time: timeStr,
          isPending: true,
        );
        
        final replyId = _replyTo != null ? int.tryParse(_replyTo!.id) : null;
        OfflineService().addMessageToQueue(widget.chatId, tempId, text, timeStr, replyToId: replyId);
        
        setState(() {
          _messages.insert(0, _replyTo != null ? tempMsg.copyWith(replyTo: _replyTo) : tempMsg);
          _replyTo = null;
        });
        
        _messageController.clear();
        _animateToBottom();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Нет подключения к интернету. Сообщение будет отправлено автоматически при восстановлении связи.'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      try {
        final replyId = _replyTo != null ? int.tryParse(_replyTo!.id) : null;
        final res = await chatService.sendTextMessage(_realChatId, text, replyToId: replyId);
        final isScrolledUp = _scrollController.hasClients && _scrollController.offset > 150;
        setState(() {
          final newMsg = ChatMessage.fromJson(res, _myUserId ?? 0);
          _messages.insert(0, _replyTo != null ? newMsg.copyWith(replyTo: _replyTo) : newMsg);
          _replyTo = null;
          if (isScrolledUp) {
            _unreadMessagesCount++;
          }
        });
        if (!isScrolledUp) {
          _animateToBottom();
        }
      } catch (e) {
        _showError('Ошибка отправки: $e');
      }
    }
    
    _messageController.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
    }
  }
    void _animateToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToUnread(int index) {
    if (index < 0 || index >= _messages.length) return;
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final key = _messageKeys[_messages[index].id];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          alignment: 0.5,
        );
      } else {
        if (_scrollController.hasClients) {
          final targetOffset = index * 120.0;
          _scrollController.animateTo(
            targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  void _scrollToMessage(String id) {
    final key = _messageKeys[id];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5,
      );
      _flashMessage(id);
    } else {
      final index = _messages.indexWhere((m) => m.id == id);
      if (index != -1 && _scrollController.hasClients) {
        final targetOffset = index * 100.0;
        _scrollController.animateTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        Future.delayed(const Duration(milliseconds: 350), () {
          _flashMessage(id);
        });
      } else if (index == -1) {
        final targetMsgId = int.tryParse(id);
        if (targetMsgId != null) {
          _loadMessagesAround(targetMsgId);
        }
      }
    }
  }

  Future<void> _loadMessagesAround(int targetId) async {
    if (!NetworkService.isOnline) {
      _showError('Необходим интернет для загрузки сообщения с сервера');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final raw = await chatService.getMessagesAround(
        _realChatId,
        targetId,
        limit: 30,
      );
      if (raw != null && raw.isNotEmpty) {
        final list = raw.map((m) {
          final msg = ChatMessage.fromJson(m, _myUserId ?? 0);
          return _enrichMessageReactions(msg);
        }).toList();
        
        final hasTarget = list.any((m) => m.id == targetId.toString());
        
        setState(() {
          final mergedMap = {for (var msg in [..._messages, ...list]) msg.id: msg};
          final sortedList = mergedMap.values.toList();
          sortedList.sort((a, b) {
            final aId = int.tryParse(a.id) ?? 0;
            final bId = int.tryParse(b.id) ?? 0;
            return bId.compareTo(aId);
          });
          _messages = sortedList;
          _hasMoreMessages = true;
        });

        if (hasTarget) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToMessage(targetId.toString());
          });
        } else {
          _showError('Сообщение не найдено на сервере');
        }
      } else {
        _showError('Сообщение не найдено на сервере');
      }
    } catch (e) {
      _showError('Ошибка загрузки истории сообщений: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _flashMessage(String id) {
    setState(() {
      _highlightedMessageId = id;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _highlightedMessageId == id) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _matchingIndices.clear();
      _currentMatchIndex = 0;
      if (query.isNotEmpty) {
        for (int i = 0; i < _messages.length; i++) {
          if (_messageMatchesQuery(_messages[i], query)) {
            _matchingIndices.add(i);
          }
        }
      }
      if (_matchingIndices.isNotEmpty) {
        _scrollToMatch(0);
      } else {
        _highlightedMessageId = null;
      }
    });
  }

  void _scrollToMatch(int index) {
    if (index >= 0 && index < _matchingIndices.length) {
      _currentMatchIndex = index;
      final msg = _messages[_matchingIndices[index]];
      _scrollToMessage(msg.id);
    }
  }

  void _prevMatch() {
    if (_matchingIndices.isEmpty) return;
    int nextIdx = _currentMatchIndex + 1;
    if (nextIdx >= _matchingIndices.length) {
      nextIdx = 0;
    }
    _scrollToMatch(nextIdx);
  }

  void _nextMatch() {
    if (_matchingIndices.isEmpty) return;
    int prevIdx = _currentMatchIndex - 1;
    if (prevIdx < 0) {
      prevIdx = _matchingIndices.length - 1;
    }
    _scrollToMatch(prevIdx);
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _matchingIndices.clear();
      _currentMatchIndex = 0;
      _highlightedMessageId = null;
    });
  }

  void _openSharedMedia() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SharedMediaScreen(
          chatId: widget.chatId,
          chatTitle: _chatTitle,
          messages: _messages,
          onSendEdited: (path) => _sendAttachment(path),
          onNavigateToMessage: (msgId) {
            Navigator.pop(context);
            _scrollToMessage(msgId);
          },
        ),
      ),
    );
  }

  Future<void> _openChatSettings() async {
    await Navigator.pushNamed(
      context,
      '/chat-settings/${widget.chatId}',
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('chat_settings_$_realChatId');
      if (cached != null) {
        if (mounted) {
          setState(() {
            _chatSettings = Map<String, dynamic>.from(jsonDecode(cached));
          });
        }
      }
    } catch (_) {}
    try {
      final freshSettings = await chatService.getChatSettings(_realChatId);
      if (mounted) {
        setState(() {
          final merged = Map<String, dynamic>.from(_chatSettings);
          freshSettings.forEach((key, value) {
            if (value != null && value.toString().isNotEmpty) {
              merged[key] = value;
            }
          });
          _chatSettings = merged;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMyReactions() async {
    if (_myUserId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'my_reactions_user_$_myUserId';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        setState(() {
          _myReactions.clear();
          decoded.forEach((msgId, list) {
            if (list is List) {
              _myReactions[msgId] = list.map((e) => e.toString()).toSet();
            }
          });
        });
      }
    } catch (e) {
      debugPrint('Error loading reactions: $e');
    }
  }

  Future<void> _saveMyReactions() async {
    if (_myUserId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'my_reactions_user_$_myUserId';
      final Map<String, List<String>> toEncode = {};
      _myReactions.forEach((msgId, set) {
        if (set.isNotEmpty) {
          toEncode[msgId] = set.toList();
        }
      });
      await prefs.setString(key, jsonEncode(toEncode));
    } catch (e) {
      debugPrint('Error saving reactions: $e');
    }
  }

  ChatMessage _enrichMessageReactions(ChatMessage msg) {
    final localReactions = _myReactions[msg.id];
    if (localReactions == null || localReactions.isEmpty) return msg;

    final mergedReactions = Map<String, int>.from(msg.reactions);
    for (final emoji in localReactions) {
      if (!mergedReactions.containsKey(emoji)) {
        mergedReactions[emoji] = 1;
      } else if (mergedReactions[emoji] == 0) {
        mergedReactions[emoji] = 1;
      }
    }
    return msg.copyWith(reactions: mergedReactions);
  }

  Future<void> _toggleReaction(ChatMessage msg, String emoji) async {
    final msgIdInt = int.tryParse(msg.id);
    if (msgIdInt == null) return;
    
    final alreadyReacted = _myReactions[msg.id]?.contains(emoji) ?? false;
    
    try {
      if (alreadyReacted) {
        await chatService.removeReaction(_realChatId, msgIdInt, emoji);
        setState(() {
          _myReactions[msg.id]?.remove(emoji);
          final currentCount = msg.reactions[emoji] ?? 0;
          if (currentCount <= 1) {
            msg.reactions.remove(emoji);
          } else {
            msg.reactions[emoji] = currentCount - 1;
          }
          final idx = _messages.indexWhere((m) => m.id == msg.id);
          if (idx != -1) {
            _messages[idx] = msg.copyWith(reactions: Map<String, int>.from(msg.reactions));
          }
        });
        await _saveMyReactions();
        await DbService.instance.updateMessageReactions(_realChatId, msg.id, msg.reactions).catchError((_) {});
      } else {
        await chatService.addReaction(_realChatId, msgIdInt, emoji);
        setState(() {
          _myReactions.putIfAbsent(msg.id, () => {}).add(emoji);
          final currentCount = msg.reactions[emoji] ?? 0;
          msg.reactions[emoji] = currentCount + 1;
          final idx = _messages.indexWhere((m) => m.id == msg.id);
          if (idx != -1) {
            _messages[idx] = msg.copyWith(reactions: Map<String, int>.from(msg.reactions));
          }
        });
        await _saveMyReactions();
        await DbService.instance.updateMessageReactions(_realChatId, msg.id, msg.reactions).catchError((_) {});
      }
    } catch (e) {
      _showError('Ошибка реакции: $e');
    }
  }

  Future<void> _startRecording() async {
    if (_isChatArchived) {
      _showError('Чат перенесен в архив. Отправка сообщений недоступна.');
      return;
    }
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      // In record 6.x, hasPermission() requests permission if needed
      // Show a message that user needs to press again after granting
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Разрешение на микрофон получено. Зажмите микрофон ещё раз для записи.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      HapticFeedback.mediumImpact();
      
      _recordTimer?.cancel();
      _recordDurationSeconds = 0;
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordDurationSeconds++;
          });
        } else {
          timer.cancel();
        }
      });

      setState(() {
        _isRecording = true;
        _isRecordLocked = true;
        _currentRecordingPath = path;
      });
    } catch (e) {
      _showError('Не удалось начать запись: $e');
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      await _audioRecorder.stop();
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}
    HapticFeedback.lightImpact();
    setState(() {
      _isRecording = false;
      _isRecordLocked = false;
      _recordDurationSeconds = 0;
      _currentRecordingPath = null;
    });
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isRecordLocked = false;
      _recordDurationSeconds = 0;
    });
    
    if (path != null) {
      setState(() => _isLoading = true);
      try {
        final url = await uploadService.uploadVoice(path);
        final fileName = path.split('/').last;
        final size = File(path).lengthSync();
        final atts = [{
          'file_url': url,
          'file_name': fileName,
          'file_size_bytes': size,
          'mime_type': 'audio/m4a'
        }];
        final replyId = _replyTo != null ? int.tryParse(_replyTo!.id) : null;
        final res = await chatService.sendMessageWithAttachments(_realChatId, '', atts, replyToId: replyId);
        setState(() {
          final newMsg = ChatMessage.fromJson(res, _myUserId ?? 0);
          _messages.insert(0, _replyTo != null ? newMsg.copyWith(replyTo: _replyTo) : newMsg);
          _replyTo = null;
        });
        _animateToBottom();
      } catch (e) {
        _showError('Ошибка отправки голоса: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatRecordDuration(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _downloadFile(ChatAttachment att) async {
    // 1. Если файл уже скачан локально - сразу открываем без повторного скачивания
    if (att.localPath != null && await File(att.localPath!).exists()) {
      final res = await OpenFile.open(att.localPath!);
      if (res.type != ResultType.done && mounted) {
        _showError('Не удалось открыть файл: ${res.message}');
      }
      return;
    }

    final existingPath = await FileSaveHelper.getLocalFilePath(att.fileName);
    if (existingPath != null && await File(existingPath).exists()) {
      final res = await OpenFile.open(existingPath);
      if (res.type != ResultType.done && mounted) {
        _showError('Не удалось открыть файл: ${res.message}');
      }
      return;
    }

    if (!mounted) return;
    if (att.fileUrl == null) return;

    final progressController = StreamController<double>.broadcast();
    showDownloadProgressDialog(context, att.fileName, progressController.stream);

    try {
      final bytes = await uploadService.downloadFile(
        att.fileUrl!,
        onProgress: (received, total) {
          if (total > 0) {
            progressController.add(received / total);
          }
        },
      );

      if (!mounted) return;
      Navigator.pop(context); // закрываем диалог загрузки

      final savedPath = await FileSaveHelper.saveFile(
        context: context,
        bytes: bytes,
        fileName: att.fileName,
      );

      if (!mounted) return;

      // Обновляем localPath в сообщении, если найдено
      setState(() {
        for (int i = 0; i < _messages.length; i++) {
          final msg = _messages[i];
          final attIdx = msg.attachments.indexWhere((a) => a.fileName == att.fileName);
          if (attIdx != -1) {
            final updatedAtts = List<ChatAttachment>.from(msg.attachments);
            updatedAtts[attIdx] = updatedAtts[attIdx].copyWith(localPath: savedPath);
            _messages[i] = msg.copyWith(attachments: updatedAtts);
          }
        }
      });

      final res = await OpenFile.open(savedPath);
      if (res.type != ResultType.done && mounted) {
        _showError('Не удалось открыть файл: ${res.message}');
      }
    } catch (e) {
      if (mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {}
      }
      _showError('Ошибка скачивания: $e');
    } finally {
      progressController.close();
    }
  }

  String _getMimeType(String fileName) {
    if (fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.jpeg')) return 'image/jpeg';
    if (fileName.toLowerCase().endsWith('.png')) return 'image/png';
    if (fileName.toLowerCase().endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }

  Future<bool?> _showImageQualityDialog() async {
    return await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Text(
                'Выберите качество фото',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.compress, color: Colors.blue),
              title: const Text('Сжатое качество'),
              subtitle: const Text('Быстрая отправка, экономия трафика',
                  textAlign: TextAlign.start),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.green),
              title: const Text('Исходное качество'),
              subtitle: const Text('Хорошее качество, оригинальный размер',
                  textAlign: TextAlign.start),
              onTap: () => Navigator.pop(context, false),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _sendAttachment(String path, {bool? compressOverride}) async {
    if (_isChatArchived) {
      _showError('Чат перенесен в архив. Отправка сообщений недоступна.');
      return;
    }
    final lowercase = path.toLowerCase();
    final isImage = lowercase.endsWith('.jpg') || lowercase.endsWith('.jpeg') || lowercase.endsWith('.png') || lowercase.endsWith('.webp');

    bool compress = true;
    if (isImage && compressOverride == null) {
      final choice = await _showImageQualityDialog();
      if (choice == null) return;
      compress = choice;
    } else if (compressOverride != null) {
      compress = compressOverride;
    }

    setState(() => _isLoading = true);
    try {
      final url = await uploadService.uploadAttachment(path, compress: compress);
      try {
        final bytes = await File(path).readAsBytes();
        AuthImage.cacheBytes(url, bytes);
      } catch (_) {}

      final fileName = path.split('/').last;
      final size = File(path).lengthSync();
      final atts = [
        {
          'file_url': url,
          'file_name': fileName,
          'file_size_bytes': size,
          'mime_type': _getMimeType(fileName),
        }
      ];
      final replyId = _replyTo != null ? int.tryParse(_replyTo!.id) : null;
      final res = await chatService.sendMessageWithAttachments(_realChatId, '', atts, replyToId: replyId);
      setState(() {
        final newMsg = ChatMessage.fromJson(res, _myUserId ?? 0);
        _messages.insert(0, _replyTo != null ? newMsg.copyWith(replyTo: _replyTo) : newMsg);
        _replyTo = null;
      });
      _animateToBottom();
    } catch (e) {
      _showError('Ошибка отправки файла: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editAndSendAttachment(String path) async {
    final editedBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageEditorScreen(imageFile: File(path)),
      ),
    );

    if (editedBytes != null) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(editedBytes);
      _sendAttachment(tempFile.path);
    } else {
      _sendAttachment(path);
    }
  }

  Future<void> _sendCurrentLocation() async {
    if (_isChatArchived) {
      _showError('Чат перенесен в архив. Отправка сообщений недоступна.');
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Служба геолокации отключена на устройстве. Включите GPS.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Доступ к геолокации отклонен.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Доступ к геолокации запрещен навсегда. Разрешите в настройках устройства.');
        return;
      }

      setState(() => _isLoading = true);

      // Получаем координаты (с таймаутом на случай слабого GPS-сигнала)
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        _showError('Не удалось определить текущие координаты. Попробуйте позже.');
        return;
      }

      final lat = position.latitude;
      final lon = position.longitude;

      final atts = [
        {
          'latitude': lat,
          'longitude': lon,
        }
      ];

      final replyId = _replyTo != null ? int.tryParse(_replyTo!.id) : null;
      final res = await chatService.sendMessageWithAttachments(
        _realChatId,
        '',
        atts,
        replyToId: replyId,
      );

      setState(() {
        final newMsg = ChatMessage.fromJson(res, _myUserId ?? 0);
        _messages.insert(0, _replyTo != null ? newMsg.copyWith(replyTo: _replyTo) : newMsg);
        _replyTo = null;
      });
      _animateToBottom();
    } catch (e) {
      _showError('Ошибка отправки геопозиции: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAttachment() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Colors.blue),
              title: const Text('Фото из галереи'),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final image = await picker.pickImage(source: ImageSource.gallery);
                if (image != null) _editAndSendAttachment(image.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Сделать фото'),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final image = await picker.pickImage(source: ImageSource.camera);
                if (image != null) _editAndSendAttachment(image.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on_rounded, color: Colors.redAccent),
              title: const Text('Геолокация'),
              subtitle: const Text('Отправить текущее местоположение', style: TextStyle(fontSize: 12, color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                _sendCurrentLocation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.orange),
              title: const Text('Файл'),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.pickFiles();
                if (result != null && result.files.single.path != null) {
                  _sendAttachment(result.files.single.path!);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onMessageAction(ChatMessage msg) {
    final quickEmojis = ['👍', '❤️', '🔥', '😂', '😮', '😢', '👏', '🎉'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (NetworkService.isOnline)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Реакции',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: quickEmojis.length,
                        itemBuilder: (context, idx) {
                          final emoji = quickEmojis[idx];
                          final isSelected = _myReactions[msg.id]?.contains(emoji) ?? false;
                          
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              _toggleReaction(msg, emoji);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) 
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: isSelected 
                                    ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) 
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                  ],
                ),
              ),
            if (!msg.isPending) ...[
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Ответить'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyTo = msg;
                    _editingMessage = null;
                    _focusNode.requestFocus();
                  });
                },
              ),
              Builder(
                builder: (context) {
                  final isPinned = _pinnedMessages.any((m) => m.id == msg.id);
                  return ListTile(
                    leading: Icon(isPinned ? Icons.pin_drop_outlined : Icons.pin_drop),
                    title: Text(isPinned ? 'Открепить' : 'Закрепить'),
                    onTap: () {
                      Navigator.pop(context);
                      if (isPinned) {
                        _unpinMessage(msg);
                      } else {
                        _pinMessage(msg);
                      }
                    },
                  );
                },
              ),
            ],
            if (msg.text.isNotEmpty || (msg.transcription != null && msg.transcription!.isNotEmpty))
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Копировать текст'),
                onTap: () {
                  Navigator.pop(context);
                  final textToCopy = msg.text.isNotEmpty ? msg.text : (msg.transcription ?? '');
                  Clipboard.setData(ClipboardData(text: textToCopy));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Текст скопирован в буфер обмена'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            if (!msg.isPending && msg.isOwn && msg.text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Изменить'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _editingMessage = msg;
                    _replyTo = null;
                    _messageController.text = msg.text;
                    _focusNode.requestFocus();
                  });
                },
              ),
            if (!msg.isPending)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Выбрать'),
                onTap: () {
                  Navigator.pop(context);
                  _enterSelectionMode(msg.id);
                },
              ),
            if (msg.isPending)
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Отменить отправку', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _cancelPendingMessage(msg.id);
                },
              )
            else if (msg.isOwn)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Удалить', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final msgId = int.tryParse(msg.id);
                  final chatIdToUse = _realChatId > 0 ? _realChatId : (int.tryParse(widget.chatId) ?? 0);
                  
                  _deletedMessageIds.add(msg.id);

                  // Optimistic removal from UI
                  final backupMsg = msg;
                  final backupIndex = _messages.indexOf(msg);
                  setState(() {
                    _messages.removeWhere((m) => m.id == msg.id);
                    _pinnedMessages.removeWhere((m) => m.id == msg.id);
                  });

                  // Remove from local database cache
                  await DbService.instance.deleteCachedMessage(chatIdToUse, msg.id);
                  if (msg.isPending) {
                    OfflineService().removeMessageFromQueue(widget.chatId, msg.id);
                  }

                  if (msgId != null && chatIdToUse > 0) {
                    try {
                      await chatService.deleteMessage(chatIdToUse, msgId);
                    } catch (e) {
                      debugPrint('Error deleting single message: $e');
                      _deletedMessageIds.remove(msg.id);
                      if (mounted) {
                        setState(() {
                          if (backupIndex >= 0 && backupIndex <= _messages.length) {
                            _messages.insert(backupIndex, backupMsg);
                          } else {
                            _messages.add(backupMsg);
                          }
                        });
                        _showError('Не удалось удалить сообщение: $e');
                      }
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

Widget _buildAppBarHeader() {
     if (_isSearching) {
       return Row(
         crossAxisAlignment: CrossAxisAlignment.center,
         children: [
           IconButton(
             icon: const Icon(Icons.arrow_back, color: Colors.white),
             onPressed: _stopSearch,
           ),
           Expanded(
             child: TextField(
               controller: _searchController,
               decoration: const InputDecoration(
                 hintText: 'Поиск...',
                 border: InputBorder.none,
                 hintStyle: TextStyle(color: Colors.white70),
                 filled: false,
                 fillColor: Colors.transparent,
               ),
               style: const TextStyle(color: Colors.white),
               autofocus: true,
               onChanged: _onSearchChanged,
             ),
           ),
           if (_matchingIndices.isNotEmpty) ...[
             Text(
               '${_currentMatchIndex + 1} из ${_matchingIndices.length}',
               style: const TextStyle(color: Colors.white70, fontSize: 13),
             ),
             IconButton(
               icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
               onPressed: _prevMatch,
             ),
             IconButton(
               icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
               onPressed: _nextMatch,
             ),
           ],
         ],
       );
     }

     if (_isSelectionMode) {
       return Row(
         crossAxisAlignment: CrossAxisAlignment.center,
         children: [
           IconButton(
             icon: const Icon(Icons.close, color: Colors.white),
             onPressed: _exitSelectionMode,
           ),
           Expanded(
             child: Text(
               '${_selectedMessages.length} выбрано',
               style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
               maxLines: 1,
               overflow: TextOverflow.ellipsis,
             ),
           ),
         ],
       );
     }

     return Row(
       crossAxisAlignment: CrossAxisAlignment.center,
       children: [
         IconButton(
           icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
           onPressed: () => Navigator.pop(context),
         ),
         Expanded(
           child: GestureDetector(
             behavior: HitTestBehavior.translucent,
             onTap: _openSharedMedia,
             child: Row(
               children: [
                 CircleAvatar(
                   radius: 18,
                   backgroundColor: Colors.white24,
                   child: Text(
                     _chatTitle.isNotEmpty ? _chatTitle[0].toUpperCase() : 'Ч',
                     style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                   ),
                 ),
                 const SizedBox(width: 10),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Text(
                         _chatTitle,
                         style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                       ),
                       const Text(
                         'показать материалы',
                         style: TextStyle(fontSize: 11, color: Colors.white70),
                       ),
                     ],
                   ),
                 ),
               ],
             ),
           ),
         ),
         IconButton(
           icon: const Icon(Icons.settings, color: Colors.white),
           onPressed: _openChatSettings,
         ),
         IconButton(
           icon: const Icon(Icons.search, color: Colors.white),
           onPressed: () {
             setState(() {
               _isSearching = true;
             });
           },
         ),
       ],
     );
   }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading && _messages.isEmpty) {
      return GradientScaffold(
        appBarCustomHeader: _buildAppBarHeader(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return GradientScaffold(
      appBarCustomHeader: _buildAppBarHeader(),
      body: ResponsiveContainer(
        maxWidth: 600,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 600;
            final messageMaxWidth = isDesktop ? 480.0 : MediaQuery.of(context).size.width * 0.8;
            final horizontalPadding = isDesktop ? 24.0 : 16.0;

            final wallpaperUrl = _chatSettings['wallpaper_url'];

            return Stack(
              children: [
                if (wallpaperUrl != null && wallpaperUrl.toString().isNotEmpty)
                  Positioned.fill(
                    child: wallpaperUrl.toString().startsWith('color:#')
                        ? Container(
                            color: _parseColor(wallpaperUrl.toString().replaceFirst('color:', '')) ?? Colors.transparent,
                          )
                        : Opacity(
                            opacity: 0.25,
                            child: Image.network(
                              wallpaperUrl.toString().startsWith('http')
                                  ? wallpaperUrl.toString()
                                  : '${ApiClient.baseUrl}${wallpaperUrl.toString().startsWith('/') ? '' : '/'}${wallpaperUrl.toString()}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                  ),
                Column(
                  children: [
                    _buildPinnedMessagesBar(theme),
                    _buildServiceRequestBanner(theme),
                    Expanded(
                      child: ListView.builder(
                        cacheExtent: 250, reverse: true,
                        controller: _scrollController,
                        padding: EdgeInsets.all(horizontalPadding),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final key = _messageKeys.putIfAbsent(msg.id, () => GlobalKey());

                           return KeepAliveWrapper(
                             key: ValueKey(msg.id),
                             child: _isSelectionMode
                                 ? KeyedSubtree(
                                     key: key,
                                     child: _buildMessageBubble(msg, theme, messageMaxWidth),
                                   )
                                 : SwipeToReply(
                                     onReply: () {
                                       setState(() {
                                         _replyTo = msg;
                                         _editingMessage = null;
                                         _focusNode.requestFocus();
                                       });
                                     },
                                     child: KeyedSubtree(
                                       key: key,
                                       child: _buildMessageBubble(msg, theme, messageMaxWidth),
                                     ),
                                   ),
                           );
                        },
                      ),
                    ),
                     if (_isLoading)
                       const Padding(
                         padding: EdgeInsets.all(8.0),
                         child: Center(child: CircularProgressIndicator()),
                       ),
_buildSelectionActionBar(theme),
                      SafeArea(
                        bottom: true,
                        top: false,
                        left: false,
                        right: false,
                        child: _buildInputArea(theme, horizontalPadding),
                      ),
                   ],
                ),
                if (_showScrollToBottom)
                  Positioned(
                    bottom: 76,
                    right: 16,
                    child: GestureDetector(
                      onTap: () {
                        _scrollController.animateTo(
                          0.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                        setState(() {
                          _unreadMessagesCount = 0;
                        });
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.keyboard_arrow_down, color: theme.colorScheme.primary, size: 28),
                            if (_unreadMessagesCount > 0)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$_unreadMessagesCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ).animate().scale(duration: const Duration(milliseconds: 150)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Color? _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    try {
      final hex = hexString.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return null;
    }
  }

Widget _buildMessageBubble(ChatMessage msg, ThemeData theme, double maxWidth) {
     final isHighlighted = msg.id == _highlightedMessageId;
     final isSelected = _selectedMessages.contains(msg.id);
     final customOwnColor = _parseColor(_chatSettings['own_bubble_color']);
     final customOtherColor = _parseColor(_chatSettings['other_bubble_color']);
     final customBotColor = _parseColor(_chatSettings['bot_bubble_color']);

     final isBot = !msg.isOwn && (msg.senderId == null || msg.senderId == 0);

     final bubbleColor = msg.isOwn
         ? (msg.isPending ? Colors.grey.shade500 : (customOwnColor ?? const Color(0xFF054582)))
         : (isBot
             ? (customBotColor ?? Colors.grey.shade100)
             : (customOtherColor ?? theme.colorScheme.surfaceContainerHighest));

     final textColor = bubbleColor.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
     final timeColor = textColor.withValues(alpha: 0.65);

     return RepaintBoundary(
       child: Align(
         alignment: msg.isOwn ? Alignment.centerRight : Alignment.centerLeft,
         child: GestureDetector(
           onTap: () {
             if (_isSelectionMode) {
               _toggleMessageSelection(msg.id);
             } else {
               _onMessageAction(msg);
             }
           },
            onLongPress: () {
              if (msg.isPending) {
                _showCancelPendingDialog(msg);
              } else if (_isSelectionMode) {
                _toggleMessageSelection(msg.id);
              } else {
                _onMessageAction(msg);
              }
            },
           child: ConstrainedBox(
             constraints: BoxConstraints(maxWidth: maxWidth),
             child: AnimatedContainer(
               duration: const Duration(milliseconds: 300),
               margin: const EdgeInsets.only(bottom: 12),
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 gradient: msg.isOwn && !isHighlighted && !isSelected && customOwnColor == null
                     ? (msg.isPending
                         ? LinearGradient(
                             colors: [Colors.grey.shade500, Colors.grey.shade400],
                             begin: Alignment.topLeft,
                             end: Alignment.bottomRight,
                           )
                         : const LinearGradient(
                             colors: [Color(0xFF054582), Color(0xFF0a7ac2)],
                             begin: Alignment.topLeft,
                             end: Alignment.bottomRight,
                           ))
                     : null,
                 color: isSelected
                     ? (msg.isOwn
                         ? (customOwnColor ?? const Color(0xFF054582)).withValues(alpha: 0.5)
                         : theme.colorScheme.primary.withValues(alpha: 0.2))
                     : (isHighlighted ? bubbleColor.withValues(alpha: 0.5) : bubbleColor),
                 border: isSelected
                     ? Border.all(color: theme.colorScheme.primary, width: 2.0)
                     : (isHighlighted
                         ? Border.all(color: msg.isOwn ? Colors.white : theme.colorScheme.primary, width: 2.0)
                         : null),
                 borderRadius: BorderRadius.only(
                   topLeft: const Radius.circular(20),
                   topRight: const Radius.circular(20),
                   bottomLeft: Radius.circular(msg.isOwn ? 20 : 4),
                   bottomRight: Radius.circular(msg.isOwn ? 4 : 20),
                 ),
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (msg.replyTo != null)
                          GestureDetector(
                            onTap: () => _scrollToMessage(msg.replyTo!.id),
                            child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: msg.isOwn 
                              ? Colors.white.withValues(alpha: 0.08) 
                              : theme.colorScheme.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border(
                            left: BorderSide(
                              color: msg.isOwn ? Colors.white70 : theme.colorScheme.primary,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.replyTo!.isOwn ? 'Вы' : 'Собеседник',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: msg.isOwn ? Colors.white : theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              msg.replyTo!.text.isNotEmpty
                                  ? msg.replyTo!.text
                                  : (msg.replyTo!.attachments.any((a) => a.isLocation)
                                      ? '📍 Геолокация'
                                      : 'Вложение'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: msg.isOwn ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  if (msg.attachments.isNotEmpty)
                    ...msg.attachments.map((att) {
                      final path = (att.fileUrl ?? att.localPath ?? '').toLowerCase();
                      final cleanPath = path.split('?').first;
                      final name = att.fileName.toLowerCase();
                      final isImage = cleanPath.endsWith('.jpg') || 
                                      cleanPath.endsWith('.png') || 
                                      cleanPath.endsWith('.jpeg') ||
                                      cleanPath.endsWith('.gif') ||
                                      cleanPath.endsWith('.webp') ||
                                      name.endsWith('.jpg') ||
                                      name.endsWith('.jpeg') ||
                                      name.endsWith('.png') ||
                                      name.endsWith('.gif') ||
                                      name.endsWith('.webp') ||
                                      (att.mimeType?.startsWith('image/') ?? false);
                      final isAudio = cleanPath.endsWith('.mp3') || 
                                      cleanPath.endsWith('.m4a') ||
                                      cleanPath.endsWith('.wav') ||
                                      cleanPath.endsWith('.ogg') ||
                                      cleanPath.endsWith('.aac') ||
                                      cleanPath.endsWith('.amr') ||
                                      cleanPath.endsWith('.flac') ||
                                      name.endsWith('.mp3') ||
                                      name.endsWith('.m4a') ||
                                      name.endsWith('.wav') ||
                                      name.endsWith('.ogg') ||
                                      name.endsWith('.aac') ||
                                      name.endsWith('.amr') ||
                                      name.endsWith('.flac') ||
                                      (att.mimeType?.startsWith('audio/') ?? false);
                      final isVideo = cleanPath.endsWith('.mp4') || 
                                      cleanPath.endsWith('.mov') ||
                                      cleanPath.endsWith('.avi') ||
                                      cleanPath.endsWith('.mkv') ||
                                      name.endsWith('.mp4') ||
                                      name.endsWith('.mov') ||
                                      name.endsWith('.avi') ||
                                      name.endsWith('.mkv') ||
                                      (att.mimeType?.startsWith('video/') ?? false);

                      if (isImage) {
                        final heroTag = 'image_${msg.id}_${att.fileName}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    opaque: false,
                                    barrierColor: Colors.transparent,
                                    transitionDuration: const Duration(milliseconds: 260),
                                    reverseTransitionDuration: const Duration(milliseconds: 220),
                                    pageBuilder: (context, animation, secondaryAnimation) => FullscreenImageViewer(
                                      imageUrl: att.fileUrl,
                                      localPath: att.localPath,
                                      fileName: att.fileName,
                                      heroTag: heroTag,
                                      onDownloadRequest: (url) => uploadService.downloadFile(url),
                                      onSendEdited: (editedPath) => _sendAttachment(editedPath),
                                    ),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return FadeTransition(opacity: animation, child: child);
                                    },
                                  ),
                                );
                              },
                              child: Hero(
                                tag: heroTag,
                                child: att.localPath != null
                                  ? Image.file(File(att.localPath!), fit: BoxFit.cover)
                                  : AuthImage(url: att.fileUrl!, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        );
                      } else if (isAudio) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: VoiceMessagePlayer(
                            voiceUrl: att.fileUrl,
                            voicePath: att.localPath,
                            isOwn: msg.isOwn,
                            initialTranscription: msg.transcription,
                            onDownload: () => _downloadFile(att),
                            onGetLocalAudio: () async {
                              if (att.fileUrl == null) return null;
                              try {
                                final bytes = await uploadService.downloadFile(att.fileUrl!);
                                final dir = await getTemporaryDirectory();
                                final file = File('${dir.path}/temp_${att.fileName}');
                                await file.writeAsBytes(bytes);
                                return file.path;
                              } catch (e) {
                                _showError('Ошибка загрузки аудио: $e');
                                return null;
                              }
                            },
                            onTranscribe: () async {
                              if (att.fileUrl == null) return 'Не удалось получить аудиофайл';
                              try {
                                final text = await uploadService.transcribeVoice(att.fileUrl!);
                                await DbService.instance.updateMessageTranscription(_realChatId, msg.id, text);
                                if (mounted) {
                                  setState(() {
                                    final idx = _messages.indexWhere((m) => m.id == msg.id);
                                    if (idx != -1) {
                                      _messages[idx] = _messages[idx].copyWith(transcription: text);
                                    }
                                  });
                                }
                                return text;
                              } catch (e) {
                                return 'Ошибка распознавания: $e';
                              }
                            },
                          ),
                        );
                      } else if (isVideo) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ChatVideoBubble(
                            videoUrl: att.fileUrl,
                            localPath: att.localPath,
                            fileName: att.fileName,
                            isOwn: msg.isOwn,
                            onDownload: () => _downloadFile(att),
                          ),
                        );
                      } else if (att.isLocation) {
                        final lat = att.latitude ?? 0.0;
                        final lon = att.longitude ?? 0.0;
                        final coordsText = '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _openMapLocation(lat, lon),
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: msg.isOwn
                                    ? Colors.white.withValues(alpha: 0.14)
                                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: msg.isOwn
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : theme.colorScheme.outline.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: msg.isOwn
                                              ? Colors.white.withValues(alpha: 0.2)
                                              : theme.colorScheme.primary.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.location_on_rounded,
                                          color: msg.isOwn ? Colors.white : theme.colorScheme.primary,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Геопозиция',
                                              style: TextStyle(
                                                color: msg.isOwn ? Colors.white : theme.colorScheme.onSurface,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              coordsText,
                                              style: TextStyle(
                                                color: msg.isOwn ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                                                fontSize: 12,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: msg.isOwn
                                          ? Colors.white.withValues(alpha: 0.16)
                                          : theme.colorScheme.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.map_outlined,
                                          size: 15,
                                          color: msg.isOwn ? Colors.white : theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Открыть на карте',
                                          style: TextStyle(
                                            color: msg.isOwn ? Colors.white : theme.colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else {
                        return GestureDetector(
                          onTap: () => _downloadFile(att),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.insert_drive_file, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    att.fileName,
                                    style: const TextStyle(color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  att.localPath != null ? Icons.visibility : Icons.download,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    }),

                  if (msg.voiceUrl != null || msg.voicePath != null)
                    VoiceMessagePlayer(
                      voiceUrl: msg.voiceUrl,
                      voicePath: msg.voicePath,
                      isOwn: msg.isOwn,
                      initialTranscription: msg.transcription,
                      onGetLocalAudio: () async {
                        if (msg.voiceUrl == null) return null;
                        try {
                          final bytes = await uploadService.downloadFile(msg.voiceUrl!);
                          final dir = await getTemporaryDirectory();
                          final file = File('${dir.path}/temp_voice_${msg.id}.m4a');
                          await file.writeAsBytes(bytes);
                          return file.path;
                        } catch (e) {
                          _showError('Ошибка загрузки аудио: $e');
                          return null;
                        }
                      },
                      onTranscribe: () async {
                        if (msg.voiceUrl == null) return 'Не удалось получить аудиофайл';
                        try {
                          final text = await uploadService.transcribeVoice(msg.voiceUrl!);
                          await DbService.instance.updateMessageTranscription(_realChatId, msg.id, text);
                          if (mounted) {
                            setState(() {
                              final idx = _messages.indexWhere((m) => m.id == msg.id);
                              if (idx != -1) {
                                _messages[idx] = _messages[idx].copyWith(transcription: text);
                              }
                            });
                          }
                          return text;
                        } catch (e) {
                          return 'Ошибка распознавания: $e';
                        }
                      },
                    ),

                  if (msg.text.isNotEmpty)
                    _buildMessageTextWithLinks(msg.text, msg.isOwn, theme, textColor),
                  
                  if (msg.reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: msg.reactions.entries.map((entry) {
                          final emoji = entry.key;
                          final count = entry.value;
                          final isMyReaction = _myReactions[msg.id]?.contains(emoji) ?? false;
                          
                          return GestureDetector(
                            onTap: () => _toggleReaction(msg, emoji),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isMyReaction 
                                    ? (msg.isOwn ? Colors.white.withValues(alpha: 0.25) : theme.colorScheme.primary.withValues(alpha: 0.2))
                                    : (msg.isOwn ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isMyReaction 
                                      ? (msg.isOwn ? Colors.white : theme.colorScheme.primary) 
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(emoji, style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (msg.isPending) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            'Ожидает отправки',
                            style: TextStyle(
                              fontSize: 10,
                              color: timeColor,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ] else if (msg.isEdited) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            'изменено',
                            style: TextStyle(
                              fontSize: 10,
                              color: timeColor,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        msg.time,
                        style: TextStyle(
                          fontSize: 10,
                          color: timeColor,
                        ),
                      ),
                      if (msg.isOwn) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.isPending
                              ? Icons.access_time
                              : (msg.isRead ? Icons.done_all : Icons.done),
                          size: 13,
                          color: msg.isPending
                              ? timeColor
                              : (msg.isRead ? (textColor == Colors.white ? Colors.cyanAccent : Colors.blue) : timeColor),
                        ),
                       ],
                      ],
                      ),
                    ],
                  ),
                  // Индикатор ожидания для pending-сообщений
                  if (msg.isPending)
                    Positioned(
                      top: 4,
                      right: msg.isOwn ? 4 : null,
                      left: msg.isOwn ? null : 4,
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: timeColor,
                        ),
                      ),
                    ),
                  if (isSelected)
                    Positioned(
                      top: 4,
                      left: msg.isOwn ? null : 4,
                      right: msg.isOwn ? 4 : null,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF054582),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
              ),
            ),
          ),
        ),
      );
    }

   Widget _buildSelectionActionBar(ThemeData theme) {
     if (!_isSelectionMode || _selectedMessages.isEmpty) return const SizedBox.shrink();
     return Container(
       width: double.infinity,
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
       decoration: BoxDecoration(
         color: theme.colorScheme.surfaceContainerHighest,
         border: Border(top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2))),
       ),
       child: Row(
         children: [
           Text(
             '${_selectedMessages.length} выбрано',
             style: TextStyle(
               fontSize: 14,
               fontWeight: FontWeight.w600,
               color: theme.colorScheme.onSurface,
             ),
           ),
const Spacer(),
            TextButton(
              onPressed: _exitSelectionMode,
              child: Text(
                'Отмена',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteSelectedMessages,
              tooltip: 'Удалить выбранные',
            ),
         ],
       ),
     );
   }

  Widget _buildInputArea(ThemeData theme, double padding) {
    if (_isChatArchived) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Этот чат перенесен в архив и доступен только для чтения',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: NetworkService.isOnlineNotifier,
          builder: (context, isOnline, child) {
            if (isOnline) return const SizedBox.shrink();
            return Container(
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, size: 14, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Нет интернета. Сообщения будут отправлены при восстановлении связи.',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (_replyTo != null || _editingMessage != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  _editingMessage != null ? Icons.edit : Icons.reply,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _editingMessage != null ? 'Редактирование' : 'В ответ на',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        (_editingMessage?.text ?? _replyTo?.text ?? 'Медиа'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _replyTo = null;
                      _editingMessage = null;
                      _messageController.clear();
                    });
                  },
                ),
              ],
            ),
          ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
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
          child: _isRecording
              ? Row(
                  children: [
                    if (_isRecordLocked) ...[
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: _cancelRecording,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatRecordDuration(_recordDurationSeconds),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _isRecordLocked
                          ? const Center(
                              child: Text(
                                'Запись зафиксирована',
                                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            )
                          : const Text(
                              'Отпустите для фиксации записи',
                              style: TextStyle(color: Colors.grey, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                    ),
                    if (_isRecordLocked)
                      IconButton(
                        icon: Icon(Icons.send, color: theme.colorScheme.primary),
                        onPressed: _stopAndSendRecording,
                      )
                    else
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                )
              : Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.attach_file, color: theme.colorScheme.onSurfaceVariant),
                      onPressed: _pickAttachment,
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          onChanged: (val) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Введите сообщение...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_messageController.text.trim().isNotEmpty || _editingMessage != null)
                      OfflineAwareButton(
                        onPressed: _sendMessage,
                        text: 'Отправить',
                        icon: Icons.send,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      )
                    else
                      GestureDetector(
                        onLongPressStart: (_) => _startRecording(),
                        onLongPressEnd: (_) {
                          if (!_isRecordLocked) {
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _isRecordLocked = true;
                            });
                          }
                        },
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Зажмите для записи голоса'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              Icons.mic,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildServiceRequestBanner(ThemeData theme) {
    if (_chatDetail == null || _chatDetail!['chat_type'] != 'service_request') {
      return const SizedBox.shrink();
    }

    final reqId = _chatDetail!['service_request_id'];
    final reqType = _chatDetail!['service_request_type']?.toString() ?? '';
    final reqStatus = _chatDetail!['service_request_status']?.toString() ?? '';
    final reqDesc = _chatDetail!['service_request_description']?.toString() ?? '';
    
    final statusColor = _mapRequestStatusToColor(reqStatus);
    final statusText = _mapRequestStatusToText(reqStatus);
    final typeText = _mapRequestTypeToText(reqType);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
        boxShadow: [
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
          Row(
            children: [
              Icon(Icons.assignment, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Заявка №$reqId ($typeText)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (reqDesc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              reqDesc,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, '/service-request-detail/$reqId');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Подробнее о заявке',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Icon(Icons.navigate_next, size: 14, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _mapRequestStatusToColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'in_progress':
        return const Color(0xFF054582);
      case 'closed':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  String _mapRequestStatusToText(String status) {
    switch (status) {
      case 'open':
        return 'Открыта';
      case 'in_progress':
        return 'В работе';
      case 'closed':
        return 'Закрыта';
      default:
        return status;
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
}

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragOffset = 0.0;
  double _dragStartOffset = 0.0;
  bool _thresholdReached = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _controller.addListener(() {
      setState(() {
        _dragOffset = (1.0 - _controller.value) * _dragStartOffset;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.primaryDelta!;
      if (_dragOffset > 0) _dragOffset = 0;
      if (_dragOffset < -80.0) {
        _dragOffset = -80.0;
      }

      if (_dragOffset <= -50.0) {
        if (!_thresholdReached) {
          _thresholdReached = true;
          HapticFeedback.lightImpact();
        }
      } else {
        _thresholdReached = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_thresholdReached) {
      widget.onReply();
    }
    _dragStartOffset = _dragOffset;
    _controller.forward(from: 0.0).then((_) {
      setState(() {
        _dragOffset = 0.0;
        _thresholdReached = false;
      });
    });
  }

  void _onHorizontalDragCancel() {
    _dragStartOffset = _dragOffset;
    _controller.forward(from: 0.0).then((_) {
      setState(() {
        _dragOffset = 0.0;
        _thresholdReached = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: AnimatedScale(
                scale: _thresholdReached ? 1.15 : 0.85,
                duration: const Duration(milliseconds: 150),
                child: AnimatedOpacity(
                  opacity: _dragOffset < -15.0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 100),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.reply,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(_dragOffset, 0.0),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            onHorizontalDragCancel: _onHorizontalDragCancel,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
