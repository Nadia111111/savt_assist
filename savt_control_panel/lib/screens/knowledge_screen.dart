// lib/screens/knowledge_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';
import '../widgets/responsive_layout.dart';
import '../services/network_service.dart';
import '../services/offline_service.dart';
import '../services/favorites_service.dart';
import '../services/knowledge_data.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 1;
  late TabController _tabController;
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  String? _selectedParentCategory;
  String? _selectedSubCategory;
  bool _isLoading = false;
  bool _isOffline = false;

  // Слушаем изменения в сервисе избранного
  void _onFavoritesChanged() {
    setState(() {});
  }

  // Кэшированные данные для офлайн
  List<ArticleModel>? _cachedArticles;
  List<FAQModel>? _cachedFaqs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();

    // Слушаем изменение сети
    NetworkService.isOnlineNotifier.addListener(_onNetworkChanged);

    // Слушаем изменения избранного
    FavoritesService().addListener(_onFavoritesChanged);

    // Инициализируем сервис избранного
    FavoritesService().initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    NetworkService.isOnlineNotifier.removeListener(_onNetworkChanged);
    FavoritesService().removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onNetworkChanged() {
    setState(() {
      _isOffline = !NetworkService.isOnline;
    });
    if (NetworkService.isOnline) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    // Проверяем офлайн кэш
    if (!NetworkService.isOnline) {
      final cachedArticles =
          OfflineService().getCachedData('kb_articles') as List?;
      final cachedFaqs = OfflineService().getCachedData('faq_list') as List?;

      if (cachedArticles != null && cachedFaqs != null) {
        setState(() {
          _cachedArticles = cachedArticles
              .map((e) => ArticleModel(
                    id: e['id'],
                    title: e['title'],
                    description: e['description'],
                    category: e['category'],
                    subCategory: e['subCategory'],
                    tags: List<String>.from(e['tags'] ?? []),
                    updatedAt: DateTime.parse(e['updatedAt']),
                    hasAttachments: e['hasAttachments'] ?? false,
                  ))
              .toList();
          _cachedFaqs = cachedFaqs
              .map((e) => FAQModel(
                    id: e['id'],
                    question: e['question'],
                    answer: e['answer'],
                    category: e['category'],
                    subCategory: e['subCategory'],
                    tags: List<String>.from(e['tags'] ?? []),
                    relatedDevices:
                        List<String>.from(e['relatedDevices'] ?? []),
                    relatedQuestions: e['relatedQuestions'] != null
                        ? List<String>.from(e['relatedQuestions'])
                        : null,
                  ))
              .toList();
          _isOffline = true;
        });
        return;
      }
    }

    // Если онлайн — сохраняем в кэш
    if (NetworkService.isOnline) {
      OfflineService().cacheData(
          'kb_articles',
          allArticles
              .map((a) => {
                    'id': a.id,
                    'title': a.title,
                    'description': a.description,
                    'category': a.category,
                    'subCategory': a.subCategory,
                    'tags': a.tags,
                    'updatedAt': a.updatedAt.toIso8601String(),
                    'hasAttachments': a.hasAttachments,
                  })
              .toList());

      OfflineService().cacheData(
          'faq_list',
          allFaqs
              .map((f) => {
                    'id': f.id,
                    'question': f.question,
                    'answer': f.answer,
                    'category': f.category,
                    'subCategory': f.subCategory,
                    'tags': f.tags,
                    'relatedDevices': f.relatedDevices,
                    'relatedQuestions': f.relatedQuestions,
                  })
              .toList());
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);
    _loadData();
  }

  void _toggleArticleFavorite(String articleId) {
    FavoritesService().toggleArticleFavorite(articleId);
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleFaqFavorite(String faqId) {
    FavoritesService().toggleFaqFavorite(faqId);
    if (mounted) {
      setState(() {});
    }
  }

  List<ArticleModel> get _filteredArticles {
    List<ArticleModel> result =
        _isOffline && _cachedArticles != null ? _cachedArticles! : allArticles;

    if (_searchQuery.isNotEmpty) {
      result = result.where((article) {
        return article.title
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            article.description
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            article.tags.any((tag) =>
                tag.toLowerCase().contains(_searchQuery.toLowerCase()));
      }).toList();
    }

    if (_selectedParentCategory != null) {
      final category =
          categories.firstWhere((c) => c.name == _selectedParentCategory);
      if (_selectedSubCategory != null) {
        result = result
            .where((article) =>
                article.category == _selectedParentCategory &&
                article.subCategory == _selectedSubCategory)
            .toList();
      } else {
        // Показываем статьи из родительской категории и всех её подкатегорий
        final subCategoryIds = category.subCategories.map((s) => s.id).toList();
        result = result
            .where((article) =>
                article.category == _selectedParentCategory &&
                (article.subCategory == null ||
                    subCategoryIds.contains(article.subCategory)))
            .toList();
      }
    }

    return result;
  }

  List<FAQModel> get _filteredFaqs {
    List<FAQModel> result =
        _isOffline && _cachedFaqs != null ? _cachedFaqs! : allFaqs;

    if (_searchQuery.isNotEmpty) {
      result = result.where((faq) {
        return faq.question
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            faq.answer.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            faq.tags.any((tag) =>
                tag.toLowerCase().contains(_searchQuery.toLowerCase()));
      }).toList();
    }

    if (_selectedParentCategory != null) {
      if (_selectedSubCategory != null) {
        result = result
            .where((faq) =>
                faq.category == _selectedParentCategory &&
                faq.subCategory == _selectedSubCategory)
            .toList();
      } else {
        result = result
            .where((faq) => faq.category == _selectedParentCategory)
            .toList();
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBarTitle: 'База знаний',
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
        },
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: const Color(0xFF0a7ac2),
              backgroundColor: const Color(0xFF1A2332),
              child: TabBarView(
                controller: _tabController,
                children: [_buildArticlesTab(), _buildFaqTab()],
              ),
            ),
          ),
        ],
      ),
      bottomNavBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTapped,
        unreadCounts: const {'chats': 3},
      ),
    );
  }

  Widget _buildTabBar() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        indicatorColor: theme.colorScheme.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(height: 48, child: Text('Статьи')),
          Tab(height: 48, child: Text('Частые вопросы')),
        ],
      ),
    );
  }

  Widget _buildArticlesTab() {
    if (_isLoading) return _buildShimmerList();
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child:
              _isSearchExpanded ? _buildSearchField() : const SizedBox.shrink(),
        ),
        _buildCategoryHierarchy(),
        if (_isOffline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: Colors.orange.shade900,
            child: const Text('Офлайн-режим',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white)),
          ),
        Expanded(
          child: _filteredArticles.isEmpty
              ? _buildEmptyState()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = constraints.maxWidth;
                    final isDesktop = screenWidth >= 600;

                    if (isDesktop) {
                      // Десктоп: сетка в 2 колонки
                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.5,
                        ),
                        itemCount: _filteredArticles.length,
                        itemBuilder: (context, index) => _buildArticleCardGrid(
                            _filteredArticles[index], index),
                      );
                    }

                    // Мобильные: обычный список
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: _filteredArticles.length,
                      itemBuilder: (context, index) =>
                          _buildArticleCard(_filteredArticles[index], index),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    final theme = Theme.of(context);
    return TextField(
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Поиск статей и вопросов...',
        prefixIcon: Icon(Icons.search,
            color: theme.colorScheme.onSurfaceVariant, size: 24),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      autofocus: true,
    );
  }

  Widget _buildCategoryHierarchy() {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Родительские категории
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Все'),
                selected: _selectedParentCategory == null,
                onSelected: (_) => setState(() {
                  _selectedParentCategory = null;
                  _selectedSubCategory = null;
                }),
                selectedColor: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                labelStyle: TextStyle(
                  color: _selectedParentCategory == null
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: _selectedParentCategory == null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ...categories.map((category) {
                final isSelected = _selectedParentCategory == category.name;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category.name),
                    selected: isSelected,
                    onSelected: (_) => setState(() {
                      _selectedParentCategory = category.name;
                      _selectedSubCategory = null;
                    }),
                    selectedColor: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
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
              }),
            ],
          ),
        ),
        // Подкатегории (если выбрана родительская)
        if (_selectedParentCategory != null)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Все подкатегории'),
                  selected: _selectedSubCategory == null,
                  onSelected: (_) =>
                      setState(() => _selectedSubCategory = null),
                  selectedColor: theme.colorScheme.secondary,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  labelStyle: TextStyle(
                    color: _selectedSubCategory == null
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: _selectedSubCategory == null
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.outline,
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ...categories
                    .firstWhere((c) => c.name == _selectedParentCategory)
                    .subCategories
                    .map((subCat) {
                  final isSelected = _selectedSubCategory == subCat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(subCat.name),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedSubCategory = subCat.id),
                      selectedColor: theme.colorScheme.secondary,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isSelected
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.outline,
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildArticleCard(ArticleModel article, int index) {
    final theme = Theme.of(context);
    final isFavorite = FavoritesService().isArticleFavorite(article.id);
    return AnimatedCard(
      index: index,
      onTap: () => _showArticleDetail(article),
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
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.menu_book, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  article.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite
                      ? const Color(0xFFF59E0B)
                      : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
                onPressed: () => _toggleArticleFavorite(article.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              if (article.hasAttachments)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.attach_file,
                      size: 14, color: theme.colorScheme.primary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            article.description,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  article.category,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (article.subCategory != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    getSubCategoryName(article.subCategory, article.category) ??
                        article.subCategory!,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '${article.updatedAt.day}.${article.updatedAt.month}',
                style: TextStyle(
                    fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCardGrid(ArticleModel article, int index) {
    final theme = Theme.of(context);
    final isFavorite = FavoritesService().isArticleFavorite(article.id);
    return AnimatedCard(
      index: index,
      onTap: () => _showArticleDetail(article),
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.menu_book, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  article.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite
                      ? const Color(0xFFF59E0B)
                      : theme.colorScheme.onSurfaceVariant,
                  size: 18,
                ),
                onPressed: () => _toggleArticleFavorite(article.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            article.description,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  article.category,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${article.updatedAt.day}.${article.updatedAt.month}',
                style: TextStyle(
                    fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTab() {
    if (_isLoading) return _buildShimmerList();
    final theme = Theme.of(context);
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child:
              _isSearchExpanded ? _buildSearchField() : const SizedBox.shrink(),
        ),
        if (_isOffline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: Colors.orange.shade900,
            child: const Text('Офлайн-режим',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white)),
          ),
        Expanded(
          child: _filteredFaqs.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _filteredFaqs.length,
                  itemBuilder: (context, index) =>
                      _buildFaqCard(_filteredFaqs[index], index),
                ),
        ),
      ],
    );
  }

  Widget _buildFaqCard(FAQModel faq, int index) {
    final theme = Theme.of(context);
    final isFavorite = FavoritesService().isFaqFavorite(faq.id);
    return AnimatedCard(
      index: index,
      child: Theme(
        data: theme.copyWith(dividerColor: theme.colorScheme.outline),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  faq.question,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite
                      ? const Color(0xFFF59E0B)
                      : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () => _toggleFaqFavorite(faq.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              child: Text(
                faq.answer,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, height: 1.5),
              ),
            ),
            // Кнопка перейти в чат
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/chat/general');
                  },
                  icon: const Icon(Icons.chat, size: 16),
                  label: const Text('Перейти в чат'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            // Связанные вопросы
            if (faq.relatedQuestions != null &&
                faq.relatedQuestions!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Связанные вопросы:',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    ...faq.relatedQuestions!.map((relatedId) {
                      final relatedFaq = allFaqs.firstWhere(
                        (f) => f.id == relatedId,
                        orElse: () => const FAQModel(
                            id: '',
                            question: '',
                            answer: '',
                            category: '',
                            tags: [],
                            relatedDevices: []),
                      );
                      if (relatedFaq.id.isEmpty) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () {
                          final index =
                              allFaqs.indexWhere((f) => f.id == relatedId);
                          if (index != -1 && index != allFaqs.indexOf(faq)) {
                            setState(() {});
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• ${relatedFaq.question}',
                            style: TextStyle(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Ничего не найдено',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  void _showArticleDetail(ArticleModel article) {
    final theme = Theme.of(context);
    final isFavorite = FavoritesService().isArticleFavorite(article.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        article.title,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.star : Icons.star_border,
                        color: isFavorite
                            ? const Color(0xFFF59E0B)
                            : theme.colorScheme.onSurfaceVariant,
                        size: 26,
                      ),
                      onPressed: () {
                        _toggleArticleFavorite(article.id);
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        article.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (article.subCategory != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          getSubCategoryName(
                                  article.subCategory, article.category) ??
                              article.subCategory!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  article.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant, height: 1.6),
                ),
                const SizedBox(height: 24),
                // Связанные материалы
                Text('Связанные материалы:',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...allArticles
                    .where((a) =>
                        a.id != article.id &&
                        (a.category == article.category ||
                            a.tags.any((t) => article.tags.contains(t))))
                    .take(2)
                    .map((related) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            related.title,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.primary),
                          ),
                        )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/chat/general');
                    },
                    icon: const Icon(Icons.chat),
                    label: const Text('Перейти в чат'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
