// lib/services/mock_data.dart
import '../models/shu_model.dart';

class MockData {
  static final List<ShuModel> allShuList = [
    ShuModel(
      id: '1',
      type: 'ШУ-24М',
      objectNumber: 'ОБ-2024-001',
      customName: '',
      comment: '',
      stationType: 'Насосная станция',
      purpose: 'Водоснабжение',
      warrantyStatus: 'active',
      warrantyDaysRemaining: 245,
      warrantyStart: '15.01.2024',
      warrantyEnd: '15.01.2027',
      moderationStatus: 'active',
      unreadMessages: 2,
      addedDate: DateTime(2024, 1, 15),
    ),
    ShuModel(
      id: '2',
      type: 'ШУ-18К',
      objectNumber: 'ОБ-2024-002',
      customName: '',
      comment: '',
      stationType: 'Вентиляционная установка',
      purpose: 'Вентиляция',
      warrantyStatus: 'expiring',
      warrantyDaysRemaining: 28,
      warrantyStart: '20.02.2024',
      warrantyEnd: '20.02.2025',
      moderationStatus: 'active',
      unreadMessages: 0,
      addedDate: DateTime(2024, 2, 20),
    ),
    ShuModel(
      id: '3',
      type: 'ШУ-36П',
      objectNumber: 'ОБ-2023-045',
      customName: '',
      comment: '',
      stationType: 'Насосная станция',
      purpose: 'Канализация',
      warrantyStatus: 'expired',
      warrantyDaysRemaining: -30,
      warrantyStart: '05.12.2023',
      warrantyEnd: '05.12.2024',
      moderationStatus: 'active',
      unreadMessages: 1,
      addedDate: DateTime(2023, 12, 5),
    ),
  ];

  // Список чатов для каждого ШУ (тип 'cabinet')
  static List<Map<String, dynamic>> get allChats => [
        // Общие чаты
        {
          'id': 'ai',
          'name': 'ИИ Консультант',
          'lastMessage': 'Здравствуйте! Я готов помочь с любыми вопросами.',
          'time': '10:00',
          'unread': 0,
          'type': 'ai',
          'isLocked': false,
          'shuId': null,
        },
        {
          'id': 'general',
          'name': 'Общие вопросы',
          'lastMessage': 'Здравствуйте! Это общий чат техподдержки.',
          'time': '10:05',
          'unread': 0,
          'type': 'general',
          'isLocked': false,
          'shuId': null,
        },
        {
          'id': 'notes',
          'name': 'Заметки',
          'lastMessage': 'Ваши личные заметки',
          'time': '-',
          'unread': 0,
          'type': 'notes',
          'isLocked': false,
          'shuId': null,
        },
        // Чаты для каждого ШУ
        ...allShuList
            .where((shu) => shu.moderationStatus == 'active')
            .map((shu) {
          return {
            'id': shu.id,
            'name': shu.customName.isNotEmpty ? shu.customName : shu.type,
            'lastMessage': '',
            'time': '-',
            'unread': shu.unreadMessages,
            'type': 'cabinet',
            'isLocked': false,
            'shuId': shu.id,
            'shuType': shu.type,
          };
        }),
        // Чаты поддержки
        {
          'id': '1',
          'name': 'Поддержка SAVT',
          'lastMessage': 'Здравствуйте! Чем можем помочь?',
          'time': '10:30',
          'unread': 2,
          'type': 'support',
          'isLocked': true,
          'shuId': null,
        },
        {
          'id': '2',
          'name': 'Технический отдел',
          'lastMessage': 'Ваш запрос обработан.',
          'time': 'Вчера',
          'unread': 0,
          'type': 'tech',
          'isLocked': true,
          'shuId': null,
        },
        {
          'id': '3',
          'name': 'Гарантийный сервис',
          'lastMessage': 'Гарантия продлена до 2027 года.',
          'time': 'Пн',
          'unread': 1,
          'type': 'warranty',
          'isLocked': true,
          'shuId': null,
        },
      ];

  // Заявки на обслуживание
  static List<Map<String, dynamic>> get serviceRequests => [
        {
          'id': 'req1',
          'type': 'warranty',
          'requestType': 'service',
          'shuId': '1',
          'shuType': 'ШУ-24М',
          'shuObjectNumber': 'ОБ-2024-001',
          'status': 'open',
          'date': '20.04.2025',
          'description': 'Проблема с насосом',
        },
        {
          'id': 'req2',
          'type': 'non_warranty',
          'requestType': 'service',
          'shuId': '3',
          'shuType': 'ШУ-36П',
          'shuObjectNumber': 'ОБ-2023-045',
          'status': 'in_progress',
          'date': '18.04.2025',
          'description': 'Замена контроллера',
        },
        {
          'id': 'req3',
          'type': 'warranty',
          'requestType': 'service',
          'shuId': '2',
          'shuType': 'ШУ-18К',
          'shuObjectNumber': 'ОБ-2024-002',
          'status': 'closed',
          'date': '15.04.2025',
          'description': 'Настройка параметров',
        },
      ];

  // Заявки на модерацию ШУ
  static List<Map<String, dynamic>> get moderationRequests => [
        {
          'id': 'mod1',
          'requestType': 'moderation',
          'shuId': 'new1',
          'shuType': 'ШУ-24М',
          'shuObjectNumber': 'ОБ-2025-010',
          'status': 'pending',
          'date': '22.04.2025',
          'description': 'Заявка на добавление нового ШУ',
        },
        {
          'id': 'mod2',
          'requestType': 'moderation',
          'shuId': 'new2',
          'shuType': 'ШУ-18К',
          'shuObjectNumber': 'ОБ-2025-011',
          'status': 'approved',
          'date': '21.04.2025',
          'description': 'Заявка на добавление ШУ',
        },
      ];

  // Запросы документов
  static List<Map<String, dynamic>> get documentRequests => [
        {
          'id': 'doc1',
          'requestType': 'document',
          'documentName': 'Руководство по эксплуатации',
          'documentId': 'doc_001',
          'status': 'approved',
          'date': '19.04.2025',
          'description': 'Запрос технической документации',
        },
        {
          'id': 'doc2',
          'requestType': 'document',
          'documentName': 'Сертификат соответствия',
          'documentId': 'doc_002',
          'status': 'pending',
          'date': '23.04.2025',
          'description': 'Запрос сертификата',
        },
      ];

  // Объединённый список всех заявок
  static List<Map<String, dynamic>> get allRequests {
    return [...serviceRequests, ...moderationRequests, ...documentRequests];
  }

  // Запросы на присоединение к ШУ (share requests)
  static List<Map<String, dynamic>> get cabinetShareRequests => [];

  // Статичный список загруженных документов (для мока)
  static final Set<String> downloadedDocuments = {};

  // Статичный список кэшированных ШУ
  static final Map<String, ShuModel> cachedShu = {};
}
