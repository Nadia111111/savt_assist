// lib/models/project.dart
class Project {
  final int projectId;
  final String name;
  final int cabinetCount;
  final bool isPinned;
  final bool isPrimary;

  String get displayName => name;

  Project({
    required this.projectId,
    required this.name,
    required this.cabinetCount,
    this.isPinned = false,
    this.isPrimary = false,
  });

  Project copyWith({
    bool? isPinned,
    bool? isPrimary,
  }) {
    return Project(
      projectId: projectId,
      name: name,
      cabinetCount: cabinetCount,
      isPinned: isPinned ?? this.isPinned,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    final id = json['project_id'] ?? json['id'];
    final rawCount = json['cabinet_count'] ?? json['cabinetCount'];
    final parsedCount = rawCount is int
        ? rawCount
        : int.tryParse(rawCount?.toString() ?? '') ?? 0;
    return Project(
      projectId: id is int ? id : int.tryParse(id.toString()) ?? 0,
      name: json['name']?.toString() ?? 'Без названия',
      cabinetCount: parsedCount,
      isPinned: json['is_pinned'] == true,
      isPrimary: json['is_primary'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'name': name,
      'cabinet_count': cabinetCount,
      'is_pinned': isPinned,
      'is_primary': isPrimary,
    };
  }
}

class ProjectDetails {
  final int projectId;
  final String name;
  final List<ProjectCabinetInfo> cabinets;

  ProjectDetails({
    required this.projectId,
    required this.name,
    required this.cabinets,
  });

  factory ProjectDetails.fromJson(Map<String, dynamic> json) {
    final id = json['project_id'] ?? json['id'];
    final cabsList = json['cabinets'] as List<dynamic>? ?? [];
    return ProjectDetails(
      projectId: id is int ? id : int.tryParse(id.toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      cabinets: cabsList.map((c) => ProjectCabinetInfo.fromJson(c)).toList(),
    );
  }
}

class ProjectCabinetInfo {
  final int id;
  final String type;
  final String objectNumber;
  final String? adminInternalName;
  final bool isPinned;

  ProjectCabinetInfo({
    required this.id,
    required this.type,
    required this.objectNumber,
    this.adminInternalName,
    this.isPinned = false,
  });

  factory ProjectCabinetInfo.fromJson(Map<String, dynamic> json) {
    final cabId = json['id'] ?? json['cabinet_id'];
    return ProjectCabinetInfo(
      id: cabId is int ? cabId : int.tryParse(cabId.toString()) ?? 0,
      type: json['type'] ?? json['cabinet_type'] ?? 'Неизвестно',
      objectNumber: json['object_number'] ?? json['objectNumber'] ?? '',
      adminInternalName: json['admin_internal_name'] ?? json['adminInternalName'],
      isPinned: json['is_pinned'] == true || json['isPinned'] == true,
    );
  }
}
