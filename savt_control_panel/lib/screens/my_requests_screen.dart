// lib/screens/my_requests_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/skeletons.dart';
import '../widgets/bottom_nav_bar.dart';
import '../main.dart'; // serviceRequestService

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  String _selectedFilter = 'Все';
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  final List<String> _statusFilters = ['Все', 'open', 'in_progress', 'closed'];

  @override
  void initState() {
    super.initState();
    _loadRequests();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadRequestsSilent();
      }
    });
  }

  Future<void> _loadRequestsSilent() async {
    try {
      final data =
          await serviceRequestService.getServiceRequests(page: 1, size: 100);
      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(data['items']);
        });
      }
    } catch (e) {
      debugPrint('Ошибка авто-обновления заявок: $e');
    }
  }

  Future<void> _onRefresh() async {
    try {
      final data =
          await serviceRequestService.getServiceRequests(page: 1, size: 100);
      setState(() {
        _requests = List<Map<String, dynamic>>.from(data['items']);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка обновления: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final data =
          await serviceRequestService.getServiceRequests(page: 1, size: 100);
      setState(() {
        _requests = List<Map<String, dynamic>>.from(data['items']);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Ошибка загрузки: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    var filtered = _requests;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((req) {
        final cabinetId =
            req['cabinet_object_number']?.toString().toLowerCase() ?? '';
        final desc = req['description']?.toString().toLowerCase() ?? '';
        return cabinetId.contains(query) || desc.contains(query);
      }).toList();
    }
    if (_selectedFilter != 'Все') {
      filtered =
          filtered.where((req) => req['status'] == _selectedFilter).toList();
    }
    return filtered;
  }

  String _statusText(String status) {
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

  Color _statusColor(String status) {
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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'open':
        return Icons.visibility;
      case 'in_progress':
        return Icons.build;
      case 'closed':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _requestTypeText(String type) {
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
      case 'other':
        return 'Другое';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GradientScaffold(
      appBarTitle: 'Мои заявки',
      appBarAction: IconButton(
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
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding:
                _isSearchExpanded ? const EdgeInsets.all(16) : EdgeInsets.zero,
            child: _isSearchExpanded
                ? _buildSearchField()
                : const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/reclamations'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.assignment_late_outlined,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Рекламации и гарантийные случаи',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        size: 14, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
          _buildFilterChips(),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const SkeletonList()
                : RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: const Color(0xFF0a7ac2),
                    child: _filteredRequests.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.5,
                                child: _buildEmptyState(),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredRequests.length,
                            itemBuilder: (context, index) =>
                                _buildRequestCard(_filteredRequests[index], index),
                          ),
                  ),
          ),
        ],
      ),
      bottomNavBar: BottomNavBar(currentIndex: 3, onTap: _onNavTapped),
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
          hintText: 'Поиск по заявкам...',
          prefixIcon: Icon(Icons.search,
              color: theme.colorScheme.onSurfaceVariant, size: 24),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _statusFilters.map((filter) {
          final isSelected = _selectedFilter == filter;
          final displayName = filter == 'Все' ? 'Все' : _statusText(filter);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(displayName),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedFilter = filter),
              selectedColor: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 1.5),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _openServiceRequestChat(Map<String, dynamic> req) async {
    dynamic chatId = req['chat_id'];
    final reqId = req['id'];

    if (chatId != null) {
      if (mounted) {
        Navigator.pushNamed(context, '/chat/$chatId');
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      if (reqId != null) {
        final parsedId = int.tryParse(reqId.toString()) ?? 0;
        final detail = await serviceRequestService.getServiceRequestDetail(parsedId);
        chatId = detail['chat_id'];

        if (chatId == null) {
          final chats = await chatService.getChats(chatType: 'service_request');
          final match = chats.firstWhere(
            (c) => c['service_request_id']?.toString() == reqId.toString(),
            orElse: () => <String, dynamic>{},
          );
          chatId = match['id'];
        }
      }
    } catch (e) {
      debugPrint('Ошибка поиска чата заявки $reqId: $e');
    } finally {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }

    if (mounted) {
      if (chatId != null) {
        Navigator.pushNamed(context, '/chat/$chatId');
      } else if (reqId != null) {
        Navigator.pushNamed(
          context,
          '/service-request-detail/$reqId',
          arguments: req,
        );
      }
    }
  }

  Widget _buildRequestCard(Map<String, dynamic> req, int index) {
    final theme = Theme.of(context);
    final status = req['status'] as String;
    final statusColor = _statusColor(status);
    final statusIcon = _statusIcon(status);
    final requestType = req['request_type'] as String;

    return GestureDetector(
      onTap: () => _openServiceRequestChat(req),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.build, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_requestTypeText(requestType),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('ШУ: ${req['cabinet_object_number']}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(req['description'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(_statusText(status),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(_formatDate(req['created_at']),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final date = DateTime.parse(iso);
      return '${date.day}.${date.month}.${date.year}';
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
          Icon(Icons.inbox_outlined,
              size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('Нет заявок',
              style: theme.textTheme.bodyLarge
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
        Navigator.pushReplacementNamed(context, '/chats');
        break;
      case 3:
        break;
    }
  }
}
