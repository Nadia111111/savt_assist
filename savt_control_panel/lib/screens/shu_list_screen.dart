// lib/screens/shu_list_screen.dart
import 'package:flutter/material.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';
import '../widgets/glow_button.dart';
import '../models/shu_model.dart';
import '../services/mock_data.dart';
import '../services/network_service.dart';

class ShuListScreen extends StatefulWidget {
  const ShuListScreen({super.key});

  @override
  State<ShuListScreen> createState() => _ShuListScreenState();
}

class _ShuListScreenState extends State<ShuListScreen> {
  int _currentIndex = 0;
  String _searchQuery = '';
  String _selectedSort = 'По типу';
  bool _isSearchExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();

  final List<String> _sortOptions = [
    'По типу',
    'По гарантии',
    'По дате',
  ];

  List<ShuModel> get _allShuList => MockData.allShuList;

  List<ShuModel> get _filteredAndSortedShuList {
    var filtered = _allShuList.where((shu) {
      final query = _searchQuery.toLowerCase();
      return shu.type.toLowerCase().contains(query) ||
          shu.objectNumber.toLowerCase().contains(query) ||
          (shu.customName.isNotEmpty &&
              shu.customName.toLowerCase().contains(query)) ||
          (shu.comment.isNotEmpty && shu.comment.toLowerCase().contains(query));
    }).toList();

    switch (_selectedSort) {
      case 'По типу':
        filtered.sort((a, b) => a.type.compareTo(b.type));
        break;
      case 'По гарантии':
        filtered.sort((a, b) =>
            b.warrantyDaysRemaining.compareTo(a.warrantyDaysRemaining));
        break;
      case 'По дате':
        filtered.sort((a, b) => b.addedDate.compareTo(a.addedDate));
        break;
    }
    return filtered;
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _navigateToAddShu() async {
    await Navigator.pushNamed(context, '/qr-scanner');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NetworkService.isOnlineNotifier,
      builder: (context, isOnline, child) {
        return GradientScaffold(
          appBarTitle: 'Мои ШУ',
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
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 24 : 16,
                      vertical: 12,
                    ),
                    child: Column(
                      children: [
                        GlowButton(
                          text: 'Добавить ШУ',
                          icon: Icons.qr_code_scanner,
                          onPressed: isOnline ? _navigateToAddShu : null,
                        ),
                        const SizedBox(height: 12),
                        if (_isSearchExpanded) ...[
                          _buildSearchField(isDesktop),
                          const SizedBox(height: 8),
                        ],
                        _buildSortChips(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _filteredAndSortedShuList.isEmpty
                        ? _buildEmptyState()
                        : LayoutBuilder(
                            builder: (context, innerConstraints) {
                              final screenWidth = innerConstraints.maxWidth;
                              final cardWidth = isDesktop
                                  ? (screenWidth / 2).clamp(280.0, 480.0)
                                  : screenWidth - 32;

                              if (isDesktop && screenWidth > 600) {
                                // Десктоп: сетка в 2 колонки
                                return GridView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 8),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 2.2,
                                  ),
                                  itemCount: _filteredAndSortedShuList.length,
                                  itemBuilder: (context, index) {
                                    final shu =
                                        _filteredAndSortedShuList[index];
                                    return _buildShuCardGrid(shu, index);
                                  },
                                );
                              }

                              // Мобильные: обычный список
                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                itemCount: _filteredAndSortedShuList.length,
                                itemBuilder: (context, index) {
                                  final shu = _filteredAndSortedShuList[index];
                                  return _buildShuCard(shu, index);
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
          bottomNavBar: BottomNavBar(
            currentIndex: _currentIndex,
            onTap: _onNavTapped,
            unreadCounts: const {'chats': 3},
          ),
        );
      },
    );
  }

  Widget _buildShuCard(ShuModel shu, int index) {
    if (shu.moderationStatus == 'moderation') {
      return _buildModerationCard(shu, index);
    } else if (shu.moderationStatus == 'rejected') {
      return _buildRejectedCard(shu, index);
    }

    final theme = Theme.of(context);
    final isActive = shu.warrantyStatus == 'active';
    final isExpiring = shu.warrantyStatus == 'expiring';
    final days = shu.warrantyDaysRemaining;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isActive) {
      statusColor = const Color(0xFF10B981);
      statusText = '$days дн.';
      statusIcon = Icons.check_circle;
    } else if (isExpiring) {
      statusColor = const Color(0xFFF59E0B);
      statusText = '$days дн.';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = const Color(0xFF991B1B);
      statusText = 'Истекла';
      statusIcon = Icons.error_outline;
    }

    return AnimatedCard(
      index: index,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.pushNamed(context, '/shu-detail/${shu.id}'),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.memory, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shu.customName.isNotEmpty ? shu.customName : shu.type,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  shu.objectNumber,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 10, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (shu.unreadMessages > 0)
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/chat/${shu.id}'),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF991B1B),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF991B1B).withOpacity(0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModerationCard(ShuModel shu, int index) {
    final theme = Theme.of(context);
    return AnimatedCard(
      index: index,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('ШУ находится на модерации. Дождитесь подтверждения.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.hourglass_empty,
                color: theme.colorScheme.onSurfaceVariant, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shu.type,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  shu.objectNumber,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Ожидает подтверждения',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close,
                color: theme.colorScheme.onSurfaceVariant, size: 18),
            onPressed: () => _cancelModeration(shu),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedCard(ShuModel shu, int index) {
    final theme = Theme.of(context);
    return AnimatedCard(
      index: index,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.error_outline,
                    color: theme.colorScheme.error, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shu.type,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shu.objectNumber,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Отклонено',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _deleteRejectedShu(shu),
                  icon: const Icon(Icons.delete_outline, size: 14),
                  label: const Text('Удалить', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.error),
                    foregroundColor: theme.colorScheme.error,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _resubmitModeration(shu),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Повторно', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _cancelModeration(ShuModel shu) {
    setState(() {
      MockData.allShuList.removeWhere((s) => s.id == shu.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Заявка на модерацию отменена')),
    );
  }

  void _deleteRejectedShu(ShuModel shu) {
    setState(() {
      MockData.allShuList.removeWhere((s) => s.id == shu.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ШУ удалено')),
    );
  }

  void _resubmitModeration(ShuModel shu) {
    Navigator.pushNamed(context, '/photo-upload', arguments: shu.objectNumber);
  }

  Widget _buildSearchField(bool isDesktop) {
    final theme = Theme.of(context);
    return TextField(
      focusNode: _searchFocusNode,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Поиск по ШУ...',
        hintStyle:
            TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
        prefixIcon: Icon(Icons.search,
            color: theme.colorScheme.onSurfaceVariant, size: 24),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildShuCardGrid(ShuModel shu, int index) {
    // Упрощенная версия карточки для сетки на десктопе
    if (shu.moderationStatus == 'moderation') {
      return _buildModerationCardGrid(shu, index);
    } else if (shu.moderationStatus == 'rejected') {
      return _buildRejectedCardGrid(shu, index);
    }

    final theme = Theme.of(context);
    final isActive = shu.warrantyStatus == 'active';
    final isExpiring = shu.warrantyStatus == 'expiring';
    final days = shu.warrantyDaysRemaining;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isActive) {
      statusColor = const Color(0xFF10B981);
      statusText = '$days дн.';
      statusIcon = Icons.check_circle;
    } else if (isExpiring) {
      statusColor = const Color(0xFFF59E0B);
      statusText = '$days дн.';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = const Color(0xFF991B1B);
      statusText = 'Истекла';
      statusIcon = Icons.error_outline;
    }

    return AnimatedCard(
      index: index,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.pushNamed(context, '/shu-detail/${shu.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.memory, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  shu.customName.isNotEmpty ? shu.customName : shu.type,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            shu.objectNumber,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 10, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (shu.unreadMessages > 0)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: theme.colorScheme.primary,
                    size: 14,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModerationCardGrid(ShuModel shu, int index) {
    final theme = Theme.of(context);
    return AnimatedCard(
      index: index,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('ШУ находится на модерации. Дождитесь подтверждения.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.hourglass_empty,
                    color: theme.colorScheme.onSurfaceVariant, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  shu.type,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            shu.objectNumber,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Ожидает подтверждения',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedCardGrid(ShuModel shu, int index) {
    final theme = Theme.of(context);
    return AnimatedCard(
      index: index,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.error_outline,
                    color: theme.colorScheme.error, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  shu.type,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            shu.objectNumber,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _deleteRejectedShu(shu),
                  icon: const Icon(Icons.delete_outline, size: 14),
                  label: const Text('Удалить', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.error),
                    foregroundColor: theme.colorScheme.error,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _resubmitModeration(shu),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Повторно', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortChips() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _sortOptions.asMap().entries.map((entry) {
          final index = entry.key;
          final sortOption = entry.value;
          final isSelected = _selectedSort == sortOption;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(sortOption),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedSort = sortOption),
              selectedColor: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
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
              checkmarkColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              elevation: isSelected ? 4 : 0,
              shadowColor: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.3)
                  : Colors.transparent,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.qr_code_scanner,
              size: 48,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Нет добавленных ШУ',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Отсканируйте QR-код для добавления',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: GlowButton(
              text: 'Сканировать',
              icon: Icons.qr_code_scanner,
              onPressed: () => Navigator.pushNamed(context, '/qr-scanner'),
            ),
          ),
        ],
      ),
    );
  }

  void _onNavTapped(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/knowledge');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/chats');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }
}
