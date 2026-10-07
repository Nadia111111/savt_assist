import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_scaffold.dart';
import '../models/reclamations.dart';
import '../widgets/skeletons.dart';
import '../main.dart'; // reclamationsService

class ReclamationsListScreen extends StatefulWidget {
  const ReclamationsListScreen({super.key});

  @override
  State<ReclamationsListScreen> createState() => _ReclamationsListScreenState();
}

class _ReclamationsListScreenState extends State<ReclamationsListScreen> {
  String _selectedFilter = 'Все';
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();

  List<ReclamationsItem> _reclamations = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  final List<String> _statusFilters = [
    'Все',
    'new',
    'review',
    'in_progress',
    'resolved',
    'rejected',
    'invalid',
  ];

  @override
  void initState() {
    super.initState();
    _loadReclamations();
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
        _loadReclamationsSilent();
      }
    });
  }

  Future<void> _loadReclamationsSilent() async {
    try {
      final statusParam = _selectedFilter == 'Все' ? null : _selectedFilter;
      final data = await reclamationsService.getReclamations(
        status: statusParam,
        page: 1,
        size: 50,
      );
      if (mounted) {
        final List rawItems = data['items'] ?? [];
        setState(() {
          _reclamations = rawItems
              .map((i) => ReclamationsItem.fromJson(Map<String, dynamic>.from(i)))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Ошибка авто-обновления рекламаций: $e');
    }
  }

  Future<void> _onRefresh() async {
    try {
      final statusParam = _selectedFilter == 'Все' ? null : _selectedFilter;
      final data = await reclamationsService.getReclamations(
        status: statusParam,
        page: 1,
        size: 50,
      );
      if (mounted) {
        final List rawItems = data['items'] ?? [];
        setState(() {
          _reclamations = rawItems
              .map((i) => ReclamationsItem.fromJson(Map<String, dynamic>.from(i)))
              .toList();
        });
      }
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

  Future<void> _loadReclamations() async {
    setState(() => _isLoading = true);
    try {
      final statusParam = _selectedFilter == 'Все' ? null : _selectedFilter;
      final data = await reclamationsService.getReclamations(
        status: statusParam,
        page: 1,
        size: 50,
      );
      if (mounted) {
        final List rawItems = data['items'] ?? [];
        setState(() {
          _reclamations = rawItems
              .map((i) => ReclamationsItem.fromJson(Map<String, dynamic>.from(i)))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  List<ReclamationsItem> get _filteredReclamations {
    var filtered = _reclamations;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((req) {
        final desc = req.description.toLowerCase();
        final objNum = req.cabinetObjectNumber?.toLowerCase() ?? '';
        return desc.contains(query) || objNum.contains(query);
      }).toList();
    }
    if (_selectedFilter != 'Все') {
      filtered = filtered.where((req) => req.status == _selectedFilter).toList();
    }
    return filtered;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBarTitle: 'Рекламации',
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
                _searchFocusNode.requestFocus();
              }
            });
          } else {
            FocusScope.of(context).unfocus();
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.pushNamed(context, '/create-reclamation');
          if (res == true && mounted) {
            _loadReclamations();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Подать рекламацию'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: _isSearchExpanded
                ? const EdgeInsets.fromLTRB(16, 12, 16, 4)
                : EdgeInsets.zero,
            child: _isSearchExpanded
                ? _buildSearchField()
                : const SizedBox.shrink(),
          ),
          _buildFilterChips(),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const SkeletonList()
                : RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: const Color(0xFF0a7ac2),
                    child: _filteredReclamations.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.5,
                                child: _buildEmptyState(),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                            itemCount: _filteredReclamations.length,
                            itemBuilder: (context, index) =>
                                _buildReclamationCard(
                                    _filteredReclamations[index], index),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    final theme = Theme.of(context);
    return TextField(
      focusNode: _searchFocusNode,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, size: 20),
        hintText: 'Поиск по номеру, описанию...',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final theme = Theme.of(context);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _statusFilters.map((filter) {
          final isSelected = _selectedFilter == filter;
          String displayName;
          switch (filter) {
            case 'new':
              displayName = 'Новая';
              break;
            case 'review':
              displayName = 'На рассмотрении';
              break;
            case 'in_progress':
              displayName = 'В работе';
              break;
            case 'resolved':
              displayName = 'Исполнена';
              break;
            case 'rejected':
              displayName = 'Отклонена';
              break;
            case 'invalid':
              displayName = 'Оформлена некорректно';
              break;
            default:
              displayName = 'Все';
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(displayName),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedFilter = filter);
                _loadReclamations();
              },
              selectedColor: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReclamationCard(ReclamationsItem item, int index) {
    final theme = Theme.of(context);
    final statusColor = item.statusColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.pushNamed(
              context,
              '/reclamation-detail/${item.id}',
            );
            _loadReclamationsSilent();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.objectTypeIcon,
                          color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.objectType == 'cabinet' &&
                                          item.cabinetObjectNumber != null &&
                                          item.cabinetObjectNumber!.isNotEmpty
                                      ? 'ШУ № ${item.cabinetObjectNumber}'
                                      : (item.projectName != null &&
                                              item.projectName!.isNotEmpty
                                          ? item.projectName!
                                          : 'Рекламация № ${item.id}'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
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
                          if (item.objectType != 'cabinet' &&
                              item.projectName != null &&
                              item.projectName!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Проект: ${item.projectName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            item.statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.3),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (item.warrantyBadgeText != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.warrantyBadgeColor!.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.warrantyBadgeText!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: item.warrantyBadgeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    Text(
                      _formatDate(item.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getFilterDisplayName(String filter) {
    switch (filter) {
      case 'new':
        return 'Новая';
      case 'review':
        return 'На рассмотрении';
      case 'in_progress':
        return 'В работе';
      case 'resolved':
        return 'Исполнена';
      case 'rejected':
        return 'Отклонена';
      case 'invalid':
        return 'Оформлена некорректно';
      default:
        return filter;
    }
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'Все'
                  ? 'У вас пока нет рекламаций'
                  : 'Нет рекламаций со статусом "${_getFilterDisplayName(_selectedFilter)}"',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Вы можете подать рекламацию по шкафу управления, линии или комплектующим',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final res = await Navigator.pushNamed(
                    context, '/create-reclamation');
                if (res == true && mounted) {
                  _loadReclamations();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Подать рекламацию'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
