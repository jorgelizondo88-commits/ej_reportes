import 'dart:convert';

class ScheduledVisit {
  final String id;
  final int visitNumber;
  DateTime date;
  String time;
  String serviceType;
  String status; // 'Pendiente', 'Realizada', 'Reagendada', 'Cancelada'
  String notes;
  DateTime? completedDate;

  ScheduledVisit({
    required this.id,
    required this.visitNumber,
    required this.date,
    this.time = '09:00 AM',
    this.serviceType = 'Control y Mantenimiento Mensual',
    this.status = 'Pendiente',
    this.notes = '',
    this.completedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'visitNumber': visitNumber,
      'date': date.toIso8601String(),
      'time': time,
      'serviceType': serviceType,
      'status': status,
      'notes': notes,
      'completedDate': completedDate?.toIso8601String(),
    };
  }

  factory ScheduledVisit.fromMap(Map<String, dynamic> map) {
    return ScheduledVisit(
      id: map['id'] ?? '',
      visitNumber: map['visitNumber'] ?? 1,
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      time: map['time'] ?? '09:00 AM',
      serviceType: map['serviceType'] ?? 'Control y Mantenimiento Mensual',
      status: map['status'] ?? 'Pendiente',
      notes: map['notes'] ?? '',
      completedDate: map['completedDate'] != null ? DateTime.tryParse(map['completedDate']) : null,
    );
  }
}

class ScheduleModel {
  final String id;
  final String folio;
  final DateTime createdAt;
  final String title;
  final String clientBusinessName;
  final String clientContactName;
  final String clientPhone;
  final String clientAddress;
  final String clientEmail;
  final String facilityType;

  // Parámetros de Recurrencia
  final String recurrenceType; // 'relative', 'fixed_day', 'custom'
  final int ordinalWeek; // 1 = 1er, 2 = 2do, 3 = 3er, 4 = 4to, 5 = Último
  final int weekday; // 1 = Lunes, ..., 7 = Domingo
  final int fixedDay; // 1..31
  final int durationMonths; // ej. 3, 5, 6, 12 meses
  final DateTime startDate;
  final String defaultTime;
  final String serviceType;
  final String conditions;
  final String notes;
  final String elaboratedBy;

  final List<ScheduledVisit> visits;

  ScheduleModel({
    required this.id,
    required this.folio,
    required this.createdAt,
    this.title = 'Programa Periódico de Control de Plagas',
    required this.clientBusinessName,
    required this.clientContactName,
    required this.clientPhone,
    required this.clientAddress,
    required this.clientEmail,
    this.facilityType = 'Comercial / Restaurante',
    this.recurrenceType = 'relative',
    this.ordinalWeek = 1,
    this.weekday = 7, // Domingo por defecto según ejemplo del usuario
    this.fixedDay = 1,
    this.durationMonths = 12,
    required this.startDate,
    this.defaultTime = '09:00 AM',
    this.serviceType = 'Control y Mantenimiento Periódico',
    String? conditions,
    this.notes = '',
    this.elaboratedBy = 'EJ Exterminadores',
    required this.visits,
  }) : conditions = conditions ?? defaultConditions();

  static String defaultConditions() {
    return '1. Las fechas aquí programadas han sido acordadas de común acuerdo con el cliente.\n'
        '2. En caso de requerir reprogramación de una visita, favor de avisar con un mínimo de 24 horas de anticipación.';
  }

  int get totalVisits => visits.length;
  int get completedVisits => visits.where((v) => v.status == 'Realizada').length;
  int get pendingVisits => visits.where((v) => v.status == 'Pendiente').length;

  bool get isCompleted => totalVisits > 0 && completedVisits == totalVisits;

  /// Descripción legible de la regla de periodicidad
  String get recurrenceDescription {
    if (recurrenceType == 'relative') {
      final ordinals = {1: 'Primer', 2: 'Segundo', 3: 'Tercer', 4: 'Cuarto', 5: 'Último'};
      final days = {
        1: 'Lunes',
        2: 'Martes',
        3: 'Miércoles',
        4: 'Jueves',
        5: 'Viernes',
        6: 'Sábado',
        7: 'Domingo',
      };
      final ordStr = ordinals[ordinalWeek] ?? 'Primer';
      final dayStr = days[weekday] ?? 'Domingo';
      return '$ordStr $dayStr de cada mes ($durationMonths meses)';
    } else if (recurrenceType == 'fixed_day') {
      return 'Día $fixedDay de cada mes ($durationMonths meses)';
    } else {
      return 'Fechas personalizadas ($totalVisits visitas)';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folio': folio,
      'createdAt': createdAt.toIso8601String(),
      'title': title,
      'clientBusinessName': clientBusinessName,
      'clientContactName': clientContactName,
      'clientPhone': clientPhone,
      'clientAddress': clientAddress,
      'clientEmail': clientEmail,
      'facilityType': facilityType,
      'recurrenceType': recurrenceType,
      'ordinalWeek': ordinalWeek,
      'weekday': weekday,
      'fixedDay': fixedDay,
      'durationMonths': durationMonths,
      'startDate': startDate.toIso8601String(),
      'defaultTime': defaultTime,
      'serviceType': serviceType,
      'conditions': conditions,
      'notes': notes,
      'elaboratedBy': elaboratedBy,
      'visits': visits.map((v) => v.toMap()).toList(),
    };
  }

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      id: map['id'] ?? '',
      folio: map['folio'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      title: map['title'] ?? 'Programa Periódico de Control de Plagas',
      clientBusinessName: map['clientBusinessName'] ?? '',
      clientContactName: map['clientContactName'] ?? '',
      clientPhone: map['clientPhone'] ?? '',
      clientAddress: map['clientAddress'] ?? '',
      clientEmail: map['clientEmail'] ?? '',
      facilityType: map['facilityType'] ?? 'Comercial / Restaurante',
      recurrenceType: map['recurrenceType'] ?? 'relative',
      ordinalWeek: map['ordinalWeek'] ?? 1,
      weekday: map['weekday'] ?? 7,
      fixedDay: map['fixedDay'] ?? 1,
      durationMonths: map['durationMonths'] ?? 12,
      startDate: DateTime.tryParse(map['startDate'] ?? '') ?? DateTime.now(),
      defaultTime: map['defaultTime'] ?? '09:00 AM',
      serviceType: map['serviceType'] ?? 'Control y Mantenimiento Periódico',
      conditions: map['conditions'] ?? defaultConditions(),
      notes: map['notes'] ?? '',
      elaboratedBy: map['elaboratedBy'] ?? 'EJ Exterminadores',
      visits: (map['visits'] as List<dynamic>? ?? [])
          .map((v) => ScheduledVisit.fromMap(v as Map<String, dynamic>))
          .toList(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory ScheduleModel.fromJson(String source) => ScheduleModel.fromMap(jsonDecode(source));
}
