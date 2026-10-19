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
    );
  }
}