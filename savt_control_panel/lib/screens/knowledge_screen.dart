// lib/screens/knowledge_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:open_file/open_file.dart';
import '../services/file_save_helper.dart';
import '../theme/app_spacing.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/skeletons.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';
import '../main.dart'; // knowledgeService
import '../utils/error_handler.dart';
import '../widgets/keep_alive_wrapper.dart';
import '../widgets/responsive_layout.dart';
import '../services/preferences_service.dart';

class KnowledgeScreen extends StatefulWidget {
  final bool isTab;
  const KnowledgeScreen({super.key, this.isTab = false});

  @override
  State<KnowledgeScreen> createState() => KnowledgeScreenState();
}

class KnowledgeScreenState extends State<KnowledgeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final int _currentIndex = 1;
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();

  bool _isHeaderVisible = true;

  void resetState() {
    if (mounted) {
      setState(() {
        _isSearchExpanded = false;
        _searchQuery = '';
        _isHeaderVisible = true;
      });
      _tabController.animateTo(0);
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
      if (_faqScrollController.hasClients) {
        _faqScrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    }
  }

  // Статьи
  List<Map<String, dynamic>> _articles = [];
  bool _loadingArticles = false;
  int _articlesPage = 1;
  bool _hasMoreArticles = true;
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];

  // FAQ
  List<Map<String, dynamic>> _faqEntries = [];
  bool _loadingFaq = false;
  int _faqPage = 1;
  bool _hasMoreFaq = true;
  int? _selectedFaqCategoryId;
  List<Map<String, dynamic>> _faqCategories = [];

  // Фильтры, сортировка и теги
  final List<int> _selectedTagIds = [];
  String _sortBy = 'created_at';
  String _sortOrder = 'desc';
  Timer? _searchDebounce;
  final List<int> _downloadingAttachmentIds = [];

  final ScrollController _scrollController = ScrollController();
  final ScrollController _faqScrollController = ScrollController();
  final ScrollController _faqChipsScrollController = ScrollController();
  bool _articlesError = false;
  bool _faqError = false;

  bool _showingArticleDetail = false;

  @override
  void initState() {
    super.initState();
    favoritesService.addListener(_onFavoritesChanged);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        PreferencesService.saveKnowledgeTab(_tabController.index);
      }
      if (_tabController.indexIsChanging) {
        if (_tabController.index == 1) {
          setState(() {
            _selectedTagIds.clear();
          });
        } else if (_tabController.index == 0) {
          setState(() {
            _selectedTagIds.clear();
            _selectedTagIds.addAll(PreferencesService.getKnowledgeSelectedTags());
          });
        }
      }
    });
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final direction = _scrollController.position.userScrollDirection;
        if (direction == ScrollDirection.reverse && _isHeaderVisible) {
          setState(() {
            _isHeaderVisible = false;
          });
        } else if (direction == ScrollDirection.forward && !_isHeaderVisible) {
          setState(() {
            _isHeaderVisible = true;
          });
        }

        if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
          _loadArticles();
        }
      }
    });

    _faqScrollController.addListener(() {
      if (_faqScrollController.hasClients) {
        final direction = _faqScrollController.position.userScrollDirection;
        if (direction == ScrollDirection.reverse && _isHeaderVisible) {
          setState(() {
            _isHeaderVisible = false;
          });
        } else if (direction == ScrollDirection.forward && !_isHeaderVisible) {
          setState(() {
            _isHeaderVisible = true;
          });
        }

        if (_faqScrollController.position.pixels >= _faqScrollController.position.maxScrollExtent - 200) {
          _loadFaq();
        }
      }
    });

    _initPreferences().then((_) {
      _loadCategories();
      _loadFaqCategories();
      _loadArticles(refresh: true);
      _loadFaq(refresh: true);
    });
  }

  Future<void> _initPreferences() async {
    try {
      setState(() {
        _sortBy = PreferencesService.getKnowledgeSortBy();
        _sortOrder = PreferencesService.getKnowledgeSortOrder();
        _selectedTagIds.clear();
        _selectedTagIds.addAll(PreferencesService.getKnowledgeSelectedTags());
      });
      final tabIndex = PreferencesService.getKnowledgeTab();
      _tabController.animateTo(tabIndex);
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      await PreferencesService.saveKnowledgeSortBy(_sortBy);
      await PreferencesService.saveKnowledgeSortOrder(_sortOrder);
      await PreferencesService.saveKnowledgeSelectedTags(_selectedTagIds);
    } catch (_) {}
  }

  void _changeSort(String sortBy, String sortOrder) {
    setState(() {
      _sortBy = sortBy;
      _sortOrder = sortOrder;
    });
    _savePreferences();
    _loadArticles(refresh: true);
    _loadFaq(refresh: true);
  }

  @override
  void dispose() {
    favoritesService.removeListener(_onFavoritesChanged);
    _scrollController.dispose();
    _faqScrollController.dispose();
    _faqChipsScrollController.dispose();
    _tabController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
     super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await knowledgeService.getKbCategories();
      setState(() => _categories = cats);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadFaqCategories() async {
    try {
      final cats = await knowledgeService.getFaqCategories();
      setState(() => _faqCategories = cats);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadArticles({bool refresh = false}) async {
    if (_loadingArticles) return;
    if (!refresh && !_hasMoreArticles) return;

    setState(() {
      if (refresh) {
        _articlesPage = 1;
        _articles = [];
        _hasMoreArticles = true;
      }
      _loadingArticles = true;
      _articlesError = false;
    });

    try {
      const pageSize = 20;
      final data = await knowledgeService.getKbArticles(
        categoryId: _selectedCategoryId,
        tagIds: _selectedTagIds.isEmpty ? null : _selectedTagIds,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        page: _articlesPage,
        size: pageSize,
      );
      final newItems = List<Map<String, dynamic>>.from(data['items']);
      favoritesService.syncArticlesFavorited(newItems);
      if (!mounted) return;
      setState(() {
        if (_articlesPage == 1) {
          _articles = newItems;
        } else {
          _articles.addAll(newItems);
        }
        _hasMoreArticles = newItems.length >= pageSize;
        _loadingArticles = false;
        _articlesError = false;
      });
      if (newItems.isNotEmpty) _articlesPage++;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingArticles = false;
        _articlesError = true;
      });
      _showError(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  Future<void> _loadFaq({bool refresh = false}) async {
    if (_loadingFaq) return;
    if (!refresh && !_hasMoreFaq) return;

    setState(() {
      if (refresh) {
        _faqPage = 1;
        _faqEntries = [];
        _hasMoreFaq = true;
      }
      _loadingFaq = true;
      _faqError = false;
    });

    try {
      const pageSize = 20;
      final effectiveSortBy = _sortBy == 'title' ? 'question' : _sortBy;
      final data = await knowledgeService.getFaqEntries(
        categoryId: _selectedFaqCategoryId,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        sortBy: effectiveSortBy,
        sortOrder: _sortOrder,
        page: _faqPage,
        size: pageSize,
      );
      final newItems = List<Map<String, dynamic>>.from(data['items']);
      favoritesService.syncFaqsFavorited(newItems);
      if (!mounted) return;
      setState(() {
        if (_faqPage == 1) {
          _faqEntries = newItems;
        } else {
          _faqEntries.addAll(newItems);
        }
        _hasMoreFaq = newItems.length >= pageSize;
        _loadingFaq = false;
        _faqError = false;
      });
      if (newItems.isNotEmpty) _faqPage++;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingFaq = false;
        _faqError = true;
      });
      _showError(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  Future<void> _onRefresh() async {
    if (_tabController.index == 0) {
      await _loadArticles(refresh: true);
    } else {
      await _loadFaq(refresh: true);
    }
  }

  String _getCurrentSortLabel() {
    if (_sortBy == 'created_at') {
      return _sortOrder == 'desc' ? 'Новые' : 'Старые';
    } else if (_sortBy == 'title') {
      return _sortOrder == 'asc' ? 'А-Я' : 'Я-А';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBarTitle: 'База знаний',
      showBackButton: false,
      appBarAction: Row(
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
          PopupMenuButton<String>(
            child: Row(
              children: [
                const Icon(Icons.sort, color: Colors.white, size: 20),
                 gapW4,
                Text(
                  _getCurrentSortLabel(),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
              ],
            ),
            onSelected: (value) {
              if (value == 'new') {
                _changeSort('created_at', 'desc');
              } else if (value == 'old') {
                _changeSort('created_at', 'asc');
              } else if (value == 'alpha_asc') {
                _changeSort('title', 'asc');
              } else if (value == 'alpha_desc') {
                _changeSort('title', 'desc');
              }
            },
            itemBuilder: (context) {
              final theme = Theme.of(context);
              return [
                PopupMenuItem(
                  value: 'new',
                  child: Row(
                    children: [
                      Icon(Icons.arrow_downward, color: (_sortBy == 'created_at' && _sortOrder == 'desc') ? theme.colorScheme.primary : Colors.grey),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('По дате (новые)'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'old',
                  child: Row(
                    children: [
                      Icon(Icons.arrow_upward, color: (_sortBy == 'created_at' && _sortOrder == 'asc') ? theme.colorScheme.primary : Colors.grey),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('По дате (старые)'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'alpha_asc',
                  child: Row(
                    children: [
                      Icon(Icons.sort_by_alpha, color: (_sortBy == 'title' && _sortOrder == 'asc') ? theme.colorScheme.primary : Colors.grey),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('По названию (А-Я)'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'alpha_desc',
                  child: Row(
                    children: [
                      Icon(Icons.sort_by_alpha, color: (_sortBy == 'title' && _sortOrder == 'desc') ? theme.colorScheme.primary : Colors.grey),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('По названию (Я-А)'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: 600,
        child: Stack(
          children: [
            Column(
              children: [
                AnimatedCrossFade(
              firstChild: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOutCubic,
                 padding: _isSearchExpanded
                     ? const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.sm)
                     : EdgeInsets.zero,
                    child: _isSearchExpanded
                        ? _buildSearchField()
                        : const SizedBox.shrink(),
                  ),
                  // TabBar
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      indicatorWeight: 3,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Статьи'),
                        Tab(text: 'Частые вопросы'),
                      ],
                    ),
                  ),
                   // Category chips (только для статей)
                   if (_tabController.index == 0 && _categories.isNotEmpty)
                     _buildCategoryChips(),
                   // Строка с сортировкой и фильтрами (только для статей)
                  if (_tabController.index == 0)
                    _buildSortingRow(),
                  // Category chips для FAQ
                  if (_tabController.index == 1 && _faqCategories.isNotEmpty)
                    _buildFaqCategoryChips(),
                ],
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _isHeaderVisible ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 500),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: const Color(0xFF0a7ac2),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    KeepAliveWrapper(child: _buildArticlesTab()),
                    KeepAliveWrapper(child: _buildFaqTab()),
                  ],
                ),
              ),
            ),
          ],
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
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 500), () {
            _loadArticles(refresh: true);
            _loadFaq(refresh: true);
          });
        },
        decoration: InputDecoration(
          hintText: 'Поиск статей и вопросов...',
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

  Widget _buildSortingRow() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Статей найдено: ${_articles.length}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  List<CategoryNode> _buildCategoryTree(List<Map<String, dynamic>> flatCategories) {
    final Map<int, CategoryNode> nodeMap = {};
    for (final cat in flatCategories) {
      final id = cat['id'] as int;
      final name = cat['name'] as String;
      final parentId = cat['parent_id'] as int?;
      nodeMap[id] = CategoryNode(id: id, name: name, parentId: parentId, children: []);
    }

    final List<CategoryNode> roots = [];
    for (final node in nodeMap.values) {
      if (node.parentId == null) {
        roots.add(node);
      } else {
        final parentNode = nodeMap[node.parentId];
        if (parentNode != null) {
          parentNode.children.add(node);
        } else {
          roots.add(node);
        }
      }
    }
    return roots;
  }

  void _showCategoryTreeBottomSheet() {
    final tree = _buildCategoryTree(_categories);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Выберите категорию',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Все категории'),
                    leading: const Icon(Icons.category_outlined),
                    selected: _selectedCategoryId == null,
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = null;
                        _loadArticles(refresh: true);
                      });
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: tree.map((node) => _buildCategoryNodeTile(node, context)).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryNodeTile(CategoryNode node, BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = _selectedCategoryId == node.id;

    if (node.children.isEmpty) {
      return ListTile(
        contentPadding: const EdgeInsets.only(left: 8),
        title: Text(node.name),
        leading: Icon(Icons.folder_outlined, color: isSelected ? theme.colorScheme.primary : null),
        selected: isSelected,
        onTap: () {
          setState(() {
            _selectedCategoryId = node.id;
            _loadArticles(refresh: true);
          });
          Navigator.pop(context);
        },
      );
    }

    return ExpansionTile(
      tilePadding: const EdgeInsets.only(left: 8, right: 8),
      title: Text(node.name),
      leading: Icon(Icons.folder, color: isSelected ? theme.colorScheme.primary : null),
      initiallyExpanded: _isParentOf(node.id, _selectedCategoryId),
      trailing: TextButton(
        onPressed: () {
          setState(() {
            _selectedCategoryId = node.id;
            _loadArticles(refresh: true);
          });
          Navigator.pop(context);
        },
        child: Text('Выбрать', style: TextStyle(color: theme.colorScheme.primary)),
      ),
      children: node.children.map((child) => Padding(
        padding: const EdgeInsets.only(left: 12.0),
        child: _buildCategoryNodeTile(child, context),
      )).toList(),
    );
  }

  bool _isParentOf(int parentId, int? childId) {
    if (childId == null) return false;
    var current = _categories.firstWhere((cat) => cat['id'] == childId, orElse: () => <String, dynamic>{});
    while (current.isNotEmpty && current['parent_id'] != null) {
      if (current['parent_id'] == parentId) return true;
      current = _categories.firstWhere((cat) => cat['id'] == current['parent_id'], orElse: () => <String, dynamic>{});
    }
    return false;
  }

  Widget _buildCategoryChips() {
    final theme = Theme.of(context);
    final selectedCat = _categories.firstWhere(
      (c) => c['id'] == _selectedCategoryId,
      orElse: () => <String, dynamic>{},
    );
    final catName = selectedCat.isNotEmpty ? selectedCat['name'] : 'Все';
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      child: InkWell(
        onTap: _showCategoryTreeBottomSheet,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.folder_open, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Категория: $catName',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqCategoryChips() {
    final theme = Theme.of(context);
    if (_faqCategories.isEmpty) return const SizedBox.shrink();
    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent &&
            _faqChipsScrollController.hasClients) {
          final targetOffset = (_faqChipsScrollController.offset +
                  pointerSignal.scrollDelta.dy +
                  pointerSignal.scrollDelta.dx)
              .clamp(
                0.0,
                _faqChipsScrollController.position.maxScrollExtent,
              );
          _faqChipsScrollController.jumpTo(targetOffset);
        }
      },
      child: SingleChildScrollView(
        controller: _faqChipsScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('Все'),
              selected: _selectedFaqCategoryId == null,
              onSelected: (_) => setState(() {
                _selectedFaqCategoryId = null;
                _loadFaq(refresh: true);
              }),
              selectedColor: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              labelStyle: TextStyle(
                  color: _selectedFaqCategoryId == null
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
            ..._faqCategories.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat['name']),
                    selected: _selectedFaqCategoryId == cat['id'],
                    onSelected: (_) => setState(() {
                      _selectedFaqCategoryId = cat['id'];
                      _loadFaq(refresh: true);
                    }),
                    selectedColor: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    labelStyle: TextStyle(
                      color: _selectedFaqCategoryId == cat['id']
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildArticlesTab() {
    if (_loadingArticles && _articles.isEmpty) {
      return const SkeletonList();
    }
    if (_articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Нет статей',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }
    return ListView.separated(
      cacheExtent: 250, controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.base),
      itemCount: _articles.length + (_hasMoreArticles ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _articles.length) {
          if (_articlesError) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 32),
                    const SizedBox(height: 8),
                    const Text('Не удалось загрузить данные', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _articlesError = false;
                        });
                        _loadArticles();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.base),
            child: Center(child: ShimmerBlock(height: 60, borderRadius: 16)),
          );
        }
        final article = _articles[index];
        return _buildArticleCard(article, index);
      },
    );
  }

   Widget _buildArticleCard(Map<String, dynamic> article, int index) {
     final theme = Theme.of(context);
     final int articleId = (article['id'] is num)
         ? (article['id'] as num).toInt()
         : (int.tryParse(article['id']?.toString() ?? '') ?? 0);
     final bool isFav = favoritesService.isArticleFavorite(
       articleId,
       fallback: article['is_favorited'] as bool?,
     );
     return AnimatedCard(
       index: index,
       onTap: () => _showArticleDetail(articleId),
       child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary
                  ]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.menu_book, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(article['title'],
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if ((article['attachment_count'] ?? 0) > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: Icon(Icons.attach_file,
                      size: 14, color: theme.colorScheme.primary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(article['description'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.start,
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (article['tags'] != null && article['tags'].isNotEmpty)
                ...article['tags'].take(2).map<Widget>((tag) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(tag['name'],
                            style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    )),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav
                      ? Colors.amber
                      : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
                onPressed: () async {
                  try {
                    await favoritesService.toggleArticleFavorite(articleId);
                    article['is_favorited'] = favoritesService.isArticleFavorite(articleId);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Не удалось обновить избранное'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(width: 4),
              Text(_formatDate(article['created_at']),
                  style: TextStyle(
                      fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTab() {
    if (_loadingFaq && _faqEntries.isEmpty) {
      return const SkeletonList();
    }
    if (_faqEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.help_outline,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Нет вопросов',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }
    return ListView.separated(
      cacheExtent: 250, controller: _faqScrollController,
      padding: const EdgeInsets.all(AppSpacing.base),
      itemCount: _faqEntries.length + (_hasMoreFaq ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _faqEntries.length) {
          if (_faqError) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 32),
                    const SizedBox(height: 8),
                    const Text('Не удалось загрузить данные', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _faqError = false;
                        });
                        _loadFaq();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.base),
            child: Center(child: ShimmerBlock(height: 60, borderRadius: 16)),
          );
        }
        final faq = _faqEntries[index];
        return _buildFaqCard(faq, index);
      },
    );
  }

    Widget _buildFaqCard(Map<String, dynamic> faq, int index) {
      final theme = Theme.of(context);
      final int faqId = (faq['id'] is num)
          ? (faq['id'] as num).toInt()
          : (int.tryParse(faq['id']?.toString() ?? '') ?? 0);
      final bool isFav = favoritesService.isFaqFavorite(
        faqId,
        fallback: faq['is_favorited'] as bool?,
      );
      return AnimatedCard(
       index: index,
       child: ExpansionTile(
         title: Row(
           children: [
             Expanded(
               child: Text(faq['question'],
                   style: theme.textTheme.titleSmall
                       ?.copyWith(fontWeight: FontWeight.w600)),
             ),
           ],
         ),
         trailing: IconButton(
           visualDensity: VisualDensity.compact,
           icon: Icon(
             isFav ? Icons.star : Icons.star_border,
             color: isFav
                 ? Colors.amber
                 : theme.colorScheme.onSurfaceVariant,
             size: 22,
           ),
           onPressed: () async {
             try {
               await favoritesService.toggleFaqFavorite(faqId);
               faq['is_favorited'] = favoritesService.isFaqFavorite(faqId);
             } catch (e) {
               if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(
                     content: Text('Не удалось обновить избранное'),
                     duration: Duration(seconds: 2),
                   ),
                 );
               }
             }
           },
         ),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Text(faq['answer'],
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.start),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAttachment(int articleId, Map<String, dynamic> att) async {
    final attId = att['id'];
    final attTitle = att['title'] ?? 'Вложение';

    // 1. Если файл уже скачан - открываем сразу без загрузки (только для мобильных платформ)
    if (!kIsWeb) {
      final existingPath = await FileSaveHelper.getLocalFilePath(attTitle);
      if (existingPath != null) {
        await OpenFile.open(existingPath);
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _downloadingAttachmentIds.add(attId);
    });

    final theme = Theme.of(context);
    
    double progress = 0.0;
    bool isDownloading = true;
    String? errorMsg;
    StateSetter? dialogSetState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          dialogSetState = setDialogState;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(attTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDownloading) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    progress > 0 
                      ? 'Загрузка: ${(progress * 100).toStringAsFixed(0)}%' 
                      : 'Подготовка к загрузке...',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.start,
                  ),
                ] else if (errorMsg != null) ...[
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: AppSpacing.base),
                  Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
                ] else ...[
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 40),
                  const SizedBox(height: AppSpacing.base),
                  const Text('Файл открывается...', textAlign: TextAlign.center),
                ],
              ],
            ),
            actions: [
              if (!isDownloading)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ОК'),
                )
            ],
          );
        },
      ),
    );

    try {
      // Use bytes-based download which works on both web and mobile
      final bytes = await knowledgeService.downloadKbAttachmentBytes(
        articleId,
        attId,
        onProgress: (sent, total) {
          if (total > 0) {
            dialogSetState?.call(() {
              progress = sent / total;
            });
          }
        },
      );

      // Save file using FileSaveHelper (handles web and mobile)
      final savedPath = await FileSaveHelper.saveFile(
        context: context,
        bytes: bytes,
        fileName: FileSaveHelper.ensureExtension(attTitle, null),
      );

      dialogSetState?.call(() {
        isDownloading = false;
      });
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Файл сохранен: $savedPath'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // On web, browser handles download automatically, no need to open
      if (!kIsWeb) {
        await OpenFile.open(savedPath);
      }
    } catch (e) {
      dialogSetState?.call(() {
        isDownloading = false;
        errorMsg = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _downloadingAttachmentIds.remove(attId);
        });
      }
    }
  }

void _showArticleDetail(int articleId) async {
    if (_showingArticleDetail) return;
    _showingArticleDetail = true;
    final theme = Theme.of(context);
    try {
       final article = await knowledgeService.getKbArticleDetail(articleId);
       if (article['is_favorited'] is bool) {
         favoritesService.syncSingleArticle(articleId, article['is_favorited'] as bool);
       }
       if (!mounted) return;
       await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) => Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                          width: 40,
                          height: 4,
                           margin: const EdgeInsets.only(right: AppSpacing.base),
                          decoration: BoxDecoration(
                              color: theme.colorScheme.outline,
                              borderRadius: BorderRadius.circular(2))),
                    ],
                  ),
                   const SizedBox(height: 12),
                   Row(
                    children: [
                      Expanded(
                        child: Text(article['title'],
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                       IconButton(
                         visualDensity: VisualDensity.compact,
                         icon: Icon(
                           favoritesService.isArticleFavorite(
                             articleId,
                             fallback: article['is_favorited'] as bool?,
                           )
                               ? Icons.star
                               : Icons.star_border,
                           color: favoritesService.isArticleFavorite(
                             articleId,
                             fallback: article['is_favorited'] as bool?,
                           )
                               ? Colors.amber
                               : theme.colorScheme.onSurfaceVariant,
                           size: 24,
                         ),
                         onPressed: () async {
                           try {
                             await favoritesService.toggleArticleFavorite(articleId);
                             article['is_favorited'] = favoritesService.isArticleFavorite(articleId);
                             setModalState(() {});
                           } catch (e) {
                             if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 const SnackBar(
                                   content: Text('Не удалось обновить избранное'),
                                   duration: Duration(seconds: 2),
                                 ),
                               );
                             }
                           }
                         },
                       ),
                    ],
                  ),
                   const SizedBox(height: AppSpacing.base),
Text(article['description'] ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.6),
                        textAlign: TextAlign.start),
                   if (article['attachments'] != null &&
                       article['attachments'].isNotEmpty) ...[
                     const SizedBox(height: AppSpacing.xl),
                     Text('Вложения:', style: theme.textTheme.titleSmall),
                      ...article['attachments'].map<Widget>((att) {
                        final attId = att['id'];
                        final isDownloading = _downloadingAttachmentIds.contains(attId);
                        return ListTile(
                          title: Text(att['title']),
                          trailing: isDownloading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : ElevatedButton(
                                  onPressed: () => _downloadAttachment(articleId, att),
                                  child: const Text('Скачать'),
                                ),
                        );
                      }),
                   ],
                   const SizedBox(height: 24),
                 ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Ошибка загрузки: $e'), backgroundColor: Colors.red));
      }
    } finally {
      _showingArticleDetail = false;
    }
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

  void _onNavTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/shu-list');
        break;
      case 1:
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

class CategoryNode {
  final int id;
  final String name;
  final int? parentId;
  final List<CategoryNode> children;

  CategoryNode({
    required this.id,
    required this.name,
    this.parentId,
    required this.children,
  });
}

