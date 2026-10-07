// lib/screens/favorites_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/skeletons.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/animated_card.dart';
import '../main.dart'; // favoritesService

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _favoriteArticles = [];
  List<Map<String, dynamic>> _favoriteFaqs = [];
  bool _loadingArticles = false;
  bool _loadingFaqs = false;
  bool _showingArticleDetail = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    await _loadFavoriteArticles();
    await _loadFavoriteFaqs();
  }

  Future<void> _onRefresh() async {
    await _loadFavorites();
  }

  Future<void> _loadFavoriteArticles() async {
    setState(() => _loadingArticles = true);
    try {
      final ids = favoritesService.favoriteArticleIds.toList();
      final List<Map<String, dynamic>> articles = [];
      for (final id in ids) {
        try {
          final article = await knowledgeService.getKbArticleDetail(id);
          articles.add(article);
        } catch (_) {}
      }
      setState(() {
        _favoriteArticles = articles;
        _loadingArticles = false;
      });
    } catch (e) {
      setState(() => _loadingArticles = false);
    }
  }

  Future<void> _loadFavoriteFaqs() async {
    setState(() => _loadingFaqs = true);
    try {
      final ids = favoritesService.favoriteFaqIds.toList();
      final data = await knowledgeService.getFaqEntries(page: 1, size: 100);
      final allFaqs = List<Map<String, dynamic>>.from(data['items']);
      final filtered = allFaqs.where((faq) => ids.contains(faq['id'])).toList();
      setState(() {
        _favoriteFaqs = filtered;
        _loadingFaqs = false;
      });
    } catch (e) {
      setState(() => _loadingFaqs = false);
    }
  }

  List<Map<String, dynamic>> get _filteredArticles {
    if (_searchQuery.isEmpty) return _favoriteArticles;
    return _favoriteArticles
        .where((a) =>
            a['title'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (a['description'] ?? '')
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<Map<String, dynamic>> get _filteredFaqs {
    if (_searchQuery.isEmpty) return _favoriteFaqs;
    return _favoriteFaqs
        .where((f) =>
            f['question'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
            f['answer'].toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
              padding:
                  _isSearchExpanded ? const EdgeInsets.all(AppSpacing.base) : EdgeInsets.zero,
              child: _isSearchExpanded
                  ? _buildSearchField()
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            _buildTabBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: const Color(0xFF0a7ac2),
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildArticlesTab(), _buildFaqTab()],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavBar: BottomNavBar(
        currentIndex: 3,
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
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, 0),
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
    if (_loadingArticles) {
      return const SkeletonList();
    }
    if (_filteredArticles.isEmpty) return _buildEmptyState('Статьи');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredArticles.length,
      itemBuilder: (context, index) =>
          _buildArticleCard(_filteredArticles[index], index),
    );
  }

  Widget _buildFaqTab() {
    if (_loadingFaqs) return const SkeletonList();
    if (_filteredFaqs.isEmpty) return _buildEmptyState('Вопросы');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredFaqs.length,
      itemBuilder: (context, index) =>
          _buildFaqCard(_filteredFaqs[index], index),
    );
  }

  Widget _buildArticleCard(Map<String, dynamic> article, int index) {
    final theme = Theme.of(context);
    final isFavorite = favoritesService.isArticleFavorite(article['id']);
    return AnimatedCard(
      index: index,
      onTap: () => _showArticleDetail(article),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF054582), Color(0xFF0a7ac2)]),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: const Icon(Icons.menu_book, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article['title'],
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(article['description'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.start,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite
                    ? const Color(0xFFF59E0B)
                    : theme.colorScheme.onSurfaceVariant),
            onPressed: () {
              favoritesService.toggleArticleFavorite(article['id']);
              setState(() {
                if (isFavorite) {
                  _favoriteArticles
                      .removeWhere((a) => a['id'] == article['id']);
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFaqCard(Map<String, dynamic> faq, int index) {
    final theme = Theme.of(context);
    final isFavorite = favoritesService.isFaqFavorite(faq['id']);
    return AnimatedCard(
      index: index,
      child: Theme(
        data: theme.copyWith(dividerColor: theme.colorScheme.outline),
        child: ExpansionTile(
          title: Row(
            children: [
              Expanded(
                  child: Text(faq['question'],
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600))),
              IconButton(
                icon: Icon(isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite
                        ? const Color(0xFFF59E0B)
                        : theme.colorScheme.onSurfaceVariant),
                onPressed: () {
                  favoritesService.toggleFaqFavorite(faq['id']);
                  setState(() {
                    if (isFavorite) {
                      _favoriteFaqs.removeWhere((f) => f['id'] == faq['id']);
                    }
                  });
                },
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              child: Text(faq['answer'],
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant, height: 1.5),
                  textAlign: TextAlign.start),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/chat/support'),
                  icon: const Icon(Icons.chat, size: 16),
                  label: const Text('Перейти в чат'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
          Text('Нет сохранённых $type',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Future<void> _showArticleDetail(Map<String, dynamic> article) async {
    if (_showingArticleDetail) return;
    _showingArticleDetail = true;
    final theme = Theme.of(context);
    final isFavorite = favoritesService.isArticleFavorite(article['id']);
    try {
      await showModalBottomSheet(
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
                              borderRadius: BorderRadius.circular(2)),
                      ),
                      IconButton(
                        icon: Icon(isFavorite ? Icons.star : Icons.star_border,
                            color: isFavorite
                                ? const Color(0xFFF59E0B)
                                : theme.colorScheme.onSurfaceVariant),
                        onPressed: () {
                          favoritesService.toggleArticleFavorite(article['id']);
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(article['title'],
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
Text(article['description'] ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.6),
                        textAlign: TextAlign.start),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/chat/support'),
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
    } finally {
      _showingArticleDetail = false;
    }
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

