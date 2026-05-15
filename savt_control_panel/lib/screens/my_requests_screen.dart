// lib/screens/my_requests_screen.dart
import 'package:flutter/material.dart';
import '../services/mock_data.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';

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

  List<Map<String, dynamic>> get _allRequests => MockData.allRequests;

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredRequests {
    var filtered = _allRequests;

    // Поиск по тексту
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((req) {
        final shuType = (req['shuType'] as String?)?.toLowerCase() ?? '';
        final objectNumber =
            (req['shuObjectNumber'] as String?)?.toLowerCase() ?? '';
        final description =
            (req['description'] as String?)?.toLowerCase() ?? '';
        final requestType =
            _getRequestTypeText(req['requestType'] as String).toLowerCase();

        return shuType.contains(query) ||
            objectNumber.contains(query) ||
            description.contains(query) ||
            requestType.contains(query);
      }).toList();
    }

    if (_selectedFilter != 'Все') {
      filtered = filtered.where((req) {
        final requestType = req['requestType'] as String;
        final type = req['type'] as String?;
        final status = req['status'] as String;

        // Фильтр по типу заявки
        if (_selectedFilter == 'Модерация') return requestType == 'moderation';
        if (_selectedFilter == 'Документы') return requestType == 'document';
        if (_selectedFilter == 'Обслуживание') return requestType == 'service';

        // Фильтр по подтипам обслуживания
        if (_selectedFilter == 'Гарантийные') return type == 'warranty';
        if (_selectedFilter == 'Негарантийные') return type == 'non_warranty';

        // Фильтр по статусам
        if (_selectedFilter == 'Открытые') return status == 'open';
        if (_selectedFilter == 'В работе') return status == 'in_progress';
        if (_selectedFilter == 'Закрытые') return status == 'closed';
        if (_selectedFilter == 'Ожидающие') return status == 'pending';
        if (_selectedFilter == 'Одобренные') return status == 'approved';
        if (_selectedFilter == 'Отклонённые') return status == 'rejected';

        return true;
      }).toList();
    }
    return filtered;
  }

  String _getRequestTypeText(String requestType) {
    switch (requestType) {
      case 'moderation':
        return 'Модерация';
      case 'document':
        return 'Документ';
      case 'service':
        return 'Обслуживание';
      default:
        return requestType;
    }
  }

  IconData _getRequestTypeIcon(String requestType) {
    switch (requestType) {
      case 'moderation':
        return Icons.verified_user;
      case 'document':
        return Icons.description;
      case 'service':
        return Icons.build;
      default:
        return Icons.help_outline;
    }
  }

  Color _getRequestTypeColor(String requestType) {
    switch (requestType) {
      case 'moderation':
        return const Color(0xFFF59E0B);
      case 'document':
        return const Color(0xFF10B981);
      case 'service':
        return const Color(0xFF054582);
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'open':
        return 'Открыта';
      case 'in_progress':
        return 'В работе';
      case 'closed':
        return 'Закрыта';
      case 'pending':
        return 'Ожидает';
      case 'approved':
        return 'Одобрена';
      case 'rejected':
        return 'Отклонена';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return const Color(0xFF054582);
      case 'closed':
      case 'approved':
        return const Color(0xFF10B981);
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'open':
      case 'pending':
        return Icons.visibility;
      case 'in_progress':
        return Icons.build;
      case 'closed':
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.block;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Мои заявки'),
        actions: [
          IconButton(
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
        ],
      ),
      body: Column(
        children: [
          // Фильтры по типам заявок
          _buildFilterChips(),
          const SizedBox(height: 12),
          // Список заявок
          Expanded(
            child: _filteredRequests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('Нет заявок',
                            style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredRequests.length,
                    itemBuilder: (context, index) {
                      final req = _filteredRequests[index];
                      return _buildRequestCard(req, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final theme = Theme.of(context);
    final List<String> filters = [
      'Все',
      'Модерация',
      'Документы',
      'Обслуживание',
      'Гарантийные',
      'Негарантийные',
      'Открытые',
      'В работе',
      'Ожидающие',
      'Одобренные',
      'Закрытые',
      'Отклонённые',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
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
                  width: 1.5,
                ),
              ),
            ),
          );
        }).toList(),
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
          hintText: 'Поиск по заявкам...',
          prefixIcon: Icon(Icons.search,
              color: theme.colorScheme.onSurfaceVariant, size: 24),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req, int index) {
    final theme = Theme.of(context);
    final requestType = req['requestType'] as String;
    final type = req['type'] as String?;
    final status = req['status'] as String;
    final requestTypeColor = _getRequestTypeColor(requestType);
    final requestTypeIcon = _getRequestTypeIcon(requestType);
    final statusColor = _statusColor(status);
    final statusIcon = _statusIcon(status);

    String title;
    String subtitle;
    IconData mainIcon;
    Color mainColor;

    if (requestType == 'service') {
      if (type == 'warranty') {
        title = 'Гарантийное обслуживание';
      } else {
        title = 'Негарантийное обслуживание';
      }
      subtitle = '${req['shuType']} • ${req['shuObjectNumber']}';
      mainIcon = Icons.build;
      mainColor = requestTypeColor;
    } else if (requestType == 'moderation') {
      title = 'Модерация ШУ';
      subtitle = '${req['shuType']} • ${req['shuObjectNumber']}';
      mainIcon = Icons.verified_user;
      mainColor = requestTypeColor;
    } else {
      title = req['documentName'] as String;
      subtitle = 'Запрос документации';
      mainIcon = Icons.description;
      mainColor = requestTypeColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: mainColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(mainIcon, color: mainColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  req['description'] as String? ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      _statusText(status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                req['date'] as String,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
