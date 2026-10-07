// lib/services/favorites_service.dart
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'network_service.dart';
import 'offline_service.dart';

class FavoritesService extends ChangeNotifier {
  final ApiClient _apiClient;
  Set<int> _favoriteArticleIds = {};
  Set<int> _favoriteFaqIds = {};
  Set<int> _favoriteProjectIds = {};
  final Set<int> _touchedArticleIds = {};
  final Set<int> _touchedFaqIds = {};
  bool _isLoading = false;

  FavoritesService(this._apiClient);

  Future<void> loadFavorites() async {
    if (_isLoading) return;
    if (!NetworkService.isOnline) {
      await _loadFromCache();
      return;
    }

    _isLoading = true;
    try {
      try {
        final articles = await _apiClient.dio.get(
          '/favorites?entity_type=kb_article&size=100',
          options: Options(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        _favoriteArticleIds = Set.from(
            (articles.data['items'] as List).map((e) => (e['entity_id'] as num).toInt()));
        await OfflineService().saveCache('favorite_articles_ids', _favoriteArticleIds.toList());
      } catch (e) {
        debugPrint('Error loading kb_article favorites: $e');
        final cached = await OfflineService().getCache('favorite_articles_ids');
        if (cached != null) {
          _favoriteArticleIds = Set<int>.from(List<int>.from(cached));
        }
      }

      try {
        final faqs = await _apiClient.dio.get(
          '/favorites?entity_type=faq_entry&size=100',
          options: Options(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        _favoriteFaqIds = Set.from(
            (faqs.data['items'] as List).map((e) => (e['entity_id'] as num).toInt()));
        await OfflineService().saveCache('favorite_faqs_ids', _favoriteFaqIds.toList());
      } catch (e) {
        debugPrint('Error loading faq_entry favorites: $e');
        final cached = await OfflineService().getCache('favorite_faqs_ids');
        if (cached != null) {
          _favoriteFaqIds = Set<int>.from(List<int>.from(cached));
        }
      }

      notifyListeners();
    } catch (e) {
      await _loadFromCache();
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _loadFromCache() async {
    final offline = OfflineService();
    final cachedArticles = await offline.getCache('favorite_articles_ids');
    final cachedFaqs = await offline.getCache('favorite_faqs_ids');
    final cachedProjects = await offline.getCache('favorite_projects_ids');
    if (cachedArticles != null) {
      _favoriteArticleIds = Set<int>.from(List<int>.from(cachedArticles));
    }
    if (cachedFaqs != null) {
      _favoriteFaqIds = Set<int>.from(List<int>.from(cachedFaqs));
    }
    if (cachedProjects != null) {
      _favoriteProjectIds = Set<int>.from(List<int>.from(cachedProjects));
    }
    notifyListeners();
  }

  // Статьи
  Future<void> toggleArticleFavorite(int articleId) async {
    _touchedArticleIds.add(articleId);
    final bool wasFavorite = _favoriteArticleIds.contains(articleId);

    // Оптимистичное обновление UI
    if (wasFavorite) {
      _favoriteArticleIds.remove(articleId);
    } else {
      _favoriteArticleIds.add(articleId);
    }
    notifyListeners();

    try {
      if (wasFavorite) {
        await _apiClient.dio.delete('/favorites/kb_article/$articleId');
      } else {
        await _apiClient.dio.post('/favorites',
            data: {'entity_type': 'kb_article', 'entity_id': articleId});
      }
      await OfflineService().saveCache('favorite_articles_ids', _favoriteArticleIds.toList());
    } catch (e) {
      debugPrint('Error toggling article favorite: $e');
      // Если сервер вернул 400 или 409 (уже в избранном), оставляем в избранном
      if (e is DioException && (e.response?.statusCode == 400 || e.response?.statusCode == 409)) {
        if (!wasFavorite) {
          _favoriteArticleIds.add(articleId);
          await OfflineService().saveCache('favorite_articles_ids', _favoriteArticleIds.toList());
          notifyListeners();
          return;
        }
      }
      // Если на удаление вернул 404 (уже удалено на сервере), оставляем удаленным
      if (e is DioException && e.response?.statusCode == 404 && wasFavorite) {
        _favoriteArticleIds.remove(articleId);
        await OfflineService().saveCache('favorite_articles_ids', _favoriteArticleIds.toList());
        notifyListeners();
        return;
      }

      // Откат при сетевой или иной серверной ошибке
      if (wasFavorite) {
        _favoriteArticleIds.add(articleId);
      } else {
        _favoriteArticleIds.remove(articleId);
      }
      notifyListeners();
      rethrow;
    }
  }

  bool isArticleFavorite(int articleId, {bool? fallback}) {
    if (_touchedArticleIds.contains(articleId)) {
      return _favoriteArticleIds.contains(articleId);
    }
    if (fallback != null) {
      if (fallback) {
        _favoriteArticleIds.add(articleId);
      } else {
        _favoriteArticleIds.remove(articleId);
      }
      return fallback;
    }
    return _favoriteArticleIds.contains(articleId);
  }

  void syncArticlesFavorited(List<dynamic> items) {
    bool changed = false;
    for (final item in items) {
      if (item is Map && item['id'] != null && item['is_favorited'] is bool) {
        final int id = (item['id'] as num).toInt();
        final bool isFav = item['is_favorited'] as bool;
        _touchedArticleIds.add(id);
        if (isFav) {
          if (_favoriteArticleIds.add(id)) changed = true;
        } else {
          if (_favoriteArticleIds.remove(id)) changed = true;
        }
      }
    }
    if (changed) {
      OfflineService().saveCache('favorite_articles_ids', _favoriteArticleIds.toList());
      notifyListeners();
    }
  }

  void syncSingleArticle(int articleId, bool isFavorited) {
    _touchedArticleIds.add(articleId);
    bool changed = false;
    if (isFavorited) {
      if (_favoriteArticleIds.add(articleId)) changed = true;
    } else {
      if (_favoriteArticleIds.remove(articleId)) changed = true;
    }
    if (changed) {
      OfflineService().saveCache('favorite_articles_ids', _favoriteArticleIds.toList());
      notifyListeners();
    }
  }

  Set<int> get favoriteArticleIds => _favoriteArticleIds;

  // FAQ
  Future<void> toggleFaqFavorite(int faqId) async {
    _touchedFaqIds.add(faqId);
    final bool wasFavorite = _favoriteFaqIds.contains(faqId);

    // Оптимистичное обновление UI
    if (wasFavorite) {
      _favoriteFaqIds.remove(faqId);
    } else {
      _favoriteFaqIds.add(faqId);
    }
    notifyListeners();

    try {
      if (wasFavorite) {
        await _apiClient.dio.delete('/favorites/faq_entry/$faqId');
      } else {
        await _apiClient.dio.post('/favorites',
            data: {'entity_type': 'faq_entry', 'entity_id': faqId});
      }
      await OfflineService().saveCache('favorite_faqs_ids', _favoriteFaqIds.toList());
    } catch (e) {
      debugPrint('Error toggling faq favorite: $e');
      if (e is DioException && (e.response?.statusCode == 400 || e.response?.statusCode == 409)) {
        if (!wasFavorite) {
          _favoriteFaqIds.add(faqId);
          await OfflineService().saveCache('favorite_faqs_ids', _favoriteFaqIds.toList());
          notifyListeners();
          return;
        }
      }
      if (e is DioException && e.response?.statusCode == 404 && wasFavorite) {
        _favoriteFaqIds.remove(faqId);
        await OfflineService().saveCache('favorite_faqs_ids', _favoriteFaqIds.toList());
        notifyListeners();
        return;
      }

      if (wasFavorite) {
        _favoriteFaqIds.add(faqId);
      } else {
        _favoriteFaqIds.remove(faqId);
      }
      notifyListeners();
      rethrow;
    }
  }

  bool isFaqFavorite(int faqId, {bool? fallback}) {
    if (_touchedFaqIds.contains(faqId)) {
      return _favoriteFaqIds.contains(faqId);
    }
    if (fallback != null) {
      if (fallback) {
        _favoriteFaqIds.add(faqId);
      } else {
        _favoriteFaqIds.remove(faqId);
      }
      return fallback;
    }
    return _favoriteFaqIds.contains(faqId);
  }

  void syncFaqsFavorited(List<dynamic> items) {
    bool changed = false;
    for (final item in items) {
      if (item is Map && item['id'] != null && item['is_favorited'] is bool) {
        final int id = (item['id'] as num).toInt();
        final bool isFav = item['is_favorited'] as bool;
        _touchedFaqIds.add(id);
        if (isFav) {
          if (_favoriteFaqIds.add(id)) changed = true;
        } else {
          if (_favoriteFaqIds.remove(id)) changed = true;
        }
      }
    }
    if (changed) {
      OfflineService().saveCache('favorite_faqs_ids', _favoriteFaqIds.toList());
      notifyListeners();
    }
  }

  Set<int> get favoriteFaqIds => _favoriteFaqIds;

  // Проекты (закрепление)
  static const int maxFavoriteProjects = 5;

  Future<bool> toggleProjectFavorite(int projectId) async {
    if (_favoriteProjectIds.contains(projectId)) {
      _favoriteProjectIds.remove(projectId);
    } else {
      if (_favoriteProjectIds.length >= maxFavoriteProjects) {
        return false;
      }
      _favoriteProjectIds.add(projectId);
    }
    await OfflineService().saveCache('favorite_projects_ids', _favoriteProjectIds.toList());
    notifyListeners();
    return true;
  }

  bool isProjectFavorite(int projectId) =>
      _favoriteProjectIds.contains(projectId);
  Set<int> get favoriteProjectIds => _favoriteProjectIds;
}
