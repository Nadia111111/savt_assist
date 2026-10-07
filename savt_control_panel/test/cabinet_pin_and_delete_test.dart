import 'package:flutter_test/flutter_test.dart';
import 'package:control_panel/models/cabinet.dart';
import 'package:control_panel/models/project.dart';

void main() {
  group('Cabinet & Project Model tests', () {
    test('Cabinet.fromJson correctly parses is_pinned = true', () {
      final json = {
        'id': 101,
        'cabinet_type': 'ШУ Насосной',
        'object_number': 'OBJ-101',
        'custom_name': 'Основной шкаф',
        'unread_count': 3,
        'warranty_status': 'active',
        'is_pinned': true,
        'project_id': null,
      };

      final cabinet = Cabinet.fromJson(json);
      expect(cabinet.cabinetId, equals(101));
      expect(cabinet.type, equals('ШУ Насосной'));
      expect(cabinet.customName, equals('Основной шкаф'));
      expect(cabinet.isPinned, isTrue);
      expect(cabinet.projectId, isNull);
    });

    test('Cabinet.fromJson defaults is_pinned to false when omitted', () {
      final json = {
        'cabinet_id': 102,
        'type': 'ШУ Вентиляции',
        'object_number': 'OBJ-102',
        'custom_name': '',
        'unread_count': 0,
        'warranty_status': 'expired',
        'project_id': 5,
        'project_name': 'Завод 1',
      };

      final cabinet = Cabinet.fromJson(json);
      expect(cabinet.cabinetId, equals(102));
      expect(cabinet.isPinned, isFalse);
      expect(cabinet.projectId, equals(5));
      expect(cabinet.projectName, equals('Завод 1'));
    });

    test('Cabinet.copyWith updates isPinned and other fields properly', () {
      final cab = Cabinet(
        cabinetId: 200,
        type: 'Тип А',
        objectNumber: 'NUM-200',
        customName: 'Шкаф 200',
        unreadCount: 0,
        warrantyStatus: 'active',
        isPinned: false,
      );

      final updated = cab.copyWith(isPinned: true, customName: 'Новое имя');
      expect(updated.cabinetId, equals(200));
      expect(updated.isPinned, isTrue);
      expect(updated.customName, equals('Новое имя'));
      expect(updated.type, equals('Тип А'));
    });

    test('ProjectCabinetInfo correctly parses is_pinned', () {
      final json = {
        'id': 301,
        'type': 'ШУ КНС',
        'object_number': 'KNS-301',
        'admin_internal_name': 'КНС Север',
        'is_pinned': true,
      };

      final info = ProjectCabinetInfo.fromJson(json);
      expect(info.id, equals(301));
      expect(info.isPinned, isTrue);
      expect(info.adminInternalName, equals('КНС Север'));
    });
  });

  group('Cabinet deletion & pin business logic tests', () {
    test('Cabinet without project (projectId == null or 0) can be deleted directly', () {
      final cabStandalone = Cabinet(
        cabinetId: 1,
        type: 'ШУ',
        objectNumber: '001',
        customName: 'Одиночный',
        unreadCount: 0,
        warrantyStatus: 'active',
        projectId: null,
      );

      final bool canDeleteDirectly = cabStandalone.projectId == null || cabStandalone.projectId == 0;
      expect(canDeleteDirectly, isTrue);
    });

    test('Cabinet inside project (projectId != null && > 0) cannot be deleted directly (requires leaving project)', () {
      final cabInProject = Cabinet(
        cabinetId: 2,
        type: 'ШУ',
        objectNumber: '002',
        customName: 'Проектный',
        unreadCount: 0,
        warrantyStatus: 'active',
        projectId: 42,
        projectName: 'Большой проект',
      );

      final bool canDeleteDirectly = cabInProject.projectId == null || cabInProject.projectId == 0;
      expect(canDeleteDirectly, isFalse);
    });

    test('Toggling pin status when selecting multiple cabinets', () {
      final cabinets = [
        Cabinet(
          cabinetId: 1,
          type: 'ШУ 1',
          objectNumber: '01',
          customName: '1',
          unreadCount: 0,
          warrantyStatus: '',
          isPinned: true,
        ),
        Cabinet(
          cabinetId: 2,
          type: 'ШУ 2',
          objectNumber: '02',
          customName: '2',
          unreadCount: 0,
          warrantyStatus: '',
          isPinned: false,
        ),
      ];

      // If at least one selected cabinet is unpinned, the action is to PIN all
      final hasUnpinned = cabinets.any((c) => !c.isPinned);
      expect(hasUnpinned, isTrue);

      final updated = cabinets.map((c) => c.copyWith(isPinned: hasUnpinned)).toList();
      expect(updated.every((c) => c.isPinned), isTrue);
    });
  });
}
