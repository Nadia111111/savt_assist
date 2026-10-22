// lib/screens/knowledge_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(canRequestFocus: false);

  bool _isHeaderVisible = true;

  void resetState() {
    if (mounted) {
      _searchController.clear();
      _searchFocusNode.canRequestFocus = false;
      _searchFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      FocusManager.instance.primaryFocus?.unfocus();
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
  final Set<String> _downloadedAttachmentNames = {};

  final ScrollController _scrollController = ScrollController();
  final ScrollController _faqScrollController = ScrollController();
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
        setState(() {});
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
        final pixels = _scrollController.position.pixels;
        if (pixels <= 0 && !_isHeaderVisible) {
          setState(() {
            _isHeaderVisible = true;
          });
        } else if (direction == ScrollDirection.reverse && _isHeaderVisible && !_isSearchExpanded) {
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
        final pixels = _faqScrollController.position.pixels;
        if (pixels <= 0 && !_isHeaderVisible) {
          setState(() {
            _isHeaderVisible = true;
          });
        } else if (direction == ScrollDirection.reverse && _isHeaderVisible && !_isSearchExpanded) {
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
    _tabController.dispose();
    _searchController.dispose();
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
              if (_isSearchExpanded) {
                final hadQuery = _searchQuery.isNotEmpty || _searchController.text.isNotEmpty;
                _searchFocusNode.canRequestFocus = false;
                _searchFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() {
                  _isSearchExpanded = false;
                  _searchQuery = '';
                  _searchController.clear();
                  _isHeaderVisible = true;
                });
                if (hadQuery) {
                  _loadArticles(refresh: true);
                  _loadFaq(refresh: true);
                }
              } else {
                _searchFocusNode.canRequestFocus = true;
                setState(() {
                  _isHeaderVisible = true;
                  _isSearchExpanded = true;
                });
                Future.delayed(const Duration(milliseconds: 150), () {
                  if (mounted && _isSearchExpanded) {
                    _searchFocusNode.requestFocus();
                  }
                });
              }
            },
          ),
          PopupMenuButton<String>(
            onOpened: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A2332) : Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              final isDark = theme.brightness == Brightness.dark;
              final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
              final primaryColor = theme.colorScheme.primary;
              final inactiveColor = isDark ? Colors.grey : const Color(0xFF94A3B8);
              return [
                PopupMenuItem(
                  value: 'new',
                  child: Row(
                    children: [
                      Icon(Icons.arrow_downward, color: (_sortBy == 'created_at' && _sortOrder == 'desc') ? primaryColor : inactiveColor),
                      const SizedBox(width: AppSpacing.sm),
                      Text('По дате (новые)', style: TextStyle(color: textColor, fontWeight: (_sortBy == 'created_at' && _sortOrder == 'desc') ? FontWeight.w600 : FontWeight.normal)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'old',
                  child: Row(
                    children: [
                      Icon(Icons.arrow_upward, color: (_sortBy == 'created_at' && _sortOrder == 'asc') ? primaryColor : inactiveColor),
                      const SizedBox(width: AppSpacing.sm),
                      Text('По дате (старые)', style: TextStyle(color: textColor, fontWeight: (_sortBy == 'created_at' && _sortOrder == 'asc') ? FontWeight.w600 : FontWeight.normal)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'alpha_asc',
                  child: Row(
                    children: [
                      Icon(Icons.sort_by_alpha, color: (_sortBy == 'title' && _sortOrder == 'asc') ? primaryColor : inactiveColor),
                      const SizedBox(width: AppSpacing.sm),
                      Text('По названию (А-Я)', style: TextStyle(color: textColor, fontWeight: (_sortBy == 'title' && _sortOrder == 'asc') ? FontWeight.w600 : FontWeight.normal)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'alpha_desc',
                  child: Row(
                    children: [
                      Icon(Icons.sort_by_alpha, color: (_sortBy == 'title' && _sortOrder == 'desc') ? primaryColor : inactiveColor),
                      const SizedBox(width: AppSpacing.sm),
                      Text('По названию (Я-А)', style: TextStyle(color: textColor, fontWeight: (_sortBy == 'title' && _sortOrder == 'desc') ? FontWeight.w600 : FontWeight.normal)),
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
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOutCubic,
                    height: _isSearchExpanded ? 68 : 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: _isSearchExpanded ? AppSpacing.base : 0,
                      vertical: _isSearchExpanded ? 6 : 0,
                    ),
                    child: ClipRect(
                      child: OverflowBox(
                        minHeight: 0,
                        maxHeight: 68,
                        alignment: Alignment.topCenter,
                        child: AnimatedOpacity(
                          opacity: _isSearchExpanded ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 220),
                          child: ExcludeFocus(
                            excluding: !_isSearchExpanded,
                            child: IgnorePointer(
                              ignoring: !_isSearchExpanded,
                              child: _buildSearchField(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // TabBar
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Theme.of(context).brightness == Brightness.dark
                          ? null
                          : Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)),
                      boxShadow: Theme.of(context).brightness == Brightness.dark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
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
                  // Category chips для FAQ
                  if (_tabController.index == 1 && _faqCategories.isNotEmpty)
                    _buildFaqCategoryChips(),
                ],
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _isHeaderVisible ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 300),
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
        controller: _searchController,
        focusNode: _searchFocusNode,
        enabled: _isSearchExpanded,
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
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        double dragDistance = 0;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) => dragDistance = 0,
                onVerticalDragUpdate: (details) {
                  dragDistance += details.primaryDelta ?? 0;
                },
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity != null && details.primaryVelocity! > 100) || dragDistance > 50) {
                    Navigator.of(context).pop();
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Выберите категорию',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
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
                  children: tree.map((node) => _buildCategoryNodeTile(node, context)).toList(),
                ),
              ),
            ],
          ),
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
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.surfaceContainerHighest
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.brightness == Brightness.dark
                  ? theme.colorScheme.outline.withValues(alpha: 0.3)
                  : theme.colorScheme.outline.withValues(alpha: 0.4),
            ),
            boxShadow: theme.brightness == Brightness.dark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
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

  void _showFaqCategoryBottomSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        double dragDistance = 0;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) => dragDistance = 0,
                onVerticalDragUpdate: (details) {
                  dragDistance += details.primaryDelta ?? 0;
                },
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity != null && details.primaryVelocity! > 100) || dragDistance > 50) {
                    Navigator.of(context).pop();
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Выберите категорию',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              Material(
                color: theme.colorScheme.surface,
                child: ListTile(
                  title: const Text('Все категории'),
                  leading: Icon(Icons.category_outlined,
                      color: _selectedFaqCategoryId == null ? theme.colorScheme.primary : null),
                  selected: _selectedFaqCategoryId == null,
                  onTap: () {
                    setState(() {
                      _selectedFaqCategoryId = null;
                      _loadFaq(refresh: true);
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _faqCategories.length,
                  itemBuilder: (context, index) {
                    final cat = _faqCategories[index];
                    final isSelected = _selectedFaqCategoryId == cat['id'];
                    return Material(
                      color: theme.colorScheme.surface,
                      child: ListTile(
                        title: Text(cat['name']),
                        leading: Icon(Icons.folder_outlined,
                            color: isSelected ? theme.colorScheme.primary : null),
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedFaqCategoryId = cat['id'];
                            _loadFaq(refresh: true);
                          });
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFaqCategoryChips() {
    final theme = Theme.of(context);
    if (_faqCategories.isEmpty) return const SizedBox.shrink();
    final selectedCat = _faqCategories.firstWhere(
      (c) => c['id'] == _selectedFaqCategoryId,
      orElse: () => <String, dynamic>{},
    );
    final catName = selectedCat.isNotEmpty ? selectedCat['name'] : 'Все';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      child: InkWell(
        onTap: _showFaqCategoryBottomSheet,
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
    return ListView.builder(
      cacheExtent: 250,
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _articles.length + (_hasMoreArticles ? 1 : 0),
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
    final hasTags = article['tags'] != null && (article['tags'] as List).isNotEmpty;
    final hasAttachments = (article['attachment_count'] ?? 0) > 0;

    return AnimatedCard(
      index: index,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      onTap: () => _showArticleDetail(articleId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article['title'] ?? '',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.start,
                    ),
                    if (article['description'] != null &&
                        (article['description'] as String).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        article['description'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.start,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
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
                    setState(() {
                      article['is_favorited'] =
                          favoritesService.isArticleFavorite(articleId);
                    });
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
            ],
          ),
          if (hasTags || hasAttachments) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (hasTags)
                  ...(article['tags'] as List).take(2).map<Widget>((tag) => Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(tag['name'] ?? '',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      )),
                const Spacer(),
                if (hasAttachments)
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
          ],
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
    return ListView.builder(
      cacheExtent: 250,
      controller: _faqScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _faqEntries.length + (_hasMoreFaq ? 1 : 0),
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
      final question = faq['question']?.toString() ?? '';
      final answer = faq['answer']?.toString() ?? '';

      return AnimatedCard(
        index: index,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        onTap: () => _showFaqDetail(faq),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.help_outline, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (answer.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          answer,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  icon: Icon(
                    isFav ? Icons.star : Icons.star_border,
                    color: isFav ? Colors.amber : theme.colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  onPressed: () async {
                    try {
                      await favoritesService.toggleFaqFavorite(faqId);
                      setState(() {
                        faq['is_favorited'] = favoritesService.isFaqFavorite(faqId);
                      });
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
              ],
            ),
          ],
        ),
      );
    }

  Future<void> _openDownloadedAttachment(String fileName) async {
    final localPath = await FileSaveHelper.getLocalFilePath(fileName);
    if (localPath != null) {
      final result = await OpenFile.open(localPath);
      if (result.type != ResultType.done && mounted) {
        _showError('Не удалось открыть файл: ${result.message}');
      }
    } else {
      _showError('Файл не найден на устройстве');
    }
  }

  Future<void> _downloadAttachment(int articleId, Map<String, dynamic> att) async {
    final attId = att['id'];
    final attTitle = att['title'] ?? 'Вложение';
    final fileUrl = att['file_url'] ?? att['url'];
    final fileName = FileSaveHelper.ensureExtension(attTitle, fileUrl);

    // Если файл уже скачан, открываем его без повторного скачивания
    if (await FileSaveHelper.isFileDownloaded(fileName)) {
      if (mounted) {
        setState(() {
          _downloadedAttachmentNames.add(fileName);
        });
      }
      await _openDownloadedAttachment(fileName);
      return;
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

      final savePath = await FileSaveHelper.saveFile(
        context: context,
        bytes: bytes,
        fileName: fileName,
      );

      dialogSetState?.call(() {
        isDownloading = false;
      });
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Файл сохранен: $savePath'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (mounted) {
        setState(() {
          _downloadingAttachmentIds.remove(attId);
          _downloadedAttachmentNames.add(fileName);
        });
      }

      // On web, browser handles download automatically, no need to open
      if (!kIsWeb) {
        await OpenFile.open(savePath);
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
       // Check for downloaded attachments
       if (article['attachments'] != null && article['attachments'].isNotEmpty) {
         final downloaded = <String>{};
         for (final att in article['attachments']) {
           final fileUrl = att['file_url'] ?? att['url'];
           final fileName = FileSaveHelper.ensureExtension(att['title'] ?? 'Вложение', fileUrl);
           if (await FileSaveHelper.isFileDownloaded(fileName)) {
             downloaded.add(fileName);
           }
         }
         if (mounted) {
           setState(() {
             _downloadedAttachmentNames.addAll(downloaded);
           });
         }
       }
       if (!mounted) return;
       await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        enableDrag: false,
        isDismissible: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            double dragDistance = 0;
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (_) => dragDistance = 0,
                    onVerticalDragUpdate: (details) {
                      dragDistance += details.primaryDelta ?? 0;
                    },
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity != null && details.primaryVelocity! > 100) || dragDistance > 50) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 14, bottom: 10),
                          color: Colors.transparent,
                          child: Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.outline.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  article['title'] ?? '',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.start,
                                ),
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
                                    if (mounted) setState(() {});
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
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            article['description'] ?? '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.start,
                          ),
                          if (article['attachments'] != null &&
                              article['attachments'].isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xl),
                            Text('Вложения:', style: theme.textTheme.titleSmall),
                            ...article['attachments'].map<Widget>((att) {
                              final attId = att['id'];
                              final fileUrl = att['file_url'] ?? att['url'];
                              final fileName = FileSaveHelper.ensureExtension(att['title'] ?? 'Вложение', fileUrl);
                              final isDownloaded = _downloadedAttachmentNames.contains(fileName);
                              final isDownloading = _downloadingAttachmentIds.contains(attId);
                              return Material(
                                color: theme.colorScheme.surface,
                                child: ListTile(
                                  title: Text(att['title']),
                                  trailing: isDownloading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : isDownloaded && !kIsWeb
                                          ? OutlinedButton.icon(
                                              icon: const Icon(Icons.visibility, size: 16),
                                              label: const Text('Просмотр'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: theme.colorScheme.primary,
                                                side: BorderSide(color: theme.colorScheme.primary),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              ),
                                              onPressed: () => _openDownloadedAttachment(fileName),
                                            )
                                          : ElevatedButton(
                                              onPressed: () => _downloadAttachment(articleId, att),
                                              child: const Text('Скачать'),
                                            ),
                                ),
                              );
                            }),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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

  void _showFaqDetail(Map<String, dynamic> faq) async {
    final theme = Theme.of(context);
    final int faqId = (faq['id'] is num)
        ? (faq['id'] as num).toInt()
        : (int.tryParse(faq['id']?.toString() ?? '') ?? 0);
    final question = faq['question']?.toString() ?? '';
    final answer = faq['answer']?.toString() ?? '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          double dragDistance = 0;
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) => dragDistance = 0,
                  onVerticalDragUpdate: (details) {
                    dragDistance += details.primaryDelta ?? 0;
                  },
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity != null && details.primaryVelocity! > 100) || dragDistance > 50) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(top: 14, bottom: 10),
                        color: Colors.transparent,
                        child: Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.outline.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                question,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                favoritesService.isFaqFavorite(
                                  faqId,
                                  fallback: faq['is_favorited'] as bool?,
                                )
                                    ? Icons.star
                                    : Icons.star_border,
                                color: favoritesService.isFaqFavorite(
                                  faqId,
                                  fallback: faq['is_favorited'] as bool?,
                                )
                                    ? Colors.amber
                                    : theme.colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                              onPressed: () async {
                                try {
                                  await favoritesService.toggleFaqFavorite(faqId);
                                  faq['is_favorited'] = favoritesService.isFaqFavorite(faqId);
                                  setModalState(() {});
                                  if (mounted) setState(() {});
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
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          answer,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.start,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ignore: unused_element
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
