// lib/screens/favorites_screen.dart
import 'package:flutter/material.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';
import '../widgets/responsive_layout.dart';
import '../services/favorites_service.dart';
import '../services/knowledge_data.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 3;
  late TabController _tabController;
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();

  // Слушаем изменения в сервисе избранного
  void _onFavoritesChanged() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Слушаем изменения избранного
    FavoritesService().addListener(_onFavoritesChanged);

    // Инициализируем сервис избранного
    FavoritesService().initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFocusNode.dispose();
    FavoritesService().removeListener(_onFavoritesChanged);
    super.dispose();
  }

  List<ArticleModel> get _filteredArticles {
    // Получаем только избранные статьи
    final favoriteIds = FavoritesService().favoriteArticleIds;
    var result =
        allArticles.where((article) => favoriteIds.contains(article.id));

    if (_searchQuery.isNotEmpty) {
      result = result.where((article) {
        return article.title
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            article.description
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
      });
    }

    return result.toList();
  }

  List<FAQModel> get _filteredFaqs {
    // Получаем только избранные FAQ
    final favoriteIds = FavoritesService().favoriteFaqIds;
    var result = allFaqs.where((faq) => favoriteIds.contains(faq.id));

    if (_searchQuery.isNotEmpty) {
      result = result.where((faq) {
        return faq.question
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            faq.answer.toLowerCase().contains(_searchQuery.toLowerCase());
      });
    }

    return result.toList();
  }

  void _toggleArticleFavorite(String id) {
    FavoritesService().toggleArticleFavorite(id);
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleFaqFavorite(String id) {
    FavoritesService().toggleFaqFavorite(id);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBarTitle: 'Избранное',
      appBarLeading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
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
          const SizedBox(height: 8),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildArticlesTab(), _buildFaqTab()],
            ),
          ),
        ],
      ),
      bottomNavBar: BottomNavBar(
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
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Поиск по избранному...',
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

  Widget _buildTabBar() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
          Tab(text: 'Статьи'),
          Tab(text: 'Вопросы'),
        ],
      ),
    );
  }

  Widget _buildArticlesTab() {
    if (_filteredArticles.isEmpty) return _buildEmptyState('Статьи');
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isDesktop = screenWidth >= 600;

        if (isDesktop) {
          // Десктоп: сетка в 2 колонки
          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.5,
            ),
            itemCount: _filteredArticles.length,
            itemBuilder: (context, index) =>
                _buildArticleCardGrid(_filteredArticles[index], index),
          );
        }

        // Мобильные: обычный список
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _filteredArticles.length,
          itemBuilder: (context, index) =>
              _buildArticleCard(_filteredArticles[index], index),
        );
      },
    );
  }

  Widget _buildFaqTab() {
    if (_filteredFaqs.isEmpty) return _buildEmptyState('Вопросы');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredFaqs.length,
      itemBuilder: (context, index) =>
          _buildFaqCard(_filteredFaqs[index], index),
    );
  }

  Widget _buildArticleCard(ArticleModel article, int index) {
    final theme = Theme.of(context);
    final isFavorite = FavoritesService().isArticleFavorite(article.id);
    return AnimatedCard(
      index: index,
      onTap: () => _showArticleDetail(article),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF054582), Color(0xFF0a7ac2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu_book, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  article.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF054582), Color(0xFF0a7ac2)],
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
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_outline, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Нет сохранённых $type',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
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
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.star : Icons.star_border,
                        color: isFavorite
                            ? const Color(0xFFF59E0B)
                            : theme.colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                      onPressed: () {
                        _toggleArticleFavorite(article.id);
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  article.title,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  article.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant, height: 1.6),
                ),
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
