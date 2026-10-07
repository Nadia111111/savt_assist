// lib/screens/shu_list_screen.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';
import '../widgets/skeletons.dart';
import '../models/cabinet.dart';
import '../models/project.dart';
import 'project_cabinets_screen.dart';
import 'navigation_container.dart';
import '../main.dart';
import '../services/network_service.dart';
import '../widgets/responsive_layout.dart';

class ShuListScreen extends StatefulWidget {
  final bool isTab;
  const ShuListScreen({super.key, this.isTab = false});

  @override
  State<ShuListScreen> createState() => ShuListScreenState();
}

class ShuListScreenState extends State<ShuListScreen> with WidgetsBindingObserver {
  final int _currentIndex = 0;
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();

  List<Cabinet> _cabinets = [];
  List<Project> _projects = [];
  bool _isLoading = true;
  String _error = '';
  bool _isOnline = true;

  bool _isSelectionMode = false;
  final Set<int> _selectedCabinetIds = {};
  final Set<int> _selectedProjectIds = {};
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;

  void resetState() {
    print('🔵 [ShuListScreen] resetState called');
    if (mounted) {
      setState(() {
        _isSearchExpanded = false;
        _searchQuery = '';
        _isSelectionMode = false;
        _selectedCabinetIds.clear();
        _selectedProjectIds.clear();
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

  void scrollToTop() {
    print('🔵 [ShuListScreen] scrollToTop called');
    if (mounted && _scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCabinets();
    _checkNetwork();
    userEventsService.onCabinetCreated = _onRemoteCabinetCreated;
    _startAutoRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCabinets(forceRefresh: true);
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_isSelectionMode) {
        _loadCabinets(forceRefresh: false);
      }
    });
  }

  void _onRemoteCabinetCreated() {
    if (mounted) {
      _loadCabinets(forceRefresh: true);
    }
  }

  void _checkNetwork() {
    _isOnline = NetworkService.isOnline;
    NetworkService.isOnlineNotifier.addListener(_onNetworkChanged);
  }

  void _onNetworkChanged() {
    if (mounted) {
      setState(() {
        _isOnline = NetworkService.isOnline;
      });
      if (_isOnline && _cabinets.isEmpty && !_isLoading) {
        _loadCabinets();
      }
    }
  }

  Future<void> refreshCabinets() async {
    await _loadCabinets(forceRefresh: true);
  }

  Future<void> _loadCabinets({bool forceRefresh = false, bool showLoading = true}) async {
    final token = await tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _cabinets = [];
          _projects = [];
          _isLoading = false;
          _error = '';
        });
      }
      return;
    }

    if (mounted && showLoading && _cabinets.isEmpty && _projects.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    try {
      print('🟢 [ShuListScreen] Загрузка ШУ и проектов с бэкенда...');

      final cabinets =
          await cabinetService.getUserCabinets(forceRefresh: forceRefresh);
      print('🟢 [ShuListScreen] Получено ШУ: ${cabinets.length}');

      final projects =
          await cabinetService.getUserProjects(forceRefresh: forceRefresh);
      print('🟢 [ShuListScreen] Получено проектов: ${projects.length}');

      if (mounted) {
        setState(() {
          _cabinets = cabinets;
          _projects = projects;
          _isLoading = false;
          _error = '';
        });
      }
    } catch (e) {
      print('🔴 [ShuListScreen] Ошибка: $e');
      if (mounted) {
        if (_cabinets.isNotEmpty || _projects.isNotEmpty) {
          setState(() {
            _isLoading = false;
            });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Не удалось обновить данные: $e'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (!_isOnline) {
          setState(() {
            _error = 'Нет подключения к интернету. Данные не загружены ранее.';
            _isLoading = false;
            });
        } else {
          setState(() {
            _error = e.toString();
            _isLoading = false;
            });
        }
      }
    }
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedCabinetIds.clear();
      _selectedProjectIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final toDeleteProjects = List<int>.from(_selectedProjectIds);
    final toDeleteCabinets = List<int>.from(_selectedCabinetIds);

    final totalCount = toDeleteProjects.length + toDeleteCabinets.length;
    if (totalCount == 0) return;

    final standaloneCabIds = <int>[];
    final projectCabIds = <int>[];
    for (final id in toDeleteCabinets) {
      final cab = _cabinets.firstWhere(
        (c) => c.cabinetId == id,
        orElse: () => Cabinet(
          cabinetId: id,
          type: '',
          objectNumber: '',
          customName: '',
          unreadCount: 0,
          warrantyStatus: '',
        ),
      );
      if (cab.projectId == null || cab.projectId == 0) {
        standaloneCabIds.add(id);
      } else {
        projectCabIds.add(id);
      }
    }

    String message = 'Выбрано элементов: $totalCount.\n';
    if (toDeleteCabinets.isNotEmpty) {
      message += 'Чаты по выбранным ШУ уйдут в архив.\n';
    }
    if (projectCabIds.isNotEmpty) {
      message +=
          'Шкафы, входящие в проект (${projectCabIds.length} шт.), нельзя удалить отдельно — для них необходимо выйти из проекта.\n';
    }
    message += 'Вы уверены, что хотите продолжить?';

    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить выбранное?'),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Отмена')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child:
                      const Text('Удалить', style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;

    if (confirm != true) return;

    bool hasError = false;
    for (final id in toDeleteProjects) {
      try {
        await cabinetService.leaveProject(id);
      } catch (e) {
        hasError = true;
      }
    }
    for (final id in standaloneCabIds) {
      try {
        await cabinetService.deleteCabinet(id);
      } catch (e) {
        hasError = true;
      }
    }

    _exitSelectionMode();
    MainNavigationContainer.globalKey.currentState?.refreshChatsList();
    await _loadCabinets(forceRefresh: true, showLoading: false);

    if (!mounted) return;
    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Не удалось удалить некоторые элементы'),
          backgroundColor: Colors.red));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Успешно удалено'), backgroundColor: Colors.green));
    }
  }

  Future<void> _togglePinSelected() async {
    final selectedProjIds = List<int>.from(_selectedProjectIds);
    final selectedCabIds = List<int>.from(_selectedCabinetIds);
    if (selectedProjIds.isEmpty && selectedCabIds.isEmpty) return;

    final hasUnpinnedProjects = selectedProjIds.any((id) {
      final p = _projects.firstWhere(
        (proj) => proj.projectId == id,
        orElse: () =>
            Project(projectId: 0, name: '', cabinetCount: 0, isPinned: false),
      );
      return !p.isPinned;
    });

    final hasUnpinnedCabinets = selectedCabIds.any((id) {
      final c = _cabinets.firstWhere(
        (cab) => cab.cabinetId == id,
        orElse: () => Cabinet(
          cabinetId: 0,
          type: '',
          objectNumber: '',
          customName: '',
          unreadCount: 0,
          warrantyStatus: '',
          isPinned: false,
        ),
      );
      return !c.isPinned;
    });

    final bool shouldPin = hasUnpinnedProjects || hasUnpinnedCabinets;

    setState(() {
      if (selectedProjIds.isNotEmpty) {
        _projects = _projects.map((p) {
          if (selectedProjIds.contains(p.projectId)) {
            return p.copyWith(isPinned: shouldPin);
          }
          return p;
        }).toList();
      }
      if (selectedCabIds.isNotEmpty) {
        _cabinets = _cabinets.map((c) {
          if (selectedCabIds.contains(c.cabinetId)) {
            return c.copyWith(isPinned: shouldPin);
          }
          return c;
        }).toList();
      }
      _exitSelectionMode();
    });

    bool hasError = false;
    for (final id in selectedProjIds) {
      try {
        if (shouldPin) {
          await cabinetService.pinProject(id);
        } else {
          await cabinetService.unpinProject(id);
        }
      } catch (e) {
        hasError = true;
      }
    }
    for (final id in selectedCabIds) {
      try {
        if (shouldPin) {
          await cabinetService.pinCabinet(id);
        } else {
          await cabinetService.unpinCabinet(id);
        }
      } catch (e) {
        hasError = true;
      }
    }

    await _loadCabinets(forceRefresh: true, showLoading: false);

    if (mounted) {
      if (hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось изменить закрепление для некоторых элементов'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                shouldPin ? 'Элементы закреплены' : 'Элементы откреплены'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<Project> get _filteredAndSortedProjects {
    List<Project> list;
    if (_searchQuery.isEmpty) {
      list = List<Project>.from(_projects);
    } else {
      final query = _searchQuery.toLowerCase();
      list = _projects
          .where((proj) => proj.displayName.toLowerCase().contains(query))
          .toList();
    }

    list.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return list;
  }

  List<Cabinet> get _filteredAndSortedIndividualCabinets {
    final projectIds = _projects.map((p) => p.projectId).toSet();
    final individual = _cabinets.where((cab) {
      if (cab.projectId == null || cab.projectId == 0) return true;
      return !projectIds.contains(cab.projectId);
    }).toList();

    var filtered = individual;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = individual.where((cab) {
        return cab.type.toLowerCase().contains(query) ||
            cab.objectNumber.toLowerCase().contains(query) ||
            cab.customName.toLowerCase().contains(query) ||
            (cab.projectName != null &&
                cab.projectName!.toLowerCase().contains(query));
      }).toList();
    }
    return filtered;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    NetworkService.isOnlineNotifier.removeListener(_onNetworkChanged);
    if (userEventsService.onCabinetCreated == _onRemoteCabinetCreated) {
      userEventsService.onCabinetCreated = null;
    }
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBarTitle: _isSelectionMode
          ? 'Выбрано: ${_selectedProjectIds.length + _selectedCabinetIds.length}'
          : 'Мои проекты',
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
                if (_selectedProjectIds.isNotEmpty ||
                    _selectedCabinetIds.isNotEmpty) ...[
                  IconButton(
                    icon: Icon(
                      (_selectedProjectIds.any((id) {
                                final p = _projects.firstWhere(
                                  (proj) => proj.projectId == id,
                                  orElse: () => Project(
                                      projectId: 0,
                                      name: '',
                                      cabinetCount: 0,
                                      isPinned: false),
                                );
                                return !p.isPinned;
                              }) ||
                              _selectedCabinetIds.any((id) {
                                final c = _cabinets.firstWhere(
                                  (cab) => cab.cabinetId == id,
                                  orElse: () => Cabinet(
                                    cabinetId: 0,
                                    type: '',
                                    objectNumber: '',
                                    customName: '',
                                    unreadCount: 0,
                                    warrantyStatus: '',
                                    isPinned: false,
                                  ),
                                );
                                return !c.isPinned;
                              }))
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      color: Colors.white,
                    ),
                    tooltip: 'Закрепить/открепить',
                    onPressed: _togglePinSelected,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    tooltip: 'Удалить выбранные',
                    onPressed: _deleteSelected,
                  ),
                ],
              ],
            )
          : IconButton(
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
      body: ResponsiveContainer(
        maxWidth: 600,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  if (_isSearchExpanded) _buildSearchField(),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const SkeletonList()
                  : RefreshIndicator(
                      onRefresh: () => _loadCabinets(forceRefresh: true),
                      color: const Color(0xFF0a7ac2),
                      child: _error.isNotEmpty &&
                              _cabinets.isEmpty &&
                              _projects.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.6,
                                  child: _buildErrorState(),
                                ),
                              ],
                            )
                          : (_filteredAndSortedProjects.isEmpty &&
                                  _filteredAndSortedIndividualCabinets.isEmpty)
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.6,
                                      child: _buildEmptyState(),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  cacheExtent: 250, controller: _scrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  itemCount:
                                      _filteredAndSortedProjects.length +
                                          _filteredAndSortedIndividualCabinets
                                              .length,
                                  itemBuilder: (context, index) {
                                    final projectsCount =
                                        _filteredAndSortedProjects.length;
                                    final individualCount =
                                        _filteredAndSortedIndividualCabinets.length;
                                    if (index < projectsCount) {
                                      final project =
                                          _filteredAndSortedProjects[index];
                                      final card = _buildProjectFolderCard(
                                          project, index);
                                      if (index == 0 && individualCount > 0) {
                                        return KeyedSubtree(
                                          key: ValueKey(
                                              'proj_${project.projectId}'),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4, bottom: 8, left: 4),
                                                child: Text(
                                                  'Проекты',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                              card,
                                            ],
                                          ),
                                        );
                                      }
                                      return KeyedSubtree(
                                        key: ValueKey(
                                            'proj_${project.projectId}'),
                                        child: card,
                                      );
                                    } else {
                                      final cabIndex = index - projectsCount;
                                      final cab =
                                          _filteredAndSortedIndividualCabinets[
                                              cabIndex];
                                      final card =
                                          _buildCabinetCard(cab, index);
                                      if (cabIndex == 0 && projectsCount > 0) {
                                        return KeyedSubtree(
                                          key: ValueKey('cab_${cab.cabinetId}'),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 14,
                                                    bottom: 8,
                                                    left: 4),
                                                child: Text(
                                                  'Отдельные шкафы',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                              card,
                                            ],
                                          ),
                                        );
                                      }
                                      return KeyedSubtree(
                                        key: ValueKey('cab_${cab.cabinetId}'),
                                        child: card,
                                      );
                                    }
                                  },
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
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              heroTag: 'requests_hub_fab',
              onPressed: () {
                Navigator.pushNamed(context, '/requests-hub');
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.assignment_outlined, size: 20),
              label: const Text('Заявки',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Не удалось загрузить данные',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _error,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Проверьте подключение к интернету',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadCabinets,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  Widget _buildCabinetCard(Cabinet cabinet, int index) {
    final theme = Theme.of(context);
    final statusColor = _getWarrantyColor(cabinet.warrantyStatus);
    final statusText = _getWarrantyText(cabinet.warrantyStatus);
    final displayName =
        cabinet.customName.isNotEmpty ? cabinet.customName : cabinet.type;
    final isSelected = _selectedCabinetIds.contains(cabinet.cabinetId);

    return RepaintBoundary(
      child: GestureDetector(
        onLongPress: () {
          if (!_isSelectionMode) {
            setState(() {
              _isSelectionMode = true;
              _selectedCabinetIds.add(cabinet.cabinetId);
            });
          }
        },
        child: AnimatedCard(
          index: index,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          backgroundColor:
              isSelected ? theme.colorScheme.primary.withValues(alpha: 0.08) : null,
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
          if (isSelected) {
                  _selectedCabinetIds.remove(cabinet.cabinetId);
                  if (_selectedCabinetIds.isEmpty &&
                      _selectedProjectIds.isEmpty) {
                    _isSelectionMode = false;
                  }
                } else {
                  _selectedCabinetIds.add(cabinet.cabinetId);
                }
              });
            } else {
              Navigator.pushNamed(context, '/shu-detail/${cabinet.cabinetId}').then((_) {
                _loadCabinets(forceRefresh: true, showLoading: false);
              });
            }
          },
          child: Row(
            children: [
              if (_isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) {
                    setState(() {
                      if (isSelected) {
                        _selectedCabinetIds.remove(cabinet.cabinetId);
                        if (_selectedCabinetIds.isEmpty &&
                            _selectedProjectIds.isEmpty) {
                          _isSelectionMode = false;
                        }
                      } else {
                        _selectedCabinetIds.add(cabinet.cabinetId);
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
              ],
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
                ),
                child: const Icon(Icons.memory, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cabinet.objectNumber,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cabinet.projectName != null &&
                              cabinet.projectName!.isNotEmpty
                          ? 'Проект: ${cabinet.projectName}'
                          : 'Без проекта',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cabinet.projectName != null &&
                                cabinet.projectName!.isNotEmpty
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: cabinet.projectName != null &&
                                cabinet.projectName!.isNotEmpty
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getWarrantyIcon(cabinet.warrantyStatus),
                              size: 10, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isSelectionMode && cabinet.isPinned)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Transform.rotate(
                    angle: 0.4,
                    child: Icon(
                      Icons.push_pin,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              if (!_isSelectionMode)
                GestureDetector(
                  onTap: () async {
                    try {
                      final chatData = await cabinetService
                          .getCabinetChat(cabinet.cabinetId);
                      final chatId = chatData['id'];
                      if (chatId != null && mounted) {
                        Navigator.pushNamed(context, '/chat/$chatId');
                        MainNavigationContainer.globalKey.currentState?.refreshChatsList();
                      }
                    } on DioException catch (e) {
                      if (e.response?.statusCode == 403 ||
                          (e.response?.statusCode == 404 &&
                              cabinet.projectId != null)) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Проект больше недоступен'),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          _loadCabinets(forceRefresh: true, showLoading: false);
                        }
                      } else if (e.response?.statusCode == 404 && mounted) {
                        Navigator.pushNamed(
                            context, '/shu-detail/${cabinet.cabinetId}');
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Ошибка открытия чата: $e'),
                              backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              color: theme.colorScheme.primary, size: 18),
                          if (cabinet.unreadCount > 0)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF991B1B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectFolderCard(Project project, int index) {
    final theme = Theme.of(context);
    final isSelected = _selectedProjectIds.contains(project.projectId);
    final isPinned = project.isPinned;

    return AnimatedCard(
      index: index,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      onLongPress: () {
        if (_isSelectionMode) return;
        setState(() {
          _isSelectionMode = true;
          _selectedProjectIds.add(project.projectId);
        });
      },
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedProjectIds.remove(project.projectId);
              if (_selectedProjectIds.isEmpty && _selectedCabinetIds.isEmpty) {
                _isSelectionMode = false;
              }
            } else {
              _selectedProjectIds.add(project.projectId);
            }
          });
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectCabinetsScreen(
              projectId: project.projectId,
              projectName: project.name,
            ),
          ),
        ).then((_) {
          _loadCabinets(forceRefresh: false);
        });
      },
      child: Row(
        children: [
          if (_isSelectionMode) ...[
            Checkbox(
              value: isSelected,
              activeColor: theme.colorScheme.primary,
              onChanged: (_) {
                setState(() {
                  if (isSelected) {
                    _selectedProjectIds.remove(project.projectId);
                    if (_selectedProjectIds.isEmpty &&
                        _selectedCabinetIds.isEmpty) {
                      _isSelectionMode = false;
                    }
                  } else {
                    _selectedProjectIds.add(project.projectId);
                  }
                });
              },
            ),
            const SizedBox(width: 8),
          ],
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.shade400,
                    Colors.orange.shade500,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]),
            child: const Center(
              child: Icon(Icons.folder, color: Colors.white, size: 28),
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
                        project.name,
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
                Builder(builder: (context) {
                  final matchingCount = _cabinets
                      .where((c) => c.projectId == project.projectId)
                      .length;
                  final displayCount = matchingCount > project.cabinetCount
                      ? matchingCount
                      : project.cabinetCount;
                  return Text(
                    'Шкафов в проекте: $displayCount',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }),
              ],
            ),
          ),
          if (!_isSelectionMode && isPinned)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Transform.rotate(
                angle: 0.4,
                child: Icon(
                  Icons.push_pin,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          if (!_isSelectionMode)
            Icon(Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          if (_isSelectionMode)
            const Icon(Icons.chevron_right, color: Colors.transparent),
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
        hintText: 'Поиск по ШУ...',
        prefixIcon: Icon(Icons.search,
            color: theme.colorScheme.onSurfaceVariant, size: 24),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.folder_open_outlined,
                size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text('Нет добавленных проектов и ШУ',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Потяните вниз для обновления страницы',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Color _getWarrantyColor(String status) {
    switch (status) {
      case 'active':
        return const Color(0xFF10B981);
      case 'expiring_soon':
        return const Color(0xFFF59E0B);
      case 'expired':
        return const Color(0xFF991B1B);
      default:
        return Colors.grey;
    }
  }

  String _getWarrantyText(String status) {
    switch (status) {
      case 'active':
        return 'Активна';
      case 'expiring_soon':
        return 'Истекает';
      case 'expired':
        return 'Истекла';
      default:
        return 'Н/Д';
    }
  }

  IconData _getWarrantyIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.check_circle;
      case 'expiring_soon':
        return Icons.warning_amber_rounded;
      case 'expired':
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
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

