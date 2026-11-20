import 'dart:convert';
import '../utils/spanish_number_to_words.dart';

class CfdiInvoiceItem {
  final double quantity;
  final String description;
  final String satProductCode; // e.g. "10191700"
  final String satProductDesc; // e.g. "Dispositivos para control de plagas"
  final String satUnitCode; // e.g. "H87"
  final String satUnitDesc; // e.g. "Pieza"
  final String taxObject; // e.g. "02 - Sí objeto de impuesto"
  final double unitPrice;
  final double taxRate; // 0.16

  CfdiInvoiceItem({
    required this.quantity,
    required this.description,
    this.satProductCode = '72102100',
    this.satProductDesc = 'Servicios de control y exterminación de plagas',
    this.satUnitCode = 'E48',
    this.satUnitDesc = 'Unidad de servicio',
    this.taxObject = '02 - Sí objeto de impuesto',
    required this.unitPrice,
    this.taxRate = 0.16,
  });

  double get subtotal => double.parse((quantity * unitPrice).toStringAsFixed(2));
  double get taxAmount => taxObject.startsWith('02')
      ? double.parse((subtotal * taxRate).toStringAsFixed(2))
      : 0.0;
  double get total => double.parse((subtotal + taxAmount).toStringAsFixed(2));

  Map<String, dynamic> toMap() => {
        'quantity': quantity,
        'description': description,
        'satProductCode': satProductCode,
        'satProductDesc': satProductDesc,
        'satUnitCode': satUnitCode,
        'satUnitDesc': satUnitDesc,
        'taxObject': taxObject,
        'unitPrice': unitPrice,
        'taxRate': taxRate,
        'subtotal': subtotal,
        'taxAmount': taxAmount,
        'total': total,
      };

  factory CfdiInvoiceItem.fromMap(Map<String, dynamic> map) => CfdiInvoiceItem(
        quantity: (map['quantity'] ?? 1.0).toDouble(),
        description: map['description'] ?? '',
        satProductCode: map['satProductCode'] ?? '72102100',
        satProductDesc: map['satProductDesc'] ?? 'Servicios de control de plagas',
        satUnitCode: map['satUnitCode'] ?? 'E48',
        satUnitDesc: map['satUnitDesc'] ?? 'Unidad de servicio',
        taxObject: map['taxObject'] ?? '02 - Sí objeto de impuesto',
        unitPrice: (map['unitPrice'] ?? 0.0).toDouble(),
        taxRate: (map['taxRate'] ?? 0.16).toDouble(),
      );
}

class CfdiTimbreDigital {
  final String uuid;
  final String noCertificadoEmisor;
  final String noCertificadoSAT;
  final DateTime fechaCertificacion;
  final String cadenaOriginal;
  final String selloEmisor;
  final String selloSAT;
  final String rfcProvCertif;
  final String qrString;

  CfdiTimbreDigital({
    required this.uuid,
    required this.noCertificadoEmisor,
    required this.noCertificadoSAT,
    required this.fechaCertificacion,
    required this.cadenaOriginal,
    required this.selloEmisor,
    required this.selloSAT,
    this.rfcProvCertif = 'FFM100507289',
    required this.qrString,
  });

  Map<String, dynamic> toMap() => {
        'uuid': uuid,
        'noCertificadoEmisor': noCertificadoEmisor,
        'noCertificadoSAT': noCertificadoSAT,
        'fechaCertificacion': fechaCertificacion.toIso8601String(),
        'cadenaOriginal': cadenaOriginal,
        'selloEmisor': selloEmisor,
        'selloSAT': selloSAT,
        'rfcProvCertif': rfcProvCertif,
        'qrString': qrString,
      };

  factory CfdiTimbreDigital.fromMap(Map<String, dynamic> map) => CfdiTimbreDigital(
        uuid: map['uuid'] ?? '',
        noCertificadoEmisor: map['noCertificadoEmisor'] ?? '',
        noCertificadoSAT: map['noCertificadoSAT'] ?? '',
        fechaCertificacion: DateTime.tryParse(map['fechaCertificacion']?.toString() ?? '') ?? DateTime.now(),
        cadenaOriginal: map['cadenaOriginal'] ?? '',
        selloEmisor: map['selloEmisor'] ?? '',
        selloSAT: map['selloSAT'] ?? '',
        rfcProvCertif: map['rfcProvCertif'] ?? 'FFM100507289',
        qrString: map['qrString'] ?? '',
      );
}

class CfdiInvoiceData {
  final String series; // e.g. "AFAD"
  final String folio; // e.g. "382"
  final DateTime emissionDate;
  final String expeditionZip; // "66056"
  final String voucherType; // "I - Ingreso"

  // Emisor fijo (Jorge Alberto Elizondo Juarez)
  final String issuerName;
  final String issuerCommercial;
  final String issuerRfc;
  final String issuerStreet;
  final String issuerColony;
  final String issuerZip;
  final String issuerCity;
  final String issuerState;
  final String issuerPhone;
  final String issuerEmail;
  final String issuerRegime;

  // Receptor / Cliente
  final String receiverBusinessName; // Razón Social
  final String receiverCommercialName; // Nombre Comercial
  final String receiverRfc;
  final String receiverAddress;
  final String receiverZip;
  final String receiverCfdiUse;
  final String receiverRegime;

  // Conceptos
  final List<CfdiInvoiceItem> items;

  // Condiciones de Pago
  final String paymentForm; // "03 - Transferencia electrónica de fondos"
  final String paymentMethod; // "PUE - Pago en una sola exhibición"
  final String bankInstitution; // "HSBC"
  final String bankAccount; // "021580066278483086"
  final String currency; // "MXN"
  final double exchangeRate; // 1.0000
  final String exportation; // "01 - No aplica"
  final String observations;

  // Timbre Digital SAT
  final CfdiTimbreDigital? timbre;

  CfdiInvoiceData({
    this.series = 'AFAD',
    required this.folio,
    required this.emissionDate,
    this.expeditionZip = '66056',
    this.voucherType = 'I - Ingreso',
    this.issuerName = 'JORGE ALBERTO ELIZONDO JUAREZ',
    this.issuerCommercial = 'EJ Digital',
    this.issuerRfc = 'EIJJ880119CM7',
    this.issuerStreet = 'PASEO ESTUDIANTIL 151',
    this.issuerColony = 'Monterreal IX C.P. 66056',
    this.issuerZip = '66056',
    this.issuerCity = 'Ciudad General Escobedo',
    this.issuerState = 'General Escobedo, Nuevo León, México',
    this.issuerPhone = '8131759342',
    this.issuerEmail = 'jelizondo@ejexterminadores.com',
    this.issuerRegime = '612 - Personas Físicas con Actividades Empresariales y Profesionales',
    required this.receiverBusinessName,
    this.receiverCommercialName = '',
    required this.receiverRfc,
    this.receiverAddress = '',
    required this.receiverZip,
    this.receiverCfdiUse = 'G03 - Gastos en general',
    this.receiverRegime = '601 - General de Ley Personas Morales',
    required this.items,
    this.paymentForm = '03 - Transferencia electrónica de fondos',
    this.paymentMethod = 'PUE - Pago en una sola exhibición',
    this.bankInstitution = 'HSBC',
    this.bankAccount = '021580066278483086',
    this.currency = 'MXN',
    this.exchangeRate = 1.0000,
    this.exportation = '01 - No aplica',
    this.observations = '',
    this.timbre,
  });

  String get fullFolio => '$series$folio';

  double get subtotal {
    double sum = 0.0;
    for (final it in items) {
      sum += it.subtotal;
    }
    return double.parse(sum.toStringAsFixed(2));
  }

  double get ivaAmount {
    double sum = 0.0;
    for (final it in items) {
      sum += it.taxAmount;
    }
    return double.parse(sum.toStringAsFixed(2));
  }

  double get total => double.parse((subtotal + ivaAmount).toStringAsFixed(2));

  String get totalInWords => SpanishNumberToWords.convert(total);

  Map<String, dynamic> toMap() => {
        'series': series,
        'folio': folio,
        'emissionDate': emissionDate.toIso8601String(),
        'expeditionZip': expeditionZip,
        'voucherType': voucherType,
        'issuerName': issuerName,
        'issuerCommercial': issuerCommercial,
        'issuerRfc': issuerRfc,
        'issuerStreet': issuerStreet,
        'issuerColony': issuerColony,
        'issuerZip': issuerZip,
        'issuerCity': issuerCity,
        'issuerState': issuerState,
        'issuerPhone': issuerPhone,
        'issuerEmail': issuerEmail,
        'issuerRegime': issuerRegime,
        'receiverBusinessName': receiverBusinessName,
        'receiverCommercialName': receiverCommercialName,
        'receiverRfc': receiverRfc,
        'receiverAddress': receiverAddress,
        'receiverZip': receiverZip,
        'receiverCfdiUse': receiverCfdiUse,
        'receiverRegime': receiverRegime,
        'items': items.map((x) => x.toMap()).toList(),
        'paymentForm': paymentForm,
        'paymentMethod': paymentMethod,
        'bankInstitution': bankInstitution,
        'bankAccount': bankAccount,
        'currency': currency,
        'exchangeRate': exchangeRate,
        'exportation': exportation,
        'observations': observations,
        'timbre': timbre?.toMap(),
        'subtotal': subtotal,
        'ivaAmount': ivaAmount,
        'total': total,
        'totalInWords': totalInWords,
      };

  factory CfdiInvoiceData.fromMap(Map<String, dynamic> map) => CfdiInvoiceData(
        series: map['series'] ?? 'AFAD',
        folio: map['folio'] ?? '1',
        emissionDate: DateTime.tryParse(map['emissionDate']?.toString() ?? '') ?? DateTime.now(),
        expeditionZip: map['expeditionZip'] ?? '66056',
        voucherType: map['voucherType'] ?? 'I - Ingreso',
        issuerName: map['issuerName'] ?? 'JORGE ALBERTO ELIZONDO JUAREZ',
        issuerCommercial: map['issuerCommercial'] ?? 'EJ Digital',
        issuerRfc: map['issuerRfc'] ?? 'EIJJ880119CM7',
        issuerStreet: map['issuerStreet'] ?? 'PASEO ESTUDIANTIL 151',
        issuerColony: map['issuerColony'] ?? 'Monterreal IX C.P. 66056',
        issuerZip: map['issuerZip'] ?? '66056',
        issuerCity: map['issuerCity'] ?? 'Ciudad General Escobedo',
        issuerState: map['issuerState'] ?? 'General Escobedo, Nuevo León, México',
        issuerPhone: map['issuerPhone'] ?? '8131759342',
        issuerEmail: map['issuerEmail'] ?? 'jelizondo@ejexterminadores.com',
        issuerRegime: map['issuerRegime'] ?? '612 - Personas Físicas con Actividades Empresariales y Profesionales',
        receiverBusinessName: map['receiverBusinessName'] ?? '',
        receiverCommercialName: map['receiverCommercialName'] ?? '',
        receiverRfc: map['receiverRfc'] ?? '',
        receiverAddress: map['receiverAddress'] ?? '',
        receiverZip: map['receiverZip'] ?? '',
        receiverCfdiUse: map['receiverCfdiUse'] ?? 'G03 - Gastos en general',
        receiverRegime: map['receiverRegime'] ?? '601 - General de Ley Personas Morales',
        items: (map['items'] as List<dynamic>? ?? [])
            .map((e) => CfdiInvoiceItem.fromMap(e as Map<String, dynamic>))
            .toList(),
        paymentForm: map['paymentForm'] ?? '03 - Transferencia electrónica de fondos',
        paymentMethod: map['paymentMethod'] ?? 'PUE - Pago en una sola exhibición',
        bankInstitution: map['bankInstitution'] ?? 'HSBC',
        bankAccount: map['bankAccount'] ?? '021580066278483086',
        currency: map['currency'] ?? 'MXN',
        exchangeRate: (map['exchangeRate'] ?? 1.0).toDouble(),
        exportation: map['exportation'] ?? '01 - No aplica',
        observations: map['observations'] ?? '',
        timbre: map['timbre'] != null ? CfdiTimbreDigital.fromMap(map['timbre']) : null,
      );
}
