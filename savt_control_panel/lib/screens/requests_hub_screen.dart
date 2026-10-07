// lib/screens/requests_hub_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_colors.dart';
import '../models/reclamations.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/skeletons.dart';
import '../widgets/animated_card.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/keep_alive_wrapper.dart';
import '../main.dart'; // serviceRequestService, reclamationsService
import 'service_request_screen.dart';
import 'service_request_detail_screen.dart';
import 'create_reclamation_screen.dart';
import 'reclamation_detail_screen.dart';

class RequestsHubScreen extends StatefulWidget {
  final int initialTab;
  const RequestsHubScreen({super.key, this.initialTab = 0});

  @override
  State<RequestsHubScreen> createState() => _RequestsHubScreenState();
}

class _RequestsHubScreenState extends State<RequestsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchExpanded = false;
  String _searchQuery = '';
  Timer? _searchDebounce;
  Timer? _autoRefreshTimer;

  // Tab 0: Сервисное обслуживание
  List<Map<String, dynamic>> _serviceRequests = [];
  bool _isLoadingService = true;
  String _serviceFilter = 'Все';
  final List<Map<String, String>> _serviceStatusFilters = [
    {'value': 'Все', 'label': 'Все'},
    {'value': 'open', 'label': 'Открыта'},
    {'value': 'in_progress', 'label': 'В работе'},
    {'value': 'closed', 'label': 'Закрыта'},
  ];

  // Tab 1: Рекламации
  List<ReclamationsItem> _reclamations = [];
  bool _isLoadingReclamations = true;
  String _reclamationFilter = 'Все';
  final List<Map<String, String>> _reclamationStatusFilters = [
    {'value': 'Все', 'label': 'Все'},
    {'value': 'review', 'label': 'На рассмотрении'},
    {'value': 'in_progress', 'label': 'В работе'},
    {'value': 'resolved', 'label': 'Исполнено'},
    {'value': 'rejected', 'label': 'Отклонена'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _loadServiceRequests();
    _loadReclamations();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadServiceRequests(silent: true);
        _loadReclamations(silent: true);
      }
    });
  }

  Future<void> _loadServiceRequests({bool silent = false}) async {
    if (!silent) setState(() => _isLoadingService = true);
    try {
      final data = await serviceRequestService.getServiceRequests(page: 1, size: 100);
      if (mounted) {
        setState(() {
          _serviceRequests = List<Map<String, dynamic>>.from(data['items'] ?? []);
          _isLoadingService = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _isLoadingService = false);
      }
    }
  }

  Future<void> _loadReclamations({bool silent = false}) async {
    if (!silent) setState(() => _isLoadingReclamations = true);
    try {
      final statusParam = _reclamationFilter == 'Все' ? null : _reclamationFilter;
      final data = await reclamationsService.getReclamations(
        status: statusParam,
        page: 1,
        size: 100,
      );
      if (mounted) {
        final List raw = data['items'] ?? [];
        setState(() {
          _reclamations = raw
              .map((i) => ReclamationsItem.fromJson(Map<String, dynamic>.from(i)))
              .toList();
          _isLoadingReclamations = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _isLoadingReclamations = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredServiceRequests {
    var list = _serviceRequests;
    if (_serviceFilter != 'Все') {
      list = list.where((r) => r['status'] == _serviceFilter).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        final num = (r['cabinet_object_number'] ?? '').toString().toLowerCase();
        final desc = (r['description'] ?? '').toString().toLowerCase();
        final id = (r['id'] ?? '').toString().toLowerCase();
        return num.contains(q) || desc.contains(q) || id.contains(q);
      }).toList();
    }
    return list;
  }

  List<ReclamationsItem> get _filteredReclamations {
    var list = _reclamations;
    if (_reclamationFilter != 'Все') {
      list = list.where((r) => r.status == _reclamationFilter).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        final num = (r.cabinetObjectNumber ?? '').toLowerCase();
        final desc = r.description.toLowerCase();
        final objType = r.objectTypeLabel.toLowerCase();
        return num.contains(q) || desc.contains(q) || objType.contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isServiceTab = _tabController.index == 0;

    return GradientScaffold(
      appBarTitle: 'Заявки',
      appBarAction: IconButton(
        icon: Icon(_isSearchExpanded ? Icons.close : Icons.search, color: Colors.white),
        tooltip: _isSearchExpanded ? 'Закрыть поиск' : 'Поиск',
        onPressed: () {
          setState(() {
            _isSearchExpanded = !_isSearchExpanded;
            if (!_isSearchExpanded) {
              _searchQuery = '';
              _searchController.clear();
            }
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
      body: ResponsiveContainer(
        maxWidth: 600,
        child: Column(
          children: [
            // Разворачиваемый поиск
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: _isSearchExpanded
                  ? const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xs)
                  : EdgeInsets.zero,
              child: _isSearchExpanded ? _buildSearchField(theme) : const SizedBox.shrink(),
            ),

            // Таб-переключатель в стиле Базы Знаний
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorColor: theme.colorScheme.primary,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Обслуживание'),
                  Tab(text: 'Рекламации'),
                ],
              ),
            ),

            // Чипы статусов
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: isServiceTab ? _buildServiceFilterChips(theme) : _buildReclamationFilterChips(theme),
            ),

            // Список карточек
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  KeepAliveWrapper(child: _buildServiceRequestsTab(theme)),
                  KeepAliveWrapper(child: _buildReclamationsTab(theme)),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: isServiceTab ? 'requests_hub_service_fab' : 'requests_hub_reclamation_fab',
        onPressed: () async {
          if (isServiceTab) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ServiceRequestScreen()),
            );
            if (mounted) _loadServiceRequests();
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateReclamationScreen()),
            );
            if (mounted) _loadReclamations();
          }
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: Text(
          isServiceTab ? 'Новая заявка' : 'Подать рекламацию',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (val) {
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _searchQuery = val);
          });
        },
        decoration: InputDecoration(
          hintText: 'Поиск по номеру ШУ или описанию...',
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildServiceFilterChips(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _serviceStatusFilters.map((f) {
          final isSelected = _serviceFilter == f['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f['label']!),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _serviceFilter = f['value']!);
              },
              backgroundColor: theme.colorScheme.surfaceContainerLow,
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReclamationFilterChips(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _reclamationStatusFilters.map((f) {
          final isSelected = _reclamationFilter == f['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f['label']!),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _reclamationFilter = f['value']!);
              },
              backgroundColor: theme.colorScheme.surfaceContainerLow,
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildServiceRequestsTab(ThemeData theme) {
    if (_isLoadingService) {
      return const SkeletonList();
    }

    final items = _filteredServiceRequests;
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_turned_in_outlined,
        title: 'Заявок на обслуживание нет',
        subtitle: 'Нажмите кнопку ниже, чтобы оформить заявку на ТО или ремонт шкафа',
        onRefresh: () => _loadServiceRequests(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadServiceRequests(),
      color: theme.colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildServiceRequestCard(theme, item, index);
        },
      ),
    );
  }

  Future<void> _openServiceRequestChat(Map<String, dynamic> item) async {
    dynamic chatId = item['chat_id'];
    final reqId = item['id'];

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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceRequestDetailScreen(requestId: reqId.toString()),
          ),
        );
      }
    }
  }

  Widget _buildServiceRequestCard(ThemeData theme, Map<String, dynamic> item, int index) {
    final status = (item['status'] ?? '').toString();
    final statusColor = _getServiceStatusColor(status);
    final statusText = _getServiceStatusText(status);
    final shuNum = item['cabinet_object_number']?.toString();
    final desc = item['description']?.toString() ?? 'Без описания';
    final type = _getServiceTypeText(item['request_type']?.toString() ?? '');
    final date = _formatDate(item['created_at']?.toString());

    return AnimatedCard(
      index: index,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () => _openServiceRequestChat(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.chat_bubble_outline, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                'Чат',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                date,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.devices_other, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                shuNum != null && shuNum.isNotEmpty ? 'ШУ № $shuNum' : 'Шкаф управления',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (type.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text('•', style: TextStyle(color: theme.colorScheme.outline)),
                const SizedBox(width: 8),
                Text(type, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReclamationsTab(ThemeData theme) {
    if (_isLoadingReclamations) {
      return const SkeletonList();
    }

    final items = _filteredReclamations;
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_late_outlined,
        title: 'Рекламаций нет',
        subtitle: 'Вы можете подать гарантийную рекламацию с помощью кнопки ниже',
        onRefresh: () => _loadReclamations(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadReclamations(),
      color: theme.colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildReclamationCard(theme, item, index);
        },
      ),
    );
  }

  Widget _buildReclamationCard(ThemeData theme, ReclamationsItem item, int index) {
    final statusColor = item.statusColor;
    final statusText = item.statusLabel;
    final date = _formatDate(item.createdAt.toIso8601String());

    return AnimatedCard(
      index: index,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReclamationDetailScreen(reclamationId: item.id)),
        );
        _loadReclamations(silent: true);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.warrantyClassification == true) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Гарантия',
                    style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                date,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(item.objectTypeIcon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                item.cabinetObjectNumber != null && item.cabinetObjectNumber!.isNotEmpty
                    ? 'ШУ № ${item.cabinetObjectNumber}'
                    : item.objectTypeLabel,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.objectTypeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<void> Function() onRefresh,
  }) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 56, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getServiceStatusColor(String status) {
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

  String _getServiceStatusText(String status) {
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

  String _getServiceTypeText(String type) {
    switch (type) {
      case 'repair':
        return 'Ремонт';
      case 'diagnostics':
        return 'Диагностика';
      case 'remote_adjustment':
        return 'Удаленная наладка';
      case 'onsite_adjustment':
        return 'Выездная наладка';
      case 'maintenance':
        return 'Обслуживание';
      default:
        return type;
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}
