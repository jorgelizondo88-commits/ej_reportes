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
  final String paymentTerms;
  final String warranty;
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
    this.paymentTerms = '50% de anticipo y 50% al finalizar el servicio.',
    this.warranty = '30 días de garantía en el servicio aplicado.',
    this.notes = 'Precios expresados en moneda nacional (MXN).',
    this.elaboratedBy = 'EJ Exterminadores',
  });

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
      'paymentTerms': paymentTerms,
      'warranty': warranty,
      'notes': notes,
      'elaboratedBy': elaboratedBy,
      'subtotal': subtotal,
      'ivaAmount': ivaAmount,
      'totalAmount': totalAmount,
    };
  }

  factory QuoteModel.fromMap(Map<String, dynamic> map) {
    return QuoteModel(
      id: map['id'] ?? '',
      quoteFolio: map['quoteFolio'] ?? '',
      quoteDate: DateTime.tryParse(map['quoteDate'] ?? '') ?? DateTime.now(),
      validDays: map['validDays'] ?? 15,
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
      paymentTerms: map['paymentTerms'] ?? '50% de anticipo y 50% al finalizar el servicio.',
      warranty: map['warranty'] ?? '30 días de garantía en el servicio aplicado.',
      notes: map['notes'] ?? 'Precios expresados en moneda nacional (MXN).',
      elaboratedBy: map['elaboratedBy'] ?? 'EJ Exterminadores',
    );
  }
}
