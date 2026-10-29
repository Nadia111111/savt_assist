import 'package:flutter_test/flutter_test.dart';
import 'package:control_panel/models/chat_message.dart';

void main() {
  group('ChatMessage senderName and displaySenderName tests', () {
    test('Shows bot name "Ася" when senderName is "Ася"', () {
      final json = {
        'id': 1,
        'text': 'Привет',
        'is_own': false,
        'sender_id': null,
        'sender_name': 'Ася',
        'created_at': '2026-10-28T12:00:00Z',
      };
      final msg = ChatMessage.fromJson(json, 999);
      expect(msg.displaySenderName, equals('Ася'));
      expect(msg.isOwn, isFalse);
    });

    test('Shows operator full name (ФИО) when senderName is provided', () {
      final json = {
        'id': 2,
        'text': 'Здравствуйте, чем помочь?',
        'is_own': false,
        'sender_id': 42,
        'sender_name': 'Сидоров Петр Алексеевич',
        'created_at': '2026-10-28T12:01:00Z',
      };
      final msg = ChatMessage.fromJson(json, 999);
      expect(msg.displaySenderName, equals('Сидоров Петр Алексеевич'));
      expect(msg.isOwn, isFalse);
    });

    test('Defaults to "Ася" for bot when senderName is null and senderId is null/0', () {
      final json = {
        'id': 3,
        'text': 'Бот сообщение',
        'is_own': false,
        'sender_id': null,
        'sender_name': null,
        'created_at': '2026-10-28T12:02:00Z',
      };
      final msg = ChatMessage.fromJson(json, 999);
      expect(msg.displaySenderName, equals('Ася'));
    });

    test('Defaults to "Оператор" when senderName is empty/null and senderId > 0', () {
      final json = {
        'id': 4,
        'text': 'Сообщение оператора без имени',
        'is_own': false,
        'sender_id': 105,
        'sender_name': '   ',
        'created_at': '2026-10-28T12:03:00Z',
      };
      final msg = ChatMessage.fromJson(json, 999);
      expect(msg.displaySenderName, equals('Оператор'));
    });
  });
}
