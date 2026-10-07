// lib/models/service_request.dart
class ServiceRequest {
  final int id;
  final int? cabinetId;
  final int? projectId;
  final String cabinetObjectNumber;
  final String requestType; // "repair", "maintenance", "inspection", "other"
  final String description;
  final String status; // 'open', 'in_progress', 'closed'
  final DateTime createdAt;

  ServiceRequest({
    required this.id,
    this.cabinetId,
    this.projectId,
    required this.cabinetObjectNumber,
    required this.requestType,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      cabinetId: json['cabinet_id'] != null
          ? (json['cabinet_id'] is int ? json['cabinet_id'] : int.tryParse(json['cabinet_id'].toString()) ?? 0)
          : null,
      projectId: json['project_id'] != null
          ? (json['project_id'] is int ? json['project_id'] : int.tryParse(json['project_id'].toString()) ?? 0)
          : null,
      cabinetObjectNumber: json['cabinet_object_number']?.toString() ?? '',
      requestType: json['request_type'] ?? 'other',
      description: json['description'] ?? '',
      status: json['status'] ?? 'open',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (cabinetId != null) 'cabinet_id': cabinetId,
      if (projectId != null) 'project_id': projectId,
      'cabinet_object_number': cabinetObjectNumber,
      'request_type': requestType,
      'description': description,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
