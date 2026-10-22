class QuoteItem {
  final String id;
  final String concept;
  final String description;
  final double quantity;
  final String unit;
  final double unitPrice;

  QuoteItem({
    required this.id,
    required this.concept,
    this.description = '',
    this.quantity = 1,
    this.unit = 'Servicio',
    required this.unitPrice,
  });

  double get totalPrice => quantity * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'concept': concept,
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
    };
  }

  factory QuoteItem.fromMap(Map<String, dynamic> map) {
    return QuoteItem(
      id: map['id'] ?? '',
      concept: map['concept'] ?? '',
      description: map['description'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] ?? 'Servicio',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class QuoteModel {
  final String id;
  final String quoteFolio;
  final DateTime quoteDate;
  final int validDays;
  final String clientBusinessName;
  final String clientContactName;
  final String clientAddress;
  final String clientPhone;
  final String clientEmail;
  final String facilityType;
  final List<String> targetedPests;
  final List<QuoteItem> items;
  final bool applyIva;
  final double ivaRate;
  final String termsAndConditions;
  final String notes;
  final String elaboratedBy;

  QuoteModel({
    required this.id,
    required this.quoteFolio,
    required this.quoteDate,
    this.validDays = 15,
    required this.clientBusinessName,
    required this.clientContactName,
    required this.clientAddress,
    required this.clientPhone,
    required this.clientEmail,
    this.facilityType = 'Comercial / Restaurante',
    this.targetedPests = const [],
    required this.items,
    this.applyIva = false,
    this.ivaRate = 0.16,
    String? termsAndConditions,
    this.notes = '',
    this.elaboratedBy = 'EJ Exterminadores',
  }) : termsAndConditions = termsAndConditions ?? defaultTermsAndConditions(validDays);

  static String defaultTermsAndConditions(int days) {
    return '1. Esta cotización tiene una validez de $days días naturales a partir de la fecha de emisión.\n'
        '2. El servicio tiene una garantía de 30 días.\n'
        '3. Todos los precios son mas I.V.A.\n'
        '4. Pago de contado en una sola exhibición al término de cada servicio.\n'
        '5. El servicio incluye un (1) tratamiento mensual, en los días y horario requeridos por el cliente y visitas de inspección y supervisión de servicio.\n'
        '6. Al concluir cada servicio se expide un Certificado de control de plagas avalado por la secretaria de salud (S.S.A.) y la orden de trabajo correspondiente.\n'
        '7. El cliente debe otorgar las facilidades de acceso, estacionamiento, tiempo y espacio a fin de realizar las labores correspondientes al servicio con la mayor brevedad y eficiencia posible.\n'
        '8. Cualquier servicio, producto, dispositivo o situación no contemplada en la presente cotización, deberá ser cotizada de manera independiente y puede tener un costo adicional.';
  }

  DateTime get validUntilDate => quoteDate.add(Duration(days: validDays));

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get ivaAmount => applyIva ? (subtotal * ivaRate) : 0.0;

  double get totalAmount => subtotal + ivaAmount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quoteFolio': quoteFolio,
      'quoteDate': quoteDate.toIso8601String(),
      'validDays': validDays,
      'clientBusinessName': clientBusinessName,
      'clientContactName': clientContactName,
      'clientAddress': clientAddress,
      'clientPhone': clientPhone,
      'clientEmail': clientEmail,
      'facilityType': facilityType,
      'targetedPests': targetedPests,
      'items': items.map((i) => i.toMap()).toList(),
      'applyIva': applyIva,
      'ivaRate': ivaRate,
      'termsAndConditions': termsAndConditions,
      'notes': notes,
      'elaboratedBy': elaboratedBy,
      'subtotal': subtotal,
      'ivaAmount': ivaAmount,
      'totalAmount': totalAmount,
    };
  }

  factory QuoteModel.fromMap(Map<String, dynamic> map) {
    final days = map['validDays'] ?? 15;
    return QuoteModel(
      id: map['id'] ?? '',
      quoteFolio: map['quoteFolio'] ?? '',
      quoteDate: DateTime.tryParse(map['quoteDate'] ?? '') ?? DateTime.now(),
      validDays: days,
      clientBusinessName: map['clientBusinessName'] ?? '',
      clientContactName: map['clientContactName'] ?? '',
      clientAddress: map['clientAddress'] ?? '',
      clientPhone: map['clientPhone'] ?? '',
      clientEmail: map['clientEmail'] ?? '',
      facilityType: map['facilityType'] ?? 'Comercial / Restaurante',
      targetedPests: List<String>.from(map['targetedPests'] ?? []),
      items: (map['items'] as List<dynamic>? ?? [])
          .map((i) => QuoteItem.fromMap(i as Map<String, dynamic>))
          .toList(),
      applyIva: map['applyIva'] ?? false,
      ivaRate: (map['ivaRate'] as num?)?.toDouble() ?? 0.16,
      termsAndConditions: map['termsAndConditions'] ?? defaultTermsAndConditions(days),
      notes: map['notes'] ?? '',
      elaboratedBy: map['elaboratedBy'] ?? 'EJ Exterminadores',
    );
  }
}
