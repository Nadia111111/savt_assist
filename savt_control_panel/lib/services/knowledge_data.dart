// lib/services/knowledge_data.dart
/// Глобальные моковые данные для Базы знаний
/// Доступны для использования на всех экранах

// Подкатегория
class SubCategory {
  final String id;
  final String name;

  const SubCategory({required this.id, required this.name});
}

// Категория с поддержкой иерархии
class CategoryModel {
  final String id;
  final String name;
  final List<SubCategory> subCategories;

  const CategoryModel({
    required this.id,
    required this.name,
    this.subCategories = const [],
  });
}

// Статья
class ArticleModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String? subCategory;
  final List<String> tags;
  final DateTime updatedAt;
  final bool hasAttachments;

  const ArticleModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.subCategory,
    required this.tags,
    required this.updatedAt,
    required this.hasAttachments,
  });

  // Создание копии с изменённым полем
  ArticleModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? subCategory,
    List<String>? tags,
    DateTime? updatedAt,
    bool? hasAttachments,
  }) {
    return ArticleModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      tags: tags ?? this.tags,
      updatedAt: updatedAt ?? this.updatedAt,
      hasAttachments: hasAttachments ?? this.hasAttachments,
    );
  }
}

// FAQ
class FAQModel {
  final String id;
  final String question;
  final String answer;
  final String category;
  final String? subCategory;
  final List<String> tags;
  final List<String> relatedDevices;
  final List<String>? relatedQuestions;

  const FAQModel({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    this.subCategory,
    required this.tags,
    required this.relatedDevices,
    this.relatedQuestions,
  });
}

// Глобальный список категорий
final List<CategoryModel> categories = [
  CategoryModel(
    id: 'introduction',
    name: 'Введение',
    subCategories: [
      SubCategory(id: 'basics', name: 'Основы'),
      SubCategory(id: 'quickstart', name: 'Быстрый старт'),
    ],
  ),
  CategoryModel(
    id: 'installation',
    name: 'Установка',
    subCategories: [
      SubCategory(id: 'hardware', name: 'Аппаратная'),
      SubCategory(id: 'software', name: 'Программная'),
    ],
  ),
  CategoryModel(
    id: 'configuration',
    name: 'Настройка',
    subCategories: [
      SubCategory(id: 'security', name: 'Безопасность'),
      SubCategory(id: 'network', name: 'Сеть'),
    ],
  ),
  CategoryModel(
    id: 'diagnostics',
    name: 'Диагностика',
    subCategories: [
      SubCategory(id: 'connection', name: 'Связь'),
      SubCategory(id: 'errors', name: 'Ошибки'),
    ],
  ),
];

// Глобальный список статей
final List<ArticleModel> allArticles = [
  ArticleModel(
    id: '1',
    title: 'Быстрый старт: Подключение ШУ-24М',
    description: 'Пошаговая инструкция по первому запуску и базовой настройке',
    category: 'Введение',
    subCategory: 'quickstart',
    tags: ['старт', 'ШУ-24М'],
    updatedAt: DateTime(2026, 4, 15),
    hasAttachments: true,
  ),
  ArticleModel(
    id: '2',
    title: 'Введение в систему SAVT',
    description: 'Обзор архитектуры и основных компонентов системы',
    category: 'Введение',
    subCategory: 'basics',
    tags: ['обзор', 'архитектура'],
    updatedAt: DateTime(2026, 4, 10),
    hasAttachments: false,
  ),
  ArticleModel(
    id: '3',
    title: 'Диагностика ошибок связи',
    description: 'Руководство по устранению проблем с подключением',
    category: 'Диагностика',
    subCategory: 'connection',
    tags: ['ошибки', 'связь'],
    updatedAt: DateTime(2026, 4, 20),
    hasAttachments: false,
  ),
  ArticleModel(
    id: '4',
    title: 'Настройка параметров безопасности',
    description: 'Конфигурация защитных функций и аварийных режимов',
    category: 'Настройка',
    subCategory: 'security',
    tags: ['безопасность'],
    updatedAt: DateTime(2026, 4, 22),
    hasAttachments: true,
  ),
  ArticleModel(
    id: '5',
    title: 'Установка аппаратного обеспечения',
    description: 'Инструкция по физическому монтажу и подключению',
    category: 'Установка',
    subCategory: 'hardware',
    tags: ['монтаж', 'аппаратура'],
    updatedAt: DateTime(2026, 4, 18),
    hasAttachments: true,
  ),
];

// Глобальный список FAQ
final List<FAQModel> allFaqs = [
  FAQModel(
    id: '1',
    question: 'Как сбросить настройки до заводских?',
    answer:
        'Для сброса настроек:\n1) Отключите питание\n2) Зажмите кнопку RESET на 10 секунд\n3) Подключите питание',
    category: 'Настройка',
    subCategory: 'security',
    tags: ['сброс'],
    relatedDevices: ['ШУ-24М', 'ШУ-18К'],
    relatedQuestions: ['2', '3'],
  ),
  FAQModel(
    id: '2',
    question: 'Что делать при потере связи?',
    answer:
        'Проверьте:\n1) Подключение кабелей\n2) Настройки сети\n3) Статус сервисов',
    category: 'Диагностика',
    subCategory: 'connection',
    tags: ['связь', 'ошибка'],
    relatedDevices: ['ШУ-24М'],
    relatedQuestions: ['1', '3'],
  ),
  FAQModel(
    id: '3',
    question: 'Как добавить новое устройство?',
    answer: 'Через меню "Устройства" → "Добавить" → введите данные устройства',
    category: 'Установка',
    subCategory: 'software',
    tags: ['устройство', 'добавление'],
    relatedDevices: ['ШУ-24М'],
    relatedQuestions: ['1'],
  ),
];

// Вспомогательная функция для получения имени подкатегории по ID
String? getSubCategoryName(String? subCategoryId, String? parentCategoryName) {
  if (subCategoryId == null || parentCategoryName == null) return null;

  final category = categories.firstWhere(
    (c) => c.name == parentCategoryName,
    orElse: () => const CategoryModel(id: '', name: ''),
  );

  if (category.name.isEmpty) return null;

  final subCat = category.subCategories.firstWhere(
    (s) => s.id == subCategoryId,
    orElse: () => const SubCategory(id: '', name: ''),
  );

  return subCat.name.isEmpty ? null : subCat.name;
}
