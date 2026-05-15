// lib/services/favorites_service.dart
import 'package:flutter/foundation.dart';

/// Глобальный сервис для управления избранными статьями и FAQ
class FavoritesService extends ChangeNotifier {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  // Хранилище ID избранных элементов
  final Set<String> _favoriteArticleIds = {};
  final Set<String> _favoriteFaqIds = {};

  // Геттеры для чтения
  Set<String> get favoriteArticleIds => Set.unmodifiable(_favoriteArticleIds);
  Set<String> get favoriteFaqIds => Set.unmodifiable(_favoriteFaqIds);

  // Инициализация (добавляем моковые элементы по умолчанию)
  void initialize() {
    // Добавляем моковые элементы по умолчанию
    if (_favoriteArticleIds.isEmpty && _favoriteFaqIds.isEmpty) {
      _favoriteArticleIds.add('1');
      _favoriteFaqIds.add('1');
      notifyListeners();
    }
  }

  // Проверка избранности статьи
  bool isArticleFavorite(String id) => _favoriteArticleIds.contains(id);

  // Проверка избранности FAQ
  bool isFaqFavorite(String id) => _favoriteFaqIds.contains(id);

  // Переключение избранности статьи
  void toggleArticleFavorite(String id) {
    if (_favoriteArticleIds.contains(id)) {
      _favoriteArticleIds.remove(id);
    } else {
      _favoriteArticleIds.add(id);
    }
    notifyListeners();
  }

  // Переключение избранности FAQ
  void toggleFaqFavorite(String id) {
    if (_favoriteFaqIds.contains(id)) {
      _favoriteFaqIds.remove(id);
    } else {
      _favoriteFaqIds.add(id);
    }
    notifyListeners();
  }

  // Очистка всех избранных (для теста)
  void clearAll() {
    _favoriteArticleIds.clear();
    _favoriteFaqIds.clear();
    notifyListeners();
  }
}
