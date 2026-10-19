class TrapMonitoring {
  final String id;
  final String location;
  final String trapType;
  final int consumptionPercentage; // 0, 10, 20, ..., 100%
  final String status;
  final int captureCount;
  final String observations;

  TrapMonitoring({
    required this.id,
    required this.location,
    required this.trapType,
    this.consumptionPercentage = 0,
    required this.status,
    this.captureCount = 0,
    this.observations = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'location': location,
      'trapType': trapType,
      'consumptionPercentage': consumptionPercentage,
      'status': status,
      'captureCount': captureCount,
      'observations': observations,
    };
  }

  factory TrapMonitoring.fromMap(Map<String, dynamic> map) {
    return TrapMonitoring(
      id: map['id'] ?? '',
      location: map['location'] ?? '',
      trapType: map['trapType'] ?? 'Estación de cebado',
      consumptionPercentage: map['consumptionPercentage']?.toInt() ?? 0,
      status: map['status'] ?? 'Sin actividad',
      captureCount: map['captureCount']?.toInt() ?? 0,
      observations: map['observations'] ?? '',
    );
  }
}