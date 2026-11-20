class ClientTrapTemplate {
  final String id;
  final String trapType;
  final String location;

  ClientTrapTemplate({
    required this.id,
    required this.trapType,
    required this.location,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trapType': trapType,
      'location': location,
    };
  }

  factory ClientTrapTemplate.fromMap(Map<String, dynamic> map) {
    return ClientTrapTemplate(
      id: map['id'] ?? '',
      trapType: map['trapType'] ?? 'Estación de cebado (Roedor)',
      location: map['location'] ?? 'Área General',
    );
  }
}

class ClientModel {
  final String id;
  final String businessName;
  final String contactName;
  final String address;
  final String phone;
  final String email;
  final String facilityType;
  final bool hasTraps;
  final List<ClientTrapTemplate> defaultTraps; // Inventario fijo de trampas
  final String? driveFolderId;
  final String? driveFolderShareUrl; // Enlace público de solo lectura para el cliente
  final DateTime? updatedAt;

  // Datos Fiscales para Facturación CFDI 4.0 (Opcional por cliente)
  final String taxRfc; // RFC oficial (e.g. "CEM140703EM8")
  final String taxBusinessName; // Razón Social exacta ante el SAT
  final String taxAddress; // Domicilio fiscal completo (calle, núm, colonia)
  final String taxZipCode; // Código Postal fiscal (5 dígitos)
  final String taxRegime; // Régimen fiscal (e.g. "601 - General de Ley Personas Morales")
  final String taxCfdiUse; // Uso de CFDI predeterminado (e.g. "G03 - Gastos en general")

  ClientModel({
    required this.id,
    required this.businessName,
    required this.contactName,
    required this.address,
    required this.phone,
    required this.email,
    required this.facilityType,
    required this.hasTraps,
    this.defaultTraps = const [],
    this.driveFolderId,
    this.driveFolderShareUrl,
    this.updatedAt,
    this.taxRfc = '',
    this.taxBusinessName = '',
    this.taxAddress = '',
    this.taxZipCode = '',
    this.taxRegime = '',
    this.taxCfdiUse = '',
  });

  bool get hasFiscalData => taxRfc.trim().isNotEmpty && taxBusinessName.trim().isNotEmpty;
  String get fiscalOrBusinessName => taxBusinessName.trim().isNotEmpty ? taxBusinessName.trim() : businessName.trim();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessName': businessName,
      'contactName': contactName,
      'address': address,
      'phone': phone,
      'email': email,
      'facilityType': facilityType,
      'hasTraps': hasTraps,
      'defaultTraps': defaultTraps.map((t) => t.toMap()).toList(),
      'driveFolderId': driveFolderId,
      'driveFolderShareUrl': driveFolderShareUrl,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      'taxRfc': taxRfc,
      'taxBusinessName': taxBusinessName,
      'taxAddress': taxAddress,
      'taxZipCode': taxZipCode,
      'taxRegime': taxRegime,
      'taxCfdiUse': taxCfdiUse,
    };
  }

  factory ClientModel.fromMap(Map<String, dynamic> map) {
    return ClientModel(
      id: map['id'] ?? '',
      businessName: map['businessName'] ?? '',
      contactName: map['contactName'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      facilityType: map['facilityType'] ?? 'Comercial / Restaurante',
      hasTraps: map['hasTraps'] ?? false,
      defaultTraps: map['defaultTraps'] != null
          ? (map['defaultTraps'] as List)
              .map((item) => ClientTrapTemplate.fromMap(item))
              .toList()
          : [],
      driveFolderId: map['driveFolderId'],
      driveFolderShareUrl: map['driveFolderShareUrl'],
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'].toString()) : null,
      taxRfc: map['taxRfc'] ?? '',
      taxBusinessName: map['taxBusinessName'] ?? '',
      taxAddress: map['taxAddress'] ?? '',
      taxZipCode: map['taxZipCode'] ?? '',
      taxRegime: map['taxRegime'] ?? '',
      taxCfdiUse: map['taxCfdiUse'] ?? '',
    );
  }

  ClientModel copyWith({
    String? id,
    String? businessName,
    String? contactName,
    String? address,
    String? phone,
    String? email,
    String? facilityType,
    bool? hasTraps,
    List<ClientTrapTemplate>? defaultTraps,
    String? driveFolderId,
    String? driveFolderShareUrl,
    DateTime? updatedAt,
    String? taxRfc,
    String? taxBusinessName,
    String? taxAddress,
    String? taxZipCode,
    String? taxRegime,
    String? taxCfdiUse,
  }) {
    return ClientModel(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      contactName: contactName ?? this.contactName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      facilityType: facilityType ?? this.facilityType,
      hasTraps: hasTraps ?? this.hasTraps,
      defaultTraps: defaultTraps ?? this.defaultTraps,
      driveFolderId: driveFolderId ?? this.driveFolderId,
      driveFolderShareUrl: driveFolderShareUrl ?? this.driveFolderShareUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      taxRfc: taxRfc ?? this.taxRfc,
      taxBusinessName: taxBusinessName ?? this.taxBusinessName,
      taxAddress: taxAddress ?? this.taxAddress,
      taxZipCode: taxZipCode ?? this.taxZipCode,
      taxRegime: taxRegime ?? this.taxRegime,
      taxCfdiUse: taxCfdiUse ?? this.taxCfdiUse,
    );
  }
}