import 'dart:convert';

class NotificationItem {
  final int id;
  final String title;
  final String body;
  final String? type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.type,
    this.data,
    required this.isRead,
    this.createdAt,
  });

  int? get reclamationId =>
      int.tryParse((data?['reclamation_id'] ?? data?['reclamationId'])?.toString() ?? '');
  int? get requestId =>
      int.tryParse((data?['request_id'] ?? data?['requestId'])?.toString() ?? '');
  int? get cabinetId =>
      int.tryParse((data?['cabinet_id'] ?? data?['shu_id'] ?? data?['cabinetId'])?.toString() ?? '');
  int? get chatId =>
      int.tryParse((data?['chat_id'] ?? data?['chatId'])?.toString() ?? '');

  NotificationItem copyWith({
    int? id,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedData;
    if (json['data'] is Map) {
      parsedData = Map<String, dynamic>.from(json['data']);
    } else if (json['data'] is String && (json['data'] as String).isNotEmpty) {
      try {
        parsedData = Map<String, dynamic>.from(jsonDecode(json['data']));
      } catch (_) {}
    } else if (json['payload'] is Map) {
      parsedData = Map<String, dynamic>.from(json['payload']);
    } else if (json['payload'] is String &&
        (json['payload'] as String).isNotEmpty) {
      try {
        parsedData = Map<String, dynamic>.from(jsonDecode(json['payload']));
      } catch (_) {}
    }

    parsedData ??= {};
    for (final key in [
      'reclamation_id',
      'reclamationId',
      'request_id',
      'requestId',
      'cabinet_id',
      'shu_id',
      'cabinetId',
      'chat_id',
      'chatId',
      'type'
    ]) {
      if (json[key] != null && !parsedData.containsKey(key)) {
        parsedData[key] = json[key];
      }
    }

    return NotificationItem(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? parsedData['type']?.toString(),
      data: parsedData.isNotEmpty ? parsedData : null,
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'is_read': isRead,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
