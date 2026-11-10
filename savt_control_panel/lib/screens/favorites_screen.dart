// lib/screens/favorites_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../services/file_save_helper.dart';
import '../theme/app_spacing.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/skeletons.dart';
import '../widgets/animated_card.dart';
import '../widgets/keep_alive_wrapper.dart';
import '../main.dart'; // favoritesService, knowledgeService

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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(canRequestFocus: false);

  List<Map<String, dynamic>> _favoriteArticles = [];
  List<Map<String, dynamic>> _favoriteFaqs = [];
  bool _loadingArticles = false;
  bool _loadingFaqs = false;
  bool _showingArticleDetail = false;

  final List<int> _downloadingAttachmentIds = [];
  final Set<String> _downloadedAttachmentNames = {};

  @override
  void initState() {
    super.initState();
    favoritesService.addListener(_onFavoritesChanged);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadFavorites();
  }

  void _onFavoritesChanged() {
    if (mounted) {
      setState(() {
        _favoriteArticles.removeWhere((a) {
          final id = (a['id'] is num)
              ? (a['id'] as num).toInt()
              : (int.tryParse(a['id']?.toString() ?? '') ?? 0);
          return !favoritesService.isArticleFavorite(id);
        });
        _favoriteFaqs.removeWhere((f) {
          final id = (f['id'] is num)
              ? (f['id'] as num).toInt()
              : (int.tryParse(f['id']?.toString() ?? '') ?? 0);
          return !favoritesService.isFaqFavorite(id);
        });
      });
    }
  }

  Future<void> _loadFavorites() async {
    if (favoritesService.favoriteArticleIds.isEmpty &&
        favoritesService.favoriteFaqIds.isEmpty) {
      try {
        await favoritesService.loadFavorites();
      } catch (_) {}
    }
    await Future.wait([
      _loadFavoriteArticles(),
      _loadFavoriteFaqs(),
    ]);
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
      if (!mounted) return;
      setState(() {
        _favoriteArticles = articles;
        _loadingArticles = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingArticles = false);
    }
  }

  Future<void> _loadFavoriteFaqs() async {
    setState(() => _loadingFaqs = true);
    try {
      final ids = favoritesService.favoriteFaqIds.toList();
      final data = await knowledgeService.getFaqEntries(page: 1, size: 100);
      final allFaqs = List<Map<String, dynamic>>.from(data['items']);
      final filtered = allFaqs.where((faq) {
        final id = (faq['id'] is num)
            ? (faq['id'] as num).toInt()
            : (int.tryParse(faq['id']?.toString() ?? '') ?? 0);
        return ids.contains(id);
      }).toList();
      if (!mounted) return;
      setState(() {
        _favoriteFaqs = filtered;
        _loadingFaqs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFaqs = false);
    }
  }

  List<Map<String, dynamic>> get _filteredArticles {
    if (_searchQuery.isEmpty) return _favoriteArticles;
    return _favoriteArticles
        .where((a) =>
            (a['title'] ?? '')
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            (a['description'] ?? '')
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<Map<String, dynamic>> get _filteredFaqs {
    if (_searchQuery.isEmpty) return _favoriteFaqs;
    return _favoriteFaqs
        .where((f) =>
            (f['question'] ?? '')
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            (f['answer'] ?? '')
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    favoritesService.removeListener(_onFavoritesChanged);
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      currentNavIndex: 3,
      appBarTitle: 'Избранное',
      appBarLeading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      appBarAction: IconButton(
        icon: Icon(_isSearchExpanded ? Icons.close : Icons.search,
            color: Colors.white),
        onPressed: () {
          if (_isSearchExpanded) {
            _searchFocusNode.canRequestFocus = false;
            _searchFocusNode.unfocus(
                disposition: UnfocusDisposition.previouslyFocusedChild);
            FocusManager.instance.primaryFocus?.unfocus();
            setState(() {
              _isSearchExpanded = false;
              _searchQuery = '';
              _searchController.clear();
            });
          } else {
            _searchFocusNode.canRequestFocus = true;
            setState(() {
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
      body: ResponsiveContainer(
        maxWidth: 600,
        child: Column(
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
            _buildTabBar(),
            const SizedBox(height: 8),
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
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base, vertical: AppSpacing.md),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.4)),
        boxShadow: isDark
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
    if (_loadingArticles && _favoriteArticles.isEmpty) {
      return const SkeletonList();
    }
    if (_filteredArticles.isEmpty) return _buildEmptyState('Статьи');
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredArticles.length,
      itemBuilder: (context, index) =>
          _buildArticleCard(_filteredArticles[index], index),
    );
  }

  Widget _buildFaqTab() {
    if (_loadingFaqs && _favoriteFaqs.isEmpty) return const SkeletonList();
    if (_filteredFaqs.isEmpty) return _buildEmptyState('Вопросы');
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredFaqs.length,
      itemBuilder: (context, index) =>
          _buildFaqCard(_filteredFaqs[index], index),
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
    final hasTags =
        article['tags'] != null && (article['tags'] as List).isNotEmpty;
    final hasAttachments = (article['attachment_count'] ??
            (article['attachments'] is List
                ? (article['attachments'] as List).length
                : 0)) >
        0;

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
                    theme.colorScheme.secondary,
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
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
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
                      if (!favoritesService.isArticleFavorite(articleId)) {
                        _favoriteArticles.removeWhere((a) {
                          final aId = (a['id'] is num)
                              ? (a['id'] as num).toInt()
                              : int.tryParse(a['id'].toString());
                          return aId == articleId;
                        });
                      }
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
                  ...(article['tags'] as List).take(2).map<Widget>((tag) =>
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.15),
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
                        color: theme.colorScheme.primary
                            .withValues(alpha: 0.2),
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
                child: const Icon(Icons.help_outline,
                    color: Colors.white, size: 22),
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
                  color:
                      isFav ? Colors.amber : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
                onPressed: () async {
                  try {
                    await favoritesService.toggleFaqFavorite(faqId);
                    setState(() {
                      faq['is_favorited'] =
                          favoritesService.isFaqFavorite(faqId);
                      if (!favoritesService.isFaqFavorite(faqId)) {
                        _favoriteFaqs.removeWhere((f) {
                          final fId = (f['id'] is num)
                              ? (f['id'] as num).toInt()
                              : int.tryParse(f['id'].toString());
                          return fId == faqId;
                        });
                      }
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

  Widget _buildEmptyState(String type) {
    final theme = Theme.of(context);
    final isArticles = type == 'Статьи';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isArticles ? Icons.menu_book_outlined : Icons.help_outline,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            isArticles ? 'Нет сохранённых статей' : 'Нет сохранённых вопросов',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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

  Future<void> _downloadAttachment(
      int articleId, Map<String, dynamic> att) async {
    final attId = att['id'];
    final attTitle = att['title'] ?? 'Вложение';
    final fileUrl = att['file_url'] ?? att['url'];
    final fileName = FileSaveHelper.ensureExtension(attTitle, fileUrl);

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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(attTitle,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDownloading) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    progress > 0
                        ? 'Загрузка: ${(progress * 100).toStringAsFixed(0)}%'
                        : 'Подготовка к загрузке...',
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.start,
                  ),
                ] else if (errorMsg != null) ...[
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: AppSpacing.base),
                  Text(errorMsg!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center),
                ] else ...[
                  const Icon(Icons.check_circle_outline,
                      color: Colors.green, size: 40),
                  const SizedBox(height: AppSpacing.base),
                  const Text('Файл открывается...',
                      textAlign: TextAlign.center),
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
      Navigator.pop(context);

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
        favoritesService.syncSingleArticle(
            articleId, article['is_favorited'] as bool);
      }
      if (article['attachments'] != null &&
          article['attachments'].isNotEmpty) {
        final downloaded = <String>{};
        for (final att in article['attachments']) {
          final fileUrl = att['file_url'] ?? att['url'];
          final fileName = FileSaveHelper.ensureExtension(
              att['title'] ?? 'Вложение', fileUrl);
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
        constraints: const BoxConstraints(maxWidth: 600),
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            double dragDistance = 0;
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
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
                      if ((details.primaryVelocity != null &&
                              details.primaryVelocity! > 100) ||
                          dragDistance > 50) {
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
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.5),
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
                                    fallback:
                                        article['is_favorited'] as bool?,
                                  )
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: favoritesService.isArticleFavorite(
                                    articleId,
                                    fallback:
                                        article['is_favorited'] as bool?,
                                  )
                                      ? Colors.amber
                                      : theme.colorScheme.onSurfaceVariant,
                                  size: 24,
                                ),
                                onPressed: () async {
                                  try {
                                    await favoritesService
                                        .toggleArticleFavorite(articleId);
                                    article['is_favorited'] = favoritesService
                                        .isArticleFavorite(articleId);
                                    setModalState(() {});
                                    if (mounted) {
                                      setState(() {
                                        if (!favoritesService
                                            .isArticleFavorite(articleId)) {
                                          _favoriteArticles.removeWhere((a) {
                                            final aId = (a['id'] is num)
                                                ? (a['id'] as num).toInt()
                                                : int.tryParse(
                                                    a['id'].toString());
                                            return aId == articleId;
                                          });
                                        }
                                      });
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Не удалось обновить избранное'),
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
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
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
                            Text('Вложения:',
                                style: theme.textTheme.titleSmall),
                            ...article['attachments'].map<Widget>((att) {
                              final attId = att['id'];
                              final fileUrl = att['file_url'] ?? att['url'];
                              final fileName = FileSaveHelper.ensureExtension(
                                  att['title'] ?? 'Вложение', fileUrl);
                              final isDownloaded =
                                  _downloadedAttachmentNames.contains(fileName);
                              final isDownloading =
                                  _downloadingAttachmentIds.contains(attId);
                              return Material(
                                color: theme.colorScheme.surface,
                                child: ListTile(
                                  title: Text(att['title']),
                                  trailing: isDownloading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : isDownloaded && !kIsWeb
                                          ? OutlinedButton.icon(
                                              icon: const Icon(
                                                  Icons.visibility,
                                                  size: 16),
                                              label:
                                                  const Text('Просмотр'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    theme.colorScheme.primary,
                                                side: BorderSide(
                                                    color: theme
                                                        .colorScheme.primary),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8),
                                              ),
                                              onPressed: () =>
                                                  _openDownloadedAttachment(
                                                      fileName),
                                            )
                                          : ElevatedButton(
                                              onPressed: () =>
                                                  _downloadAttachment(
                                                      articleId, att),
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
            content: Text('Ошибка загрузки: $e'),
            backgroundColor: Colors.red));
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
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          double dragDistance = 0;
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
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
                    if ((details.primaryVelocity != null &&
                            details.primaryVelocity! > 100) ||
                        dragDistance > 50) {
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
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.5),
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
                                  await favoritesService
                                      .toggleFaqFavorite(faqId);
                                  faq['is_favorited'] =
                                      favoritesService.isFaqFavorite(faqId);
                                  setModalState(() {});
                                  if (mounted) {
                                    setState(() {
                                      if (!favoritesService
                                          .isFaqFavorite(faqId)) {
                                        _favoriteFaqs.removeWhere((f) {
                                          final fId = (f['id'] is num)
                                              ? (f['id'] as num).toInt()
                                              : int.tryParse(
                                                  f['id'].toString());
                                          return fId == faqId;
                                        });
                                      }
                                    });
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Не удалось обновить избранное'),
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
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
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
}
