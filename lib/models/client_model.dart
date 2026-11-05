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
  });

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
    );
  }
}