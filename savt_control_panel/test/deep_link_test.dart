import 'package:flutter_test/flutter_test.dart';
import 'package:control_panel/services/deep_link_service.dart';

void main() {
  group('DeepLink parsing tests', () {
    test('savt://project/{code}', () {
      final uri = Uri.parse('savt://project/PRJ-001');
      final result = parseDeepLink(uri);
      expect(result, isNotNull);
      expect(result!.type, equals('project'));
      expect(result.code, equals('PRJ-001'));
      expect(result.rawData, equals('savt://project/PRJ-001'));
    });

    test('savt://cabinet/{code}', () {
      final uri = Uri.parse('savt://cabinet/SHU-777');
      final result = parseDeepLink(uri);
      expect(result, isNotNull);
      expect(result!.type, equals('cabinet'));
      expect(result.code, equals('SHU-777'));
    });

    test('savt://add/project/{code}', () {
      final uri = Uri.parse('savt://add/project/PRJ-002');
      final result = parseDeepLink(uri);
      expect(result, isNotNull);
      expect(result!.type, equals('project'));
      expect(result.code, equals('PRJ-002'));
    });

    test('savt://add/cabinet/{code}', () {
      final uri = Uri.parse('savt://add/cabinet/SHU-888');
      final result = parseDeepLink(uri);
      expect(result, isNotNull);
      expect(result!.type, equals('cabinet'));
      expect(result.code, equals('SHU-888'));
    });

    test('savt:///project/{code} with triple slash', () {
      final uri = Uri.parse('savt:///project/PRJ-003');
      final result = parseDeepLink(uri);
      expect(result, isNotNull);
      expect(result!.type, equals('project'));
      expect(result.code, equals('PRJ-003'));
    });

    test('https://helper.savt.by/add/project/{code}', () {
      final uri = Uri.parse('https://helper.savt.by/add/project/PRJ-004');
      final result = parseDeepLink(uri);
      expect(result, isNotNull);
      expect(result!.type, equals('project'));
      expect(result.code, equals('PRJ-004'));
    });

    test('https://helper.savt.by/project/{code}', () {
      final uri = Uri.parse('https://helper.savt.by/project/PRJ-005');
      final result = parseDeepLink(uri);
      expect(result, isNotNull);
      expect(result!.type, equals('project'));
      expect(result.code, equals('PRJ-005'));
    });

    test('savt://chat/{id}', () {
      final uri = Uri.parse('savt://chat/123');
      final result = parseDeepLink(uri);
      expect(result, isNotNull);
      expect(result!.type, equals('chat'));
      expect(result.code, equals('123'));
    });

    test('savt://request/{id}', () {
      final uri = Uri.parse('savt://request/456');
      final result = parseDeepLink(uri);
      expect(result, isNotNull);
      expect(result!.type, equals('request'));
      expect(result.code, equals('456'));
    });

    test('savt://reclamation/{id}', () {
      final uri = Uri.parse('savt://reclamation/789');
      final result = parseDeepLink(uri);
      expect(result, isNotNull);
      expect(result!.type, equals('reclamation'));
      expect(result.code, equals('789'));
    });

    test('savt://project/{code} with = and _ does not corrupt code', () {
      const raw = 'savt://project/SEC_abc_123=XYZ==';
      final uri = Uri.parse(raw);
      final result = parseDeepLink(uri);
      expect(result, isNotNull);
      expect(result!.type, equals('project'));
      expect(result.code, equals('SEC_abc_123=XYZ=='));
      expect(result.rawData, equals(raw));
    });

    test('unrelated link should return null', () {
      final uri = Uri.parse('https://example.com/test');
      final result = parseDeepLink(uri);
      expect(result, isNull);
    });
  });
}
