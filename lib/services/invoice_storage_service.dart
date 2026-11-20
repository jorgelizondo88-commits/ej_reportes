import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cfdi_invoice_data.dart';

class InvoiceStorageService {
  static const String _recentConceptsKey = 'ej_recent_invoice_concepts';
  static const String _clientTemplatePrefix = 'ej_client_invoice_template_';
  static const String _lastFolioKey = 'ej_invoice_last_folio_number';
  static const String _seriesKey = 'ej_invoice_series';

  /// Guarda un concepto en la memoria histórica de autocompletado
  static Future<void> saveRecentConcept(CfdiInvoiceItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentConceptsKey);
    List<dynamic> list = [];
    if (raw != null) {
      try {
        list = jsonDecode(raw);
      } catch (_) {
        list = [];
      }
    }

    // Evitar duplicados por descripción
    list.removeWhere((e) => (e['description'] ?? '').toString().toLowerCase().trim() == item.description.toLowerCase().trim());
    list.insert(0, item.toMap());

    // Guardar hasta 30 conceptos recientes
    if (list.length > 30) {
      list = list.sublist(0, 30);
    }

    await prefs.setString(_recentConceptsKey, jsonEncode(list));
  }

  /// Recupera los conceptos usados recientemente
  static Future<List<CfdiInvoiceItem>> getRecentConcepts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentConceptsKey);
    if (raw == null || raw.isEmpty) {
      // Conceptos iniciales de cortesía para plagas
      return [
        CfdiInvoiceItem(
          quantity: 1,
          description: 'Servicio de Control y Manejo Integrado de Plagas',
          satProductCode: '72102100',
          satProductDesc: 'Servicios de control y exterminación de plagas',
          satUnitCode: 'E48',
          satUnitDesc: 'Unidad de servicio',
          unitPrice: 1500.0,
        ),
        CfdiInvoiceItem(
          quantity: 1,
          description: 'Estación de Cebado para Roedores',
          satProductCode: '10191700',
          satProductDesc: 'Dispositivos para control de plagas',
          satUnitCode: 'H87',
          satUnitDesc: 'Pieza',
          unitPrice: 150.0,
        ),
        CfdiInvoiceItem(
          quantity: 1,
          description: 'Lámpara Trampa de Luz UV para Insectos Voladores',
          satProductCode: '42281504',
          satProductDesc: 'Dispositivos para control de plagas',
          satUnitCode: 'H87',
          satUnitDesc: 'Pieza',
          unitPrice: 1400.0,
        ),
      ];
    }

    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => CfdiInvoiceItem.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Guarda los conceptos de la última factura de este cliente para plantilla mensual
  static Future<void> saveClientLastInvoice(String clientId, CfdiInvoiceData invoice) async {
    if (clientId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_clientTemplatePrefix$clientId';
    await prefs.setString(key, jsonEncode(invoice.toMap()));
  }

  /// Recupera la última factura de este cliente
  static Future<CfdiInvoiceData?> getClientLastInvoice(String clientId) async {
    if (clientId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_clientTemplatePrefix$clientId';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return CfdiInvoiceData.fromMap(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// Serie de la factura (default 'AFAD' como usa Jorge)
  static Future<String> getSeries() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_seriesKey) ?? 'AFAD';
  }

  static Future<void> setSeries(String series) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seriesKey, series.trim().toUpperCase());
  }

  /// Obtiene el siguiente folio consecutivo
  static Future<int> getNextFolioNumber() async {
    final prefs = await SharedPreferences.getInstance();
    // Default 383 porque la última que Jorge emitió fue AFAD382
    final current = prefs.getInt(_lastFolioKey) ?? 382;
    return current + 1;
  }

  /// Actualiza el último folio registrado tras timbrar
  static Future<void> updateLastFolioNumber(int folio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastFolioKey, folio);
  }

  static const String _customTemplatesKey = 'ej_invoice_custom_templates';

  /// Guarda una plantilla personalizada definida por el usuario
  static Future<void> saveCustomTemplate(InvoiceTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    final templates = await getCustomTemplates();
    templates.removeWhere((t) => t.id == template.id);
    templates.insert(0, template);
    await prefs.setString(_customTemplatesKey, jsonEncode(templates.map((t) => t.toMap()).toList()));
  }

  /// Obtiene la lista de plantillas guardadas por el usuario
  static Future<List<InvoiceTemplate>> getCustomTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customTemplatesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => InvoiceTemplate.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Elimina una plantilla guardada
  static Future<void> deleteCustomTemplate(String templateId) async {
    final prefs = await SharedPreferences.getInstance();
    final templates = await getCustomTemplates();
    templates.removeWhere((t) => t.id == templateId);
    await prefs.setString(_customTemplatesKey, jsonEncode(templates.map((t) => t.toMap()).toList()));
  }
}

class InvoiceTemplate {
  final String id;
  final String name; // e.g. "Confianza Médica - Póliza Mensual"
  final String clientId;
  final String clientName;
  final List<CfdiInvoiceItem> items;
  final String paymentForm;
  final String paymentMethod;
  final String observations;
  final bool includeBankInfo;
  final DateTime createdAt;

  InvoiceTemplate({
    required this.id,
    required this.name,
    required this.clientId,
    required this.clientName,
    required this.items,
    this.paymentForm = '03 - Transferencia electrónica de fondos',
    this.paymentMethod = 'PUE - Pago en una sola exhibición',
    this.observations = '',
    this.includeBankInfo = true,
    required this.createdAt,
  });

  double get total {
    double sum = 0.0;
    for (final it in items) {
      sum += it.total;
    }
    return sum;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'clientId': clientId,
    'clientName': clientName,
    'items': items.map((it) => it.toMap()).toList(),
    'paymentForm': paymentForm,
    'paymentMethod': paymentMethod,
    'observations': observations,
    'includeBankInfo': includeBankInfo,
    'createdAt': createdAt.toIso8601String(),
  };

  factory InvoiceTemplate.fromMap(Map<String, dynamic> map) {
    return InvoiceTemplate(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'] ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => CfdiInvoiceItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      paymentForm: map['paymentForm'] ?? '03 - Transferencia electrónica de fondos',
      paymentMethod: map['paymentMethod'] ?? 'PUE - Pago en una sola exhibición',
      observations: map['observations'] ?? '',
      includeBankInfo: map['includeBankInfo'] ?? true,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
