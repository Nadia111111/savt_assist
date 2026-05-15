// lib/models/shu_model.dart
class ShuModel {
  final String id;
  final String type;
  final String objectNumber;
  String customName;
  String comment;
  final String? stationType; // <-- добавить
  final String? purpose; // <-- добавить
  final String warrantyStatus;
  final int warrantyDaysRemaining;
  final String? warrantyStart;
  final String? warrantyEnd;
  final String moderationStatus;
  int unreadMessages;
  final DateTime addedDate;

  ShuModel({
    required this.id,
    required this.type,
    required this.objectNumber,
    this.customName = '',
    this.comment = '',
    this.stationType,
    this.purpose,
    required this.warrantyStatus,
    required this.warrantyDaysRemaining,
    this.warrantyStart,
    this.warrantyEnd,
    required this.moderationStatus,
    this.unreadMessages = 0,
    required this.addedDate,
  });
}
