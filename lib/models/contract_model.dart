import 'dart:convert';
import 'dart:typed_data';

class ContractModel {
  final String id;
  final String folio;
  final DateTime creationDate;

  // Datos del Cliente / Empresa
  final String clientName;
  final String businessName;
  final String rfc;
  final String address;
  final String phone;
  final String email;

  // Representante Legal y Documentación
  final String representativeName;
  final String representativeRole;
  final String representativePhone;
  final String? ineFrontPath;
  final String? ineBackPath;

  // Alcance y Condiciones de la Póliza
  final String serviceType;
  final int durationMonths;
  final DateTime startDate;
  final DateTime endDate;
  final String visitFrequency;
  final int totalVisits;
  final List<String> targetPests;
  final String coveredAreas;

  // Condiciones Económicas
  final double costPerVisit;
  final double monthlyCost;
  final double totalContractCost;
  final String paymentMethod;
  final String paymentTerms;

  // Cláusulas Adicionales y Jurisdicción
  final String specialClauses;
  final String jurisdiction;

  // Firmas en Pantalla (S-Pen)
  final Uint8List? clientSignatureBytes;
  final Uint8List? contractorSignatureBytes;
  final String signerFullName;
  final String? pdfPath;

  const ContractModel({
    required this.id,
    required this.folio,
    required this.creationDate,
    required this.clientName,
    required this.businessName,
    required this.rfc,
    required this.address,
    required this.phone,
    required this.email,
    required this.representativeName,
    required this.representativeRole,
    required this.representativePhone,
    this.ineFrontPath,
    this.ineBackPath,
    required this.serviceType,
    required this.durationMonths,
    required this.startDate,
    required this.endDate,
    required this.visitFrequency,
    required this.totalVisits,
    required this.targetPests,
    required this.coveredAreas,
    required this.costPerVisit,
    required this.monthlyCost,
    required this.totalContractCost,
    required this.paymentMethod,
    required this.paymentTerms,
    this.specialClauses = '',
    this.jurisdiction = 'Monterrey, Nuevo León',
    this.clientSignatureBytes,
    this.contractorSignatureBytes,
    required this.signerFullName,
    this.pdfPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folio': folio,
      'creationDate': creationDate.toIso8601String(),
      'clientName': clientName,
      'businessName': businessName,
      'rfc': rfc,
      'address': address,
      'phone': phone,
      'email': email,
      'representativeName': representativeName,
      'representativeRole': representativeRole,
      'representativePhone': representativePhone,
      'ineFrontPath': ineFrontPath,
      'ineBackPath': ineBackPath,
      'serviceType': serviceType,
      'durationMonths': durationMonths,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'visitFrequency': visitFrequency,
      'totalVisits': totalVisits,
      'targetPests': targetPests,
      'coveredAreas': coveredAreas,
      'costPerVisit': costPerVisit,
      'monthlyCost': monthlyCost,
      'totalContractCost': totalContractCost,
      'paymentMethod': paymentMethod,
      'paymentTerms': paymentTerms,
      'specialClauses': specialClauses,
      'jurisdiction': jurisdiction,
      'clientSignatureBase64': clientSignatureBytes != null ? base64Encode(clientSignatureBytes!) : null,
      'contractorSignatureBase64': contractorSignatureBytes != null ? base64Encode(contractorSignatureBytes!) : null,
      'signerFullName': signerFullName,
      'pdfPath': pdfPath,
    };
  }

  factory ContractModel.fromMap(Map<String, dynamic> map) {
    return ContractModel(
      id: map['id'] ?? '',
      folio: map['folio'] ?? '',
      creationDate: map['creationDate'] != null ? DateTime.parse(map['creationDate']) : DateTime.now(),
      clientName: map['clientName'] ?? '',
      businessName: map['businessName'] ?? '',
      rfc: map['rfc'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      representativeName: map['representativeName'] ?? '',
      representativeRole: map['representativeRole'] ?? '',
      representativePhone: map['representativePhone'] ?? '',
      ineFrontPath: map['ineFrontPath'],
      ineBackPath: map['ineBackPath'],
      serviceType: map['serviceType'] ?? 'Póliza Comercial / Industrial',
      durationMonths: map['durationMonths'] is int ? map['durationMonths'] : int.tryParse(map['durationMonths']?.toString() ?? '12') ?? 12,
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']) : DateTime.now(),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : DateTime.now(),
      visitFrequency: map['visitFrequency'] ?? 'Mensual (1 visita/mes)',
      totalVisits: map['totalVisits'] is int ? map['totalVisits'] : int.tryParse(map['totalVisits']?.toString() ?? '12') ?? 12,
      targetPests: (map['targetPests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      coveredAreas: map['coveredAreas'] ?? '',
      costPerVisit: (map['costPerVisit'] is num) ? (map['costPerVisit'] as num).toDouble() : double.tryParse(map['costPerVisit']?.toString() ?? '0') ?? 0.0,
      monthlyCost: (map['monthlyCost'] is num) ? (map['monthlyCost'] as num).toDouble() : double.tryParse(map['monthlyCost']?.toString() ?? '0') ?? 0.0,
      totalContractCost: (map['totalContractCost'] is num) ? (map['totalContractCost'] as num).toDouble() : double.tryParse(map['totalContractCost']?.toString() ?? '0') ?? 0.0,
      paymentMethod: map['paymentMethod'] ?? 'Transferencia Electrónica',
      paymentTerms: map['paymentTerms'] ?? 'Pago los primeros 5 días hábiles del mes',
      specialClauses: map['specialClauses'] ?? '',
      jurisdiction: map['jurisdiction'] ?? 'Monterrey, Nuevo León',
      clientSignatureBytes: map['clientSignatureBase64'] != null ? base64Decode(map['clientSignatureBase64']) : null,
      contractorSignatureBytes: map['contractorSignatureBase64'] != null ? base64Decode(map['contractorSignatureBase64']) : null,
      signerFullName: map['signerFullName'] ?? '',
      pdfPath: map['pdfPath'],
    );
  }

  ContractModel copyWith({
    String? id,
    String? folio,
    DateTime? creationDate,
    String? clientName,
    String? businessName,
    String? rfc,
    String? address,
    String? phone,
    String? email,
    String? representativeName,
    String? representativeRole,
    String? representativePhone,
    String? ineFrontPath,
    String? ineBackPath,
    String? serviceType,
    int? durationMonths,
    DateTime? startDate,
    DateTime? endDate,
    String? visitFrequency,
    int? totalVisits,
    List<String>? targetPests,
    String? coveredAreas,
    double? costPerVisit,
    double? monthlyCost,
    double? totalContractCost,
    String? paymentMethod,
    String? paymentTerms,
    String? specialClauses,
    String? jurisdiction,
    Uint8List? clientSignatureBytes,
    Uint8List? contractorSignatureBytes,
    String? signerFullName,
    String? pdfPath,
  }) {
    return ContractModel(
      id: id ?? this.id,
      folio: folio ?? this.folio,
      creationDate: creationDate ?? this.creationDate,
      clientName: clientName ?? this.clientName,
      businessName: businessName ?? this.businessName,
      rfc: rfc ?? this.rfc,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      representativeName: representativeName ?? this.representativeName,
      representativeRole: representativeRole ?? this.representativeRole,
      representativePhone: representativePhone ?? this.representativePhone,
      ineFrontPath: ineFrontPath ?? this.ineFrontPath,
      ineBackPath: ineBackPath ?? this.ineBackPath,
      serviceType: serviceType ?? this.serviceType,
      durationMonths: durationMonths ?? this.durationMonths,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      visitFrequency: visitFrequency ?? this.visitFrequency,
      totalVisits: totalVisits ?? this.totalVisits,
      targetPests: targetPests ?? this.targetPests,
      coveredAreas: coveredAreas ?? this.coveredAreas,
      costPerVisit: costPerVisit ?? this.costPerVisit,
      monthlyCost: monthlyCost ?? this.monthlyCost,
      totalContractCost: totalContractCost ?? this.totalContractCost,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      specialClauses: specialClauses ?? this.specialClauses,
      jurisdiction: jurisdiction ?? this.jurisdiction,
      clientSignatureBytes: clientSignatureBytes ?? this.clientSignatureBytes,
      contractorSignatureBytes: contractorSignatureBytes ?? this.contractorSignatureBytes,
      signerFullName: signerFullName ?? this.signerFullName,
      pdfPath: pdfPath ?? this.pdfPath,
    );
  }
}
