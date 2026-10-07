// lib/models/telemetry.dart

class TelemetryAlarm {
  final int address;
  final int bit;
  final String name;
  final int value;
  final DateTime updatedAt;

  TelemetryAlarm({
    required this.address,
    required this.bit,
    required this.name,
    required this.value,
    required this.updatedAt,
  });

  factory TelemetryAlarm.fromJson(Map<String, dynamic> json) {
    return TelemetryAlarm(
      address: json['address'] is int
          ? json['address']
          : int.tryParse(json['address']?.toString() ?? '') ?? 0,
      bit: json['bit'] is int
          ? json['bit']
          : int.tryParse(json['bit']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      value: json['value'] is int
          ? json['value']
          : int.tryParse(json['value']?.toString() ?? '') ?? 0,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class TelemetryStateResponse {
  final List<TelemetryAlarm> registers;

  TelemetryStateResponse({
    required this.registers,
  });

  factory TelemetryStateResponse.fromJson(Map<String, dynamic> json) {
    return TelemetryStateResponse(
      registers: (json['registers'] as List<dynamic>? ?? [])
          .map((r) => TelemetryAlarm.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}
