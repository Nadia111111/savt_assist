// lib/models/cabinet.dart
class Cabinet {
  final int cabinetId;
  final String type;
  final String objectNumber;
  final String customName;
  final int unreadCount;
  final String warrantyStatus;
  final String? warrantyEndsAt;
  final int? projectId;
  final String? projectName;
  final bool isPinned;

  Cabinet({
    required this.cabinetId,
    required this.type,
    required this.objectNumber,
    required this.customName,
    required this.unreadCount,
    required this.warrantyStatus,
    this.warrantyEndsAt,
    this.projectId,
    this.projectName,
    this.isPinned = false,
  });

  Cabinet copyWith({
    int? cabinetId,
    String? type,
    String? objectNumber,
    String? customName,
    int? unreadCount,
    String? warrantyStatus,
    String? warrantyEndsAt,
    int? projectId,
    String? projectName,
    bool? isPinned,
  }) {
    return Cabinet(
      cabinetId: cabinetId ?? this.cabinetId,
      type: type ?? this.type,
      objectNumber: objectNumber ?? this.objectNumber,
      customName: customName ?? this.customName,
      unreadCount: unreadCount ?? this.unreadCount,
      warrantyStatus: warrantyStatus ?? this.warrantyStatus,
      warrantyEndsAt: warrantyEndsAt ?? this.warrantyEndsAt,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  factory Cabinet.fromJson(Map<String, dynamic> json) {
    // Поддержка разных форматов полей
    final id = json['cabinet_id'] ?? json['id'];
    if (id == null) {
      print('ОШИБКА: нет id в json: $json');
    }

    final isPinned = json['is_pinned'] == true || json['isPinned'] == true;

    return Cabinet(
      cabinetId: id is int ? id : int.tryParse(id.toString()) ?? 0,
      type: json['type'] ?? json['cabinet_type'] ?? 'Неизвестно',
      objectNumber: json['object_number'] ?? json['objectNumber'] ?? '',
      customName: json['custom_name'] ?? json['customName'] ?? '',
      unreadCount: json['unread_count'] ?? json['unreadCount'] ?? 0,
      warrantyStatus:
          json['warranty_status'] ?? json['warrantyStatus'] ?? 'unknown',
      warrantyEndsAt: json['warranty_ends_at'] ?? json['warrantyEndsAt'],
      projectId: json['project_id'] is int
          ? json['project_id']
          : int.tryParse(json['project_id']?.toString() ?? ''),
      projectName: json['project_name']?.toString(),
      isPinned: isPinned,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cabinet_id': cabinetId,
      'type': type,
      'object_number': objectNumber,
      'custom_name': customName,
      'unread_count': unreadCount,
      'warranty_status': warrantyStatus,
      'warranty_ends_at': warrantyEndsAt,
      'project_id': projectId,
      'project_name': projectName,
      'is_pinned': isPinned,
    };
  }
}
