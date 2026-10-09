import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../theme/app_colors.dart';
import '../services/notification_service.dart';
import '../services/offline_service.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/skeletons.dart';
import '../widgets/animated_card.dart';
import '../main.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService =
      NotificationService(apiClient);
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String _error = '';
  bool _isInitialized = false;
  bool _isUnauthorized = false;
  List<String> _selectedTypeFilters = [];

  @override
  void initState() {
    super.initState();
    print('🔵 [NotificationScreen] initState вызван');
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    print(
        '🔵 [NotificationScreen] _loadNotifications вызван, refresh=$refresh, _isLoading=$_isLoading, _isUnauthorized=$_isUnauthorized');

    if (_isUnauthorized && !refresh) return;
    if (!refresh && _isInitialized && _isLoading) return;
    if (!mounted) return;

    setState(() {
      if (!refresh) _isLoading = true;
      _error = '';
      _isUnauthorized = false;
    });

    try {
      print(
          '🔵 [NotificationScreen] Вызов _notificationService.getNotifications()');

      final response = await _notificationService
          .getNotifications(
        types: _selectedTypeFilters.isEmpty ? null : _selectedTypeFilters,
        page: 1,
        size: 50,
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Превышено время ожидания загрузки уведомлений');
        },
      );

      print('✅ [NotificationScreen] Ответ получен');

      if (!mounted) return;

      final items = response['items'] as List? ?? [];
      print('📊 [NotificationScreen] Количество элементов: ${items.length}');

      final notifications = items
          .map<NotificationItem>((json) => NotificationItem.fromJson(json))
          .toList();

      setState(() {
        _notifications = notifications;
        _isLoading = false;
        _isInitialized = true;
        _error = '';
        _isUnauthorized = false;
      });

      final unreadCount = _notifications.where((n) => !n.isRead).length;
      OfflineService().updateUnreadNotificationCount(unreadCount);
      print(
          '✅ [NotificationScreen] Загрузка завершена, уведомлений: ${notifications.length}, непрочитанных: $unreadCount');
    } on DioException catch (e) {
      print('❌ [NotificationScreen] DioException: ${e.type} - ${e.message}');
      if (!mounted) return;

      if (e.response?.statusCode == 401) {
        setState(() {
          _error = 'Сессия истекла. Войдите заново.';
          _isLoading = false;
          _isInitialized = true;
          _isUnauthorized = true;
        });
        _showError(_error);
        return;
      }

      setState(() {
        _error = _getErrorDetail(e);
        _isLoading = false;
        _isInitialized = true;
        _isUnauthorized = false;
      });
      _showError(_error);
    } on TimeoutException catch (e) {
      print('❌ [NotificationScreen] TimeoutException: ${e.message}');
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Превышено время ожидания';
        _isLoading = false;
        _isInitialized = true;
        _isUnauthorized = false;
      });
      _showError(_error);
    } catch (e) {
      print('❌ [NotificationScreen] Неизвестная ошибка: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки: $e';
        _isLoading = false;
        _isInitialized = true;
        _isUnauthorized = false;
      });
      _showError(_error);
    }
  }

  Future<void> _onRefresh() async {
    print('🔄 [NotificationScreen] _onRefresh вызван');

    if (_isUnauthorized) {
      _loadNotifications(refresh: true);
      return;
    }

    try {
      final response = await _notificationService
          .getNotifications(
        types: _selectedTypeFilters.isEmpty ? null : _selectedTypeFilters,
        page: 1,
        size: 50,
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Превышено время ожидания');
        },
      );

      if (!mounted) return;

      final items = response['items'] as List? ?? [];
      final notifications = items
          .map<NotificationItem>((json) => NotificationItem.fromJson(json))
          .toList();

      setState(() {
        _notifications = notifications;
        _error = '';
        _isUnauthorized = false;
      });

      final unreadCount = _notifications.where((n) => !n.isRead).length;
      OfflineService().updateUnreadNotificationCount(unreadCount);
    } on DioException catch (e) {
      if (!mounted) return;

      if (e.response?.statusCode == 401) {
        setState(() {
          _error = 'Сессия истекла. Войдите заново.';
          _isUnauthorized = true;
        });
        _showError(_error);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка обновления: ${_getErrorDetail(e)}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка обновления: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _changeFilter(List<String> types) {
    print('🔵 [NotificationScreen] Смена фильтра на: $types');
    setState(() {
      _selectedTypeFilters = types;
      _isLoading = true;
      _isInitialized = false;
    });
    _loadNotifications(refresh: true);
  }

  Future<void> _markAsRead(NotificationItem notification) async {
    if (_isUnauthorized) {
      _showError('Сначала войдите в систему');
      return;
    }

    try {
      final success = await _notificationService
          .markAsRead(notification.id)
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (!success) {
        // 404 - уведомление не найдено, обновляем список
        _loadNotifications(refresh: true);
        return;
      }

      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = notification.copyWith(isRead: true);
        }
      });
      final unreadCount = _notifications.where((n) => !n.isRead).length;
      OfflineService().updateUnreadNotificationCount(unreadCount);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        setState(() {
          _error = 'Сессия истекла. Войдите заново.';
          _isUnauthorized = true;
        });
        _showError(_error);
        return;
      }
      _showError('Ошибка: ${e.toString()}');
    }
  }

  Future<void> _handleNotificationTap(NotificationItem notification) async {
    if (!notification.isRead) {
      _markAsRead(notification);
    }
    final data = Map<String, dynamic>.from(notification.data ?? {});
    if (notification.type != null && !data.containsKey('type')) {
      data['type'] = notification.type;
    }
    handleNotificationNavigation(data);
  }

  Future<void> _markAllAsRead() async {
    if (_isUnauthorized) {
      _showError('Сначала войдите в систему');
      return;
    }

    try {
      await _notificationService
          .markAllAsRead()
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      setState(() {
        _notifications = _notifications
            .map<NotificationItem>((n) => n.copyWith(isRead: true))
            .toList();
      });
      OfflineService().updateUnreadNotificationCount(0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Все уведомления прочитаны'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        setState(() {
          _error = 'Сессия истекла. Войдите заново.';
          _isUnauthorized = true;
        });
        _showError(_error);
        return;
      }
      _showError('Ошибка: ${_getErrorDetail(e)}');
    } catch (e) {
      _showError('Ошибка: ${e.toString()}');
    }
  }

  Future<void> _deleteAllNotifications() async {
    if (_isUnauthorized) {
      _showError('Сначала войдите в систему');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить все уведомления?'),
        content: const Text('Все уведомления будут безвозвратно удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Очистить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _notificationService
          .deleteAllNotifications()
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      setState(() {
        _notifications.clear();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Все уведомления удалены'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      OfflineService().updateUnreadNotificationCount(0);
      _loadNotifications(refresh: true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (e.response?.statusCode == 401) {
        setState(() {
          _error = 'Сессия истекла. Войдите заново.';
          _isUnauthorized = true;
        });
        _showError(_error);
        return;
      }
      _showError('Ошибка: ${_getErrorDetail(e)}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showError('Ошибка: ${e.toString()}');
    }
  }

  String _getErrorDetail(DioException e) {
    if (e.response?.statusCode == 401) {
      return 'Сессия истекла. Войдите заново.';
    }
    if (e.response?.statusCode == 500) {
      return 'Ошибка на сервере. Попробуйте позже.';
    }
    if (e.response?.data is Map && e.response?.data['detail'] != null) {
      return e.response!.data['detail'];
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Превышено время ожидания ответа от сервера';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Нет соединения с интернетом';
    }
    return 'Ошибка загрузки уведомлений';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _navigateToAuth() {
    Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
  }

  String _formatTime(DateTime? createdAt) {
    if (createdAt == null) return 'Нет даты';
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин. назад';
    if (diff.inDays < 1) return '${diff.inHours} ч. назад';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    return '${createdAt.day}.${createdAt.month}';
  }

@override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBarTitle: 'Уведомления',
      appBarAction: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          if (_notifications.any((n) => !n.isRead) && !_isUnauthorized)
            TextButton(
              onPressed: _isLoading ? null : _markAllAsRead,
              child: const Text(
                'Прочитать всё',
                style: TextStyle(color: Colors.white),
              ),
            ),
          if (_notifications.isNotEmpty && !_isUnauthorized)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              tooltip: 'Очистить все',
              onPressed: _isLoading ? null : _deleteAllNotifications,
            ),
          PopupMenuButton<List<String>>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: _changeFilter,
            tooltip: 'Фильтр по типу',
            itemBuilder: (context) => [
              const PopupMenuItem<List<String>>(
                value: [],
                child: Row(
                  children: [
                    Icon(Icons.all_inbox, size: 18),
                    SizedBox(width: 8),
                    Text('Все'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: [],
                child: Divider(height: 1),
              ),
              const PopupMenuItem<List<String>>(
                value: ['chat_message'],
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble, size: 18),
                    SizedBox(width: 8),
                    Text('Сообщения'),
                  ],
                ),
              ),
              const PopupMenuItem<List<String>>(
                value: ['request_status'],
                child: Row(
                  children: [
                    Icon(Icons.support_agent, size: 18),
                    SizedBox(width: 8),
                    Text('Заявки ТО'),
                  ],
                ),
              ),
              const PopupMenuItem<List<String>>(
                value: ['reclamation', 'reclamations'],
                child: Row(
                  children: [
                    Icon(Icons.assignment_late_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Рекламации'),
                  ],
                ),
              ),
              const PopupMenuItem<List<String>>(
                value: ['warranty_expiring'],
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 18),
                    SizedBox(width: 8),
                    Text('Гарантия'),
                  ],
                ),
              ),
              const PopupMenuItem<List<String>>(
                value: ['promotional'],
                child: Row(
                  children: [
                    Icon(Icons.campaign, size: 18),
                    SizedBox(width: 8),
                    Text('Реклама'),
                  ],
                ),
              ),
              const PopupMenuItem<List<String>>(
                value: ['operator_requested'],
                child: Row(
                  children: [
                    Icon(Icons.person_add, size: 18),
                    SizedBox(width: 8),
                    Text('Оператор'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: [],
                child: Divider(height: 1),
              ),
              const PopupMenuItem<List<String>>(
                value: [
                  'chat_message',
                  'request_status',
                  'reclamation',
                  'reclamations',
                  'warranty_expiring',
                  'promotional',
                  'operator_requested',
                ],
                child: Row(
                  children: [
                    Icon(Icons.checklist, size: 18),
                    SizedBox(width: 8),
                    Text('Все типы'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && !_isInitialized) {
      return const SkeletonList();
    }

    if (_error.isNotEmpty && _isUnauthorized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Сессия истекла',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _navigateToAuth,
                icon: const Icon(Icons.login),
                label: const Text('Войти заново'),
              ),
            ],
          ),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Ошибка загрузки',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _loadNotifications(refresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Попробовать снова'),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty && _isInitialized) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF0a7ac2),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildEmptyState(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF0a7ac2),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationCard(notification);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedTypeFilters.isNotEmpty
                ? 'Нет уведомлений этого типа'
                : 'Нет уведомлений',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Потяните вниз для обновления',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;

    return AnimatedCard(
      index: 0,
      onTap: _isUnauthorized ? null : () => _handleNotificationTap(notification),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isUnread
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getIconForType(notification.type),
              color: isUnread ? Colors.white : theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatTime(notification.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontSize: 11,
                      ),
                    ),
                    if (notification.type != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getTypeLabel(notification.type!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isUnread)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'reclamation':
      case 'reclamations':
        return Icons.assignment_late_outlined;
      case 'warranty_expiring':
        return Icons.warning_amber;
      case 'chat_message':
        return Icons.chat_bubble;
      case 'request_status':
        return Icons.support_agent;
      case 'promotional':
        return Icons.campaign;
      case 'operator_requested':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'reclamation':
      case 'reclamations':
        return 'Рекламация';
      case 'warranty_expiring':
        return 'Гарантия';
      case 'chat_message':
        return 'Сообщение';
      case 'request_status':
        return 'Заявка ТО';
      case 'promotional':
        return 'Реклама';
      case 'operator_requested':
        return 'Оператор';
      default:
        return type;
    }
  }
}









