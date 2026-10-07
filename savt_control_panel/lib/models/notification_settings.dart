class NotificationSettings {
  final bool chatMessages;
  final bool promotional;
  final bool warrantyExpiring;
  final bool requestStatusChange;
  final bool cabinetAlarms;
  final bool isMuted;
  final DateTime? mutedUntil;
  final bool mutedIndefinitely;

  NotificationSettings({
    required this.chatMessages,
    required this.promotional,
    required this.warrantyExpiring,
    required this.requestStatusChange,
    required this.cabinetAlarms,
    required this.isMuted,
    this.mutedUntil,
    required this.mutedIndefinitely,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      chatMessages: json['chat_messages'] ?? true,
      promotional: json['promotional'] ?? true,
      warrantyExpiring: json['warranty_expiring'] ?? true,
      requestStatusChange: json['request_status_change'] ?? true,
      cabinetAlarms: json['cabinet_alarms'] ?? true,
      isMuted: json['is_muted'] ?? false,
      mutedUntil: json['muted_until'] != null
          ? DateTime.parse(json['muted_until'])
          : null,
      mutedIndefinitely: json['muted_indefinitely'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chat_messages': chatMessages,
      'promotional': promotional,
      'warranty_expiring': warrantyExpiring,
      'request_status_change': requestStatusChange,
      'cabinet_alarms': cabinetAlarms,
      'is_muted': isMuted,
      'muted_until': mutedUntil?.toIso8601String(),
      'muted_indefinitely': mutedIndefinitely,
    };
  }

  NotificationSettings copyWith({
    bool? chatMessages,
    bool? promotional,
    bool? warrantyExpiring,
    bool? requestStatusChange,
    bool? cabinetAlarms,
    bool? isMuted,
    DateTime? mutedUntil,
    bool? mutedIndefinitely,
  }) {
    return NotificationSettings(
      chatMessages: chatMessages ?? this.chatMessages,
      promotional: promotional ?? this.promotional,
      warrantyExpiring: warrantyExpiring ?? this.warrantyExpiring,
      requestStatusChange: requestStatusChange ?? this.requestStatusChange,
      cabinetAlarms: cabinetAlarms ?? this.cabinetAlarms,
      isMuted: isMuted ?? this.isMuted,
      mutedUntil: mutedUntil ?? this.mutedUntil,
      mutedIndefinitely: mutedIndefinitely ?? this.mutedIndefinitely,
    );
  }

  String getMuteStatusText() {
    if (!isMuted) return 'Уведомления включены';
    if (mutedIndefinitely) return 'Приостановлены навсегда';
    if (mutedUntil != null) {
      final now = DateTime.now();
      if (mutedUntil!.isAfter(now)) {
        final diff = mutedUntil!.difference(now);
        if (diff.inHours > 0) {
          return 'Приостановлены до ${_formatTime(mutedUntil!)} (${diff.inHours} ч.)';
        } else if (diff.inMinutes > 0) {
          return 'Приостановлены до ${_formatTime(mutedUntil!)} (${diff.inMinutes} мин.)';
        }
      }
      return 'Пауза скоро закончится';
    }
    return 'Уведомления включены';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}