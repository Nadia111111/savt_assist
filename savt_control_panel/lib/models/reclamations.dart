// lib/models/reclamations.dart
import 'package:flutter/material.dart';

class ReclamationsItem {
  final int id;
  final String objectType;
  final String status;
  final bool? warrantyClassification;
  final String description;
  final String? cabinetObjectNumber;
  final String? projectName;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  ReclamationsItem({
    required this.id,
    required this.objectType,
    required this.status,
    this.warrantyClassification,
    required this.description,
    this.cabinetObjectNumber,
    this.projectName,
    required this.createdAt,
    this.resolvedAt,
  });

  factory ReclamationsItem.fromJson(Map<String, dynamic> json) {
    return ReclamationsItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      objectType: json['object_type'] ?? json['objectType'] ?? '',
      status: json['status'] ?? '',
      warrantyClassification: json['warranty_classification'] is bool
          ? json['warranty_classification']
          : (json['warranty_classification'] == null
              ? null
              : json['warranty_classification'].toString().toLowerCase() == 'true'),
      description: json['description'] ?? '',
      cabinetObjectNumber: json['cabinet_object_number'] ?? json['cabinetObjectNumber'],
      projectName: json['project_name'] ?? json['projectName'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'object_type': objectType,
      'status': status,
      'warranty_classification': warrantyClassification,
      'description': description,
      'cabinet_object_number': cabinetObjectNumber,
      'project_name': projectName,
      'created_at': createdAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  String get statusLabel {
    switch (status) {
      case 'new':
        return 'Новая';
      case 'review':
        return 'На рассмотрении';
      case 'in_progress':
        return 'В работе';
      case 'resolved':
        return 'Исполнена';
      case 'rejected':
        return 'Отклонена';
      case 'invalid':
        return 'Оформлена некорректно';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'new':
        return const Color(0xFF0284C7); // Индиго/небесный
      case 'review':
        return const Color(0xFFF59E0B); // Янтарный
      case 'in_progress':
        return const Color(0xFF0A7AC2); // Фирменный синий
      case 'resolved':
        return const Color(0xFF10B981); // Изумрудно-зеленый
      case 'rejected':
        return const Color(0xFFDC2626); // Красный
      case 'invalid':
        return const Color(0xFFEA580C); // Кораллово-оранжевый
      default:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'new':
        return Icons.fiber_new_outlined;
      case 'review':
        return Icons.hourglass_empty_rounded;
      case 'in_progress':
        return Icons.pending_actions_rounded;
      case 'resolved':
        return Icons.check_circle_outline_rounded;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'invalid':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline;
    }
  }

  String get objectTypeLabel {
    switch (objectType) {
      case 'cabinet':
        return 'ШУ';
      case 'line':
        return 'Автоматическая линия';
      case 'component':
        return 'ПКИ';
      case 'software':
        return 'ПО';
      case 'documentation':
        return 'Документация';
      default:
        return objectType;
    }
  }

  IconData get objectTypeIcon {
    switch (objectType) {
      case 'cabinet':
        return Icons.devices_other;
      case 'line':
        return Icons.precision_manufacturing;
      case 'component':
        return Icons.memory;
      case 'software':
        return Icons.code;
      case 'documentation':
        return Icons.description;
      default:
        return Icons.build_circle_outlined;
    }
  }

  String? get warrantyBadgeText {
    if (warrantyClassification == true) return 'Гарантия';
    if (warrantyClassification == false) return 'Платно';
    if (status == 'review') return 'Определяется';
    return null;
  }

  Color? get warrantyBadgeColor {
    if (warrantyClassification == true) return const Color(0xFF10B981);
    if (warrantyClassification == false) return const Color(0xFFEF4444);
    if (status == 'review') return const Color(0xFFF59E0B);
    return null;
  }
}

class ReclamationsDetail {
  final int id;
  final String status;
  final bool? warrantyClassification;
  final String objectType;
  final int? cabinetId;
  final String? cabinetObjectNumber;
  final int? projectId;
  final String? projectName;
  final Map<String, dynamic>? objectDetails;
  final String? contractNumber;
  final String? orderNumber;
  final String? ttnNumber;
  final String description;
  final String? occurrenceConditions;
  final String? errorCodes;
  final String contactName;
  final String contactPhone;
  final String contactEmail;
  final String? customerName;
  final String? rootCause;
  final String? resolutionComment;
  final String? rejectionReason;
  final String? responsibleName;
  final String? responsiblePhone;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final List<ReclamationsAttachment> attachments;

  ReclamationsDetail({
    required this.id,
    required this.status,
    this.warrantyClassification,
    required this.objectType,
    this.cabinetId,
    this.cabinetObjectNumber,
    this.projectId,
    this.projectName,
    this.objectDetails,
    this.contractNumber,
    this.orderNumber,
    this.ttnNumber,
    required this.description,
    this.occurrenceConditions,
    this.errorCodes,
    required this.contactName,
    required this.contactPhone,
    required this.contactEmail,
    this.customerName,
    this.rootCause,
    this.resolutionComment,
    this.rejectionReason,
    this.responsibleName,
    this.responsiblePhone,
    required this.createdAt,
    this.resolvedAt,
    required this.attachments,
  });

  factory ReclamationsDetail.fromJson(Map<String, dynamic> json) {
    final attachmentsRaw = json['attachments'] as List<dynamic>?;
    return ReclamationsDetail(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      status: json['status'] ?? '',
      warrantyClassification: json['warranty_classification'] is bool
          ? json['warranty_classification']
          : (json['warranty_classification'] == null
              ? null
              : json['warranty_classification'].toString().toLowerCase() == 'true'),
      objectType: json['object_type'] ?? json['objectType'] ?? '',
      cabinetId: json['cabinet_id'] != null
          ? (json['cabinet_id'] is int ? json['cabinet_id'] : int.tryParse(json['cabinet_id'].toString()))
          : null,
      cabinetObjectNumber: json['cabinet_object_number'] ?? json['cabinetObjectNumber'],
      projectId: json['project_id'] != null
          ? (json['project_id'] is int ? json['project_id'] : int.tryParse(json['project_id'].toString()))
          : null,
      projectName: json['project_name'] ?? json['projectName'],
      objectDetails: json['object_details'] is Map
          ? Map<String, dynamic>.from(json['object_details'])
          : null,
      contractNumber: json['contract_number'],
      orderNumber: json['order_number'],
      ttnNumber: json['ttn_number'],
      description: json['description'] ?? '',
      occurrenceConditions: json['occurrence_conditions'],
      errorCodes: json['error_codes'],
      contactName: json['contact_name'] ?? '',
      contactPhone: json['contact_phone'] ?? '',
      contactEmail: json['contact_email'] ?? '',
      customerName: json['customer_name'],
      rootCause: json['root_cause'],
      resolutionComment: json['resolution_comment'],
      rejectionReason: json['rejection_reason'],
      responsibleName: json['responsible_name'],
      responsiblePhone: json['responsible_phone'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
      attachments: attachmentsRaw
              ?.map((a) => ReclamationsAttachment.fromJson(
                  a is Map ? Map<String, dynamic>.from(a) : <String, dynamic>{}))
              .toList() ??
          [],
    );
  }

  String get statusLabel {
    switch (status) {
      case 'new':
        return 'Новая';
      case 'review':
        return 'На рассмотрении';
      case 'in_progress':
        return 'В работе';
      case 'resolved':
        return 'Исполнена';
      case 'rejected':
        return 'Отклонена';
      case 'invalid':
        return 'Оформлена некорректно';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'new':
        return const Color(0xFF0284C7);
      case 'review':
        return const Color(0xFFF59E0B);
      case 'in_progress':
        return const Color(0xFF0A7AC2);
      case 'resolved':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFDC2626);
      case 'invalid':
        return const Color(0xFFEA580C);
      default:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'new':
        return Icons.fiber_new_outlined;
      case 'review':
        return Icons.hourglass_empty_rounded;
      case 'in_progress':
        return Icons.pending_actions_rounded;
      case 'resolved':
        return Icons.check_circle_outline_rounded;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'invalid':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline;
    }
  }

  String get objectTypeLabel {
    switch (objectType) {
      case 'cabinet':
        return 'ШУ';
      case 'line':
        return 'Автоматическая линия';
      case 'component':
        return 'ПКИ';
      case 'software':
        return 'ПО';
      case 'documentation':
        return 'Документация';
      default:
        return objectType;
    }
  }

  IconData get objectTypeIcon {
    switch (objectType) {
      case 'cabinet':
        return Icons.devices_other;
      case 'line':
        return Icons.precision_manufacturing;
      case 'component':
        return Icons.memory;
      case 'software':
        return Icons.code;
      case 'documentation':
        return Icons.description;
      default:
        return Icons.build_circle_outlined;
    }
  }

  String? get warrantyBadgeText {
    if (warrantyClassification == true) return 'Гарантийный случай';
    if (warrantyClassification == false) return 'Негарантийный случай (платно)';
    if (status == 'review') return 'Классификация: на рассмотрении';
    return null;
  }

  Color? get warrantyBadgeColor {
    if (warrantyClassification == true) return const Color(0xFF10B981);
    if (warrantyClassification == false) return const Color(0xFFEF4444);
    if (status == 'review') return const Color(0xFFF59E0B);
    return null;
  }
}

class ReclamationsAttachment {
  final int id;
  final String fileUrl;
  final String fileName;
  final int fileSizeBytes;
  final String mimeType;
  final DateTime createdAt;

  ReclamationsAttachment({
    required this.id,
    required this.fileUrl,
    required this.fileName,
    required this.fileSizeBytes,
    required this.mimeType,
    required this.createdAt,
  });

  factory ReclamationsAttachment.fromJson(Map<String, dynamic> json) {
    return ReclamationsAttachment(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      fileUrl: json['file_url'] ?? json['fileUrl'] ?? '',
      fileName: json['file_name'] ?? json['fileName'] ?? '',
      fileSizeBytes: json['file_size_bytes'] is int
          ? json['file_size_bytes']
          : int.tryParse(json['file_size_bytes']?.toString() ?? '0') ?? 0,
      mimeType: json['mime_type'] ?? json['mimeType'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'file_url': fileUrl,
      'file_name': fileName,
      'file_size_bytes': fileSizeBytes,
      'mime_type': mimeType,
    };
  }

  bool get isImage {
    final lowerMime = mimeType.toLowerCase();
    final lowerName = fileName.toLowerCase();
    return lowerMime.startsWith('image/') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.gif');
  }

  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) return '$fileSizeBytes Б';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} КБ';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }
}