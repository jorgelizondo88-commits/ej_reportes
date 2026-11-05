import 'dart:convert';

class TrapPinModel {
  final String id;
  String code; // ej. C-01, TM-01, TG-01, LU-01
  String type; // 'Cebadero Exterior', 'Trampa Mecánica Interior', 'Trampa de Goma', 'Lámpara Luz UV', 'Punto de Monitoreo'
  double x; // Coordenada relativa horizontal (0.0 a 1.0)
  double y; // Coordenada relativa vertical (0.0 a 1.0)
  String area; // ej. "Andén de carga 2", "Comedor bajo tarja"
  String zone; // 'Exterior', 'Interior', 'Perímetro'
  String notes;

  TrapPinModel({
    required this.id,
    required this.code,
    required this.type,
    required this.x,
    required this.y,
    this.area = '',
    this.zone = 'Exterior',
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'type': type,
      'x': x,
      'y': y,
      'area': area,
      'zone': zone,
      'notes': notes,
    };
  }

  factory TrapPinModel.fromMap(Map<String, dynamic> map) {
    return TrapPinModel(
      id: map['id'] ?? '',
      code: map['code'] ?? '',
      type: map['type'] ?? 'Cebadero Exterior',
      x: (map['x'] as num?)?.toDouble() ?? 0.5,
      y: (map['y'] as num?)?.toDouble() ?? 0.5,
      area: map['area'] ?? '',
      zone: map['zone'] ?? 'Exterior',
      notes: map['notes'] ?? '',
    );
  }

  TrapPinModel copyWith({
    String? id,
    String? code,
    String? type,
    double? x,
    double? y,
    String? area,
    String? zone,
    String? notes,
  }) {
    return TrapPinModel(
      id: id ?? this.id,
      code: code ?? this.code,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      area: area ?? this.area,
      zone: zone ?? this.zone,
      notes: notes ?? this.notes,
    );
  }
}

class TrapWallPoint {
  final double x; // Relativo 0.0 - 1.0
  final double y; // Relativo 0.0 - 1.0

  TrapWallPoint({required this.x, required this.y});

  Map<String, dynamic> toMap() => {'x': x, 'y': y};

  factory TrapWallPoint.fromMap(Map<String, dynamic> map) => TrapWallPoint(
    x: (map['x'] as num?)?.toDouble() ?? 0.0,
    y: (map['y'] as num?)?.toDouble() ?? 0.0,
  );
}

class TrapWallPath {
  final String id;
  List<TrapWallPoint> points;
  bool isClosed;
  String label; // ej. "Nave Principal", "Oficinas", "Almacén"

  TrapWallPath({
    required this.id,
    required this.points,
    this.isClosed = true,
    this.label = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'points': points.map((p) => p.toMap()).toList(),
    'isClosed': isClosed,
    'label': label,
  };

  factory TrapWallPath.fromMap(Map<String, dynamic> map) => TrapWallPath(
    id: map['id'] ?? '',
    points: (map['points'] as List<dynamic>?)
        ?.map((p) => TrapWallPoint.fromMap(p as Map<String, dynamic>))
        .toList() ?? [],
    isClosed: map['isClosed'] ?? true,
    label: map['label'] ?? '',
  );

  TrapWallPath copy() {
    return TrapWallPath(
      id: id,
      points: points.map((p) => TrapWallPoint(x: p.x, y: p.y)).toList(),
      isClosed: isClosed,
      label: label,
    );
  }
}

class TrapLayoutModel {
  final String id;
  final String folio; // ej. #EJ-LAY-001
  final DateTime createdAt;
  DateTime updatedAt;
  String clientBusinessName;
  String clientContactName;
  String clientPhone;
  String clientAddress;
  String facilityName; // ej. "Planta Industrial Apodaca", "Almacén Central"
  String backgroundType; // 'camera', 'gallery', 'grid'
  String? backgroundImagePath; // Ruta local del archivo de imagen
  String gridTitle; // Si es cuadrícula: "Croquis Esquemático de Planta"
  List<TrapPinModel> pins;
  List<TrapWallPath> walls; // Muros y perímetros trazados por el usuario
  String technicalNotes;
  String technicianName;

  TrapLayoutModel({
    required this.id,
    required this.folio,
    required this.createdAt,
    required this.updatedAt,
    required this.clientBusinessName,
    this.clientContactName = '',
    this.clientPhone = '',
    this.clientAddress = '',
    this.facilityName = 'Instalación Principal',
    this.backgroundType = 'grid',
    this.backgroundImagePath,
    this.gridTitle = 'Plano de Distribución de Estaciones',
    List<TrapPinModel>? pins,
    List<TrapWallPath>? walls,
    this.technicalNotes = 'Dispositivos de monitoreo y control instalados bajo criterios de la NOM-256-SSA1-2012 y estándares de bioseguridad industrial.',
    this.technicianName = 'Ing. Jorge Elizondo / Rep. Técnico',
  })  : pins = pins ?? [],
        walls = walls ?? [];

  int get totalPins => pins.length;
  int get totalExteriorBaitStations => pins.where((p) => p.type.contains('Cebadero')).length;
  int get totalMechanicalTraps => pins.where((p) => p.type.contains('Mecánica') || p.type.contains('Golpe')).length;
  int get totalGlueTraps => pins.where((p) => p.type.contains('Goma') || p.type.contains('Adhesiva')).length;
  int get totalUvLamps => pins.where((p) => p.type.contains('Luz UV') || p.type.contains('Lámpara')).length;
  int get totalMonitoringPoints => pins.where((p) => p.type.contains('Monitoreo')).length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folio': folio,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'clientBusinessName': clientBusinessName,
      'clientContactName': clientContactName,
      'clientPhone': clientPhone,
      'clientAddress': clientAddress,
      'facilityName': facilityName,
      'backgroundType': backgroundType,
      'backgroundImagePath': backgroundImagePath,
      'gridTitle': gridTitle,
      'pins': pins.map((p) => p.toMap()).toList(),
      'walls': walls.map((w) => w.toMap()).toList(),
      'technicalNotes': technicalNotes,
      'technicianName': technicianName,
    };
  }

  factory TrapLayoutModel.fromMap(Map<String, dynamic> map) {
    return TrapLayoutModel(
      id: map['id'] ?? '',
      folio: map['folio'] ?? '#EJ-LAY-001',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      clientBusinessName: map['clientBusinessName'] ?? '',
      clientContactName: map['clientContactName'] ?? '',
      clientPhone: map['clientPhone'] ?? '',
      clientAddress: map['clientAddress'] ?? '',
      facilityName: map['facilityName'] ?? 'Instalación Principal',
      backgroundType: map['backgroundType'] ?? 'grid',
      backgroundImagePath: map['backgroundImagePath'],
      gridTitle: map['gridTitle'] ?? 'Plano de Distribución de Estaciones',
      pins: (map['pins'] as List<dynamic>?)
              ?.map((p) => TrapPinModel.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      walls: (map['walls'] as List<dynamic>?)
              ?.map((w) => TrapWallPath.fromMap(w as Map<String, dynamic>))
              .toList() ??
          [],
      technicalNotes: map['technicalNotes'] ?? '',
      technicianName: map['technicianName'] ?? 'Ing. Jorge Elizondo / Rep. Técnico',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory TrapLayoutModel.fromJson(String source) =>
      TrapLayoutModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
