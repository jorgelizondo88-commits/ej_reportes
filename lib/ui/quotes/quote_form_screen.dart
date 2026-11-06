import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';
import '../../models/client_model.dart';
import '../../models/quote_model.dart';
import '../../services/client_service.dart';
import 'quote_history_screen.dart';
import 'quote_preview_screen.dart';

class QuoteFormScreen extends StatefulWidget {
  final ClientModel? preselectedClient;

  const QuoteFormScreen({super.key, this.preselectedClient});

  @override
  State<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends State<QuoteFormScreen> {
  static const String _quoteDraftKey = 'ej_active_quote_draft';
  static const String _quoteFolioCounterKey = 'ej_consecutive_quote_counter';
  static const String _prefTechNameKey = 'ej_saved_tech_name';
  static const String _prefTechSignKey = 'ej_saved_tech_sign';

  final ClientService _clientService = ClientService();
  List<ClientModel> _savedClients = [];
  ClientModel? _selectedClient;

  late TextEditingController _folioController;
  late TextEditingController _businessController;
  late TextEditingController _contactController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _termsController;
  late TextEditingController _notesController;
  late TextEditingController _repController;

  DateTime _quoteDate = DateTime.now();
  int _validDays = 15;
  String _facilityType = 'Comercial / Restaurante';
  bool _applyIva = false;
  bool _saveNewClientToDb = true;

  bool _includeSignature = true;
  Uint8List? _signatureBytes;
  bool _hasSavedReportSignature = false;

  final List<String> _targetedPests = [];
  final List<QuoteItem> _items = [];

  final List<String> _facilityTypes = [
    'Comercial / Restaurante',
    'Industrial / Bodega',
    'Residencial / Casa',
    'Oficinas / Corporativo',
    'Hospitalario / Clínica',
  ];

  final List<String> _availablePests = [
    'Cucaracha alemana',
    'Cucaracha americana',
    'Roedores (Rata/Ratón)',
    'Hormigas',
    'Moscas / Mosquitos',
    'Chinches de cama',
    'Alacranes / Arañas',
    'Termitas',
  ];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadClients();
    _loadSavedSignatureAndRep();
    if (widget.preselectedClient != null) {
      _applyClient(widget.preselectedClient!);
    } else {
      _initDraftOrNew();
    }
  }

  Future<void> _loadSavedSignatureAndRep() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTechName = prefs.getString(_prefTechNameKey);
    final savedTechSign = prefs.getString(_prefTechSignKey);

    if (mounted) {
      setState(() {
        if ((_repController.text.trim().isEmpty || _repController.text == 'EJ Exterminadores') &&
            savedTechName != null &&
            savedTechName.trim().isNotEmpty) {
          _repController.text = savedTechName.trim();
        }

        if (savedTechSign != null && savedTechSign.isNotEmpty) {
          _hasSavedReportSignature = true;
          if (_signatureBytes == null) {
            try {
              _signatureBytes = base64Decode(savedTechSign);
            } catch (_) {}
          }
        }
      });
    }
  }

  void _initControllers() {
    _folioController = TextEditingController(text: _formatFolio(1, DateTime.now()));
    _businessController = TextEditingController();
    _contactController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _termsController = TextEditingController(text: QuoteModel.defaultTermsAndConditions(_validDays));
    _notesController = TextEditingController();
    _repController = TextEditingController(text: 'EJ Exterminadores');
  }

  @override
  void dispose() {
    _folioController.dispose();
    _businessController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _termsController.dispose();
    _notesController.dispose();
    _repController.dispose();
    super.dispose();
  }

  String _formatFolio(int counter, DateTime date) {
    final monthStr = date.month.toString().padLeft(2, '0');
    final yearStr = (date.year % 100).toString().padLeft(2, '0');
    final sequenceStr = counter.toString().padLeft(4, '0');
    return 'EJ-COT-$monthStr$yearStr-$sequenceStr';
  }

  Future<void> _loadClients() async {
    final clients = await _clientService.getSavedClients();
    if (mounted) {
      setState(() => _savedClients = clients);
    }
  }

  Future<int> _calculateNextQuoteNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getString('ej_quotes_history_list');
    int maxNumber = 0;
    if (rawHistory != null && rawHistory.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(rawHistory);
        for (final item in list) {
          final folioStr = (item['folio'] ?? item['quoteFolio'] ?? '').toString();
          final match = RegExp(r'(\d+)$').firstMatch(folioStr);
          if (match != null) {
            final num = int.tryParse(match.group(1)!);
            if (num != null && num > maxNumber) {
              maxNumber = num;
            }
          }
        }
      } catch (_) {}
    }
    final counterFromPrefs = prefs.getInt(_quoteFolioCounterKey) ?? 0;
    final nextNumber = (maxNumber > counterFromPrefs ? maxNumber : counterFromPrefs) + 1;
    return nextNumber;
  }

  Future<void> _initDraftOrNew() async {
    final prefs = await SharedPreferences.getInstance();
    final rawDraft = prefs.getString(_quoteDraftKey);

    if (rawDraft != null && rawDraft.isNotEmpty) {
      _restoreDraft(rawDraft);
    } else {
      final nextNumber = await _calculateNextQuoteNumber();
      setState(() {
        _folioController.text = _formatFolio(nextNumber, DateTime.now());
      });
    }
  }

  void _restoreDraft(String raw) {
    try {
      final map = jsonDecode(raw);
      setState(() {
        _folioController.text = map['quoteFolio'] ?? _folioController.text;
        _quoteDate = DateTime.tryParse(map['quoteDate'] ?? '') ?? DateTime.now();
        _validDays = map['validDays'] ?? 15;
        _businessController.text = map['clientBusinessName'] ?? '';
        _contactController.text = map['clientContactName'] ?? '';
        _addressController.text = map['clientAddress'] ?? '';
        _phoneController.text = map['clientPhone'] ?? '';
        _emailController.text = map['clientEmail'] ?? '';
        _facilityType = map['facilityType'] ?? 'Comercial / Restaurante';
        _termsController.text = map['termsAndConditions'] ?? QuoteModel.defaultTermsAndConditions(_validDays);
        _notesController.text = map['notes'] ?? _notesController.text;
        _repController.text = map['elaboratedBy'] ?? _repController.text;
        _applyIva = map['applyIva'] ?? false;
        _includeSignature = map['includeSignature'] ?? true;
        if (map['signatureBase64'] != null) {
          try {
            _signatureBytes = base64Decode(map['signatureBase64']);
          } catch (_) {}
        }

        _targetedPests.clear();
        if (map['targetedPests'] != null) {
          _targetedPests.addAll(List<String>.from(map['targetedPests']));
        }

        _items.clear();
        if (map['items'] != null) {
          for (var itemMap in (map['items'] as List)) {
            _items.add(QuoteItem.fromMap(itemMap));
          }
        }
      });
    } catch (_) {}
  }

  void _onValidDaysChanged(int newDays) {
    setState(() {
      _validDays = newDays;
      final currentText = _termsController.text;
      if (currentText.isEmpty) {
        _termsController.text = QuoteModel.defaultTermsAndConditions(newDays);
      } else {
        // Corrige automáticamente los días en la cláusula 1
        final updated = currentText.replaceAll(
          RegExp(r'validez de \d+ días naturales', caseSensitive: false),
          'validez de $newDays días naturales',
        );
        _termsController.text = updated;
      }
    });
    _saveDraft();
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftMap = {
      'quoteFolio': _folioController.text,
      'quoteDate': _quoteDate.toIso8601String(),
      'validDays': _validDays,
      'clientBusinessName': _businessController.text,
      'clientContactName': _contactController.text,
      'clientAddress': _addressController.text,
      'clientPhone': _phoneController.text,
      'clientEmail': _emailController.text,
      'facilityType': _facilityType,
      'targetedPests': _targetedPests,
      'termsAndConditions': _termsController.text,
      'notes': _notesController.text,
      'elaboratedBy': _repController.text,
      'includeSignature': _includeSignature,
      'signatureBase64': _signatureBytes != null ? base64Encode(_signatureBytes!) : null,
      'applyIva': _applyIva,
      'items': _items.map((i) => i.toMap()).toList(),
    };
    await prefs.setString(_quoteDraftKey, jsonEncode(draftMap));
  }

  Future<void> _openFullScreenSignature() async {
    final controller = SignatureController(
      penStrokeWidth: 4,
      penColor: Colors.black,
      exportBackgroundColor: Colors.transparent,
    );

    final Uint8List? result = await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text('Firma del Asesor / Prestador'),
              backgroundColor: const Color(0xFF0F2B48),
              foregroundColor: Colors.white,
              actions: [
                TextButton(
                  onPressed: () => controller.clear(),
                  child: const Text('Limpiar', style: TextStyle(color: Colors.white)),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    if (controller.isNotEmpty) {
                      final bytes = await controller.toPngBytes();
                      if (context.mounted) Navigator.pop(context, bytes);
                    } else {
                      if (context.mounted) Navigator.pop(context, null);
                    }
                  },
                  child: const Text('Guardar'),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.amber.shade50,
                    width: double.infinity,
                    child: const Text(
                      'Firme dentro del área blanca para plasmar su firma en las cotizaciones.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.brown),
                    ),
                  ),
                  Expanded(
                    child: Signature(
                      controller: controller,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result != null) {
      setState(() {
        _signatureBytes = result;
        _includeSignature = true;
      });
      _saveDraft();

      if (mounted) {
        final saveAsDefault = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('¿Fijar como Firma Predeterminada?'),
            content: const Text(
              '¿Deseas fijar esta firma también como tu firma predeterminada para que se use tanto en Reportes como en futuras Cotizaciones?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Solo para esta cotización'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2B48),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Fijar para Todo'),
              ),
            ],
          ),
        );

        if (saveAsDefault == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefTechSignKey, base64Encode(result));
          if (_repController.text.trim().isNotEmpty) {
            await prefs.setString(_prefTechNameKey, _repController.text.trim());
          }
          if (mounted) {
            setState(() => _hasSavedReportSignature = true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Firma fijada como predeterminada para Reportes y Cotizaciones!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    }
  }

  void _applyClient(ClientModel client) {
    setState(() {
      _selectedClient = client;
      _businessController.text = client.businessName;
      _contactController.text = client.contactName;
      _addressController.text = client.address;
      _phoneController.text = client.phone;
      _emailController.text = client.email;
      if (_facilityTypes.contains(client.facilityType)) {
        _facilityType = client.facilityType;
      }
    });
    _saveDraft();
  }

  Future<void> _clearDraftAndNewQuote() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Iniciar Nueva Cotización?'),
        content: const Text(
          'Esto limpiará todos los campos para comenzar una cotización en blanco y generará el siguiente folio consecutivo.\n\n(Los clientes guardados y el historial no se afectarán).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpiar Todo'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_quoteDraftKey);

      final nextCounter = await _calculateNextQuoteNumber();
      await prefs.setInt(_quoteFolioCounterKey, nextCounter);

      final nextFolio = _formatFolio(nextCounter, DateTime.now());

      setState(() {
        _folioController.text = nextFolio;
        _businessController.clear();
        _contactController.clear();
        _addressController.clear();
        _phoneController.clear();
        _emailController.clear();
        _selectedClient = null;
        _items.clear();
        _targetedPests.clear();
        _quoteDate = DateTime.now();
        _validDays = 15;
        _termsController.text = QuoteModel.defaultTermsAndConditions(15);
        _notesController.clear();
        _applyIva = false;
      });
    }
  }

  void _addItemDialog({QuoteItem? existingItem, int? index}) {
    final conceptCtrl = TextEditingController(text: existingItem?.concept ?? '');
    final descCtrl = TextEditingController(text: existingItem?.description ?? '');
    final qtyCtrl = TextEditingController(text: existingItem != null ? (existingItem.quantity == existingItem.quantity.roundToDouble() ? existingItem.quantity.toInt().toString() : existingItem.quantity.toString()) : '1');
    final priceCtrl = TextEditingController(text: existingItem != null ? existingItem.unitPrice.toStringAsFixed(2) : '');
    String unit = existingItem?.unit ?? 'Servicio';

    final commonConcepts = [
      'Servicio de Control y Manejo Integral de Plagas',
      'Póliza Mensual de Fumigación y Monitoreo',
      'Instalación de Estaciones de Cebado (Roedores)',
      'Servicio de Desinfección Patógena y Sanitización',
      'Tratamiento Especializado contra Termitas',
      'Tratamiento Integral contra Chinches de Cama',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      existingItem != null ? 'Editar Concepto' : 'Agregar Concepto / Servicio',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Sugerencias frecuentes:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: commonConcepts.map((preset) {
                    return ActionChip(
                      label: Text(preset, style: const TextStyle(fontSize: 11)),
                      backgroundColor: const Color(0xFF0F2B48).withOpacity(0.06),
                      onPressed: () {
                        setModalState(() {
                          conceptCtrl.text = preset;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: conceptCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Concepto / Servicio *',
                    hintText: 'Ej. Control Integral de Plagas',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Detalles / Alcance (Opcional)',
                    hintText: 'Ej. Aspersión perimetral, cebado de trampas y nebulización.',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Cantidad *'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: unit,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Unidad',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        items: ['Servicio', 'Póliza', 'Mes', 'Pza', 'Visita', 'Lote']
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => unit = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'P. Unitario (\$)*'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F2B48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check),
                    label: Text(existingItem != null ? 'Guardar Cambios' : 'Agregar a la Cotización'),
                    onPressed: () {
                      final concept = conceptCtrl.text.trim();
                      final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                      final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;

                      if (concept.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Por favor ingresa el nombre del concepto.')),
                        );
                        return;
                      }

                      final item = QuoteItem(
                        id: existingItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        concept: concept,
                        description: descCtrl.text.trim(),
                        quantity: qty,
                        unit: unit,
                        unitPrice: price,
                      );

                      setState(() {
                        if (index != null && index >= 0) {
                          _items[index] = item;
                        } else {
                          _items.add(item);
                        }
                      });

                      _saveDraft();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _generateAndPreviewQuote() async {
    final business = _businessController.text.trim();
    final contact = _contactController.text.trim();

    if (business.isEmpty && contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa al menos la Razón Social o el Nombre de Contacto del cliente.')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un concepto o servicio a la cotización.')),
      );
      return;
    }

    // Guardar cliente en BD si se seleccionó la opción y es nuevo
    if (_saveNewClientToDb && business.isNotEmpty) {
      final newClient = ClientModel(
        id: _selectedClient?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        businessName: business,
        contactName: contact,
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        facilityType: _facilityType,
        hasTraps: false,
      );
      await _clientService.saveClient(newClient);
      _loadClients();
    }

    final quote = QuoteModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      quoteFolio: _folioController.text.trim(),
      quoteDate: _quoteDate,
      validDays: _validDays,
      clientBusinessName: business,
      clientContactName: contact,
      clientAddress: _addressController.text.trim(),
      clientPhone: _phoneController.text.trim(),
      clientEmail: _emailController.text.trim(),
      facilityType: _facilityType,
      targetedPests: _targetedPests,
      items: _items,
      applyIva: _applyIva,
      termsAndConditions: _termsController.text.trim(),
      notes: _notesController.text.trim(),
      elaboratedBy: _repController.text.trim().isNotEmpty ? _repController.text.trim() : 'EJ Exterminadores',
      includeSignature: _includeSignature,
      signatureBase64: _includeSignature && _signatureBytes != null ? base64Encode(_signatureBytes!) : null,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuotePreviewScreen(quote: quote),
      ),
    );
  }

  double get _subtotal => _items.fold(0.0, (sum, i) => sum + i.totalPrice);
  double get _iva => _applyIva ? (_subtotal * 0.16) : 0.0;
  double get _total => _subtotal + _iva;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Cotización', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_shared_outlined),
            tooltip: 'Historial de Cotizaciones',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QuoteHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            tooltip: 'Limpiar / Nueva Cotización',
            onPressed: _clearDraftAndNewQuote,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Folio y Fecha
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Datos Generales de la Cotización', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48))),
                    const SizedBox(height: 12),
                    // Folio con ancho completo para visualizar siempre hasta el último dígito
                    TextField(
                      controller: _folioController,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48), letterSpacing: 0.5),
                      decoration: const InputDecoration(
                        labelText: 'Folio de Cotización',
                        prefixIcon: Icon(Icons.tag, size: 20, color: Color(0xFF0F2B48)),
                      ),
                      onChanged: (_) => _saveDraft(),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _quoteDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => _quoteDate = picked);
                          _saveDraft();
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha de Emisión',
                          prefixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                        ),
                        child: Text(dateFormat.format(_quoteDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: _validDays,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Vigencia de la Cotización',
                        prefixIcon: Icon(Icons.timer_outlined, size: 20),
                      ),
                      items: const [
                        DropdownMenuItem(value: 7, child: Text('7 días naturales')),
                        DropdownMenuItem(value: 15, child: Text('15 días naturales (Estándar)')),
                        DropdownMenuItem(value: 30, child: Text('30 días naturales')),
                        DropdownMenuItem(value: 60, child: Text('60 días naturales')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          _onValidDaysChanged(val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Selector y Datos del Cliente
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Datos del Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48))),
                        if (_savedClients.isNotEmpty)
                          TextButton.icon(
                            icon: const Icon(Icons.people_outline, size: 18),
                            label: const Text('Cargar Cliente'),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                                builder: (context) => ListView.builder(
                                  itemCount: _savedClients.length,
                                  itemBuilder: (context, i) {
                                    final c = _savedClients[i];
                                    return ListTile(
                                      title: Text(c.businessName.isNotEmpty ? c.businessName : c.contactName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('${c.contactName} • ${c.phone}'),
                                      onTap: () {
                                        _applyClient(c);
                                        Navigator.pop(context);
                                      },
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _businessController,
                      decoration: const InputDecoration(labelText: 'Razón Social / Nombre del Negocio *'),
                      onChanged: (_) => _saveDraft(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _contactController,
                            decoration: const InputDecoration(labelText: 'Persona de Contacto'),
                            onChanged: (_) => _saveDraft(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'Teléfono'),
                            onChanged: (_) => _saveDraft(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Dirección del Servicio'),
                      onChanged: (_) => _saveDraft(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                      onChanged: (_) => _saveDraft(),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _facilityTypes.contains(_facilityType) ? _facilityType : _facilityTypes.first,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Giro / Instalación',
                        prefixIcon: Icon(Icons.business_outlined, size: 20),
                      ),
                      items: _facilityTypes
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _facilityType = val);
                          _saveDraft();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Plagas a tratar (Opcional)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Plagas a Tratar en esta Cotización', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _availablePests.map((pest) {
                        final isSelected = _targetedPests.contains(pest);
                        return FilterChip(
                          label: Text(pest, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                          selected: isSelected,
                          selectedColor: const Color(0xFF0F2B48),
                          checkmarkColor: Colors.white,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _targetedPests.add(pest);
                              } else {
                                _targetedPests.remove(pest);
                              }
                            });
                            _saveDraft();
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Conceptos y Servicios
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Servicios / Conceptos (${_items.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48)),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F2B48),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Agregar Servicio', style: TextStyle(fontSize: 12)),
                          onPressed: () => _addItemDialog(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_items.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.post_add_outlined, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              'Aún no has agregado ningún servicio a cotizar.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = _items[idx];
                          final qtyStr = item.quantity == item.quantity.roundToDouble()
                              ? item.quantity.toInt().toString()
                              : item.quantity.toString();

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            title: Text(item.concept, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(
                              '${item.description.isNotEmpty ? '${item.description}\n' : ''}$qtyStr ${item.unit} x ${currency.format(item.unitPrice)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currency.format(item.totalPrice),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E6091)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => _addItemDialog(existingItem: item, index: idx),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  onPressed: () {
                                    setState(() => _items.removeAt(idx));
                                    _saveDraft();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Resumen de Totales e IVA
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:', style: TextStyle(fontSize: 15, color: Colors.black87)),
                        Text(currency.format(_subtotal), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('Desglosar I.V.A. (16%):', style: TextStyle(fontSize: 14, color: Colors.black87)),
                            const SizedBox(width: 8),
                            Switch.adaptive(
                              value: _applyIva,
                              activeColor: const Color(0xFF0F2B48),
                              onChanged: (val) {
                                setState(() => _applyIva = val);
                                _saveDraft();
                              },
                            ),
                          ],
                        ),
                        if (_applyIva)
                          Text(currency.format(_iva), style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
                        Text(
                          '${currency.format(_total)} MXN',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E6091)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Términos y Condiciones
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Términos y Condiciones',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48)),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.restart_alt, size: 16),
                          label: const Text('Restaurar', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _termsController.text = QuoteModel.defaultTermsAndConditions(_validDays);
                            });
                            _saveDraft();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'La cláusula #1 se actualiza automáticamente según la vigencia seleccionada ($_validDays días).',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _termsController,
                      maxLines: 9,
                      style: const TextStyle(fontSize: 12.5, height: 1.35),
                      decoration: const InputDecoration(
                        hintText: 'Términos y condiciones de la cotización...',
                      ),
                      onChanged: (_) => _saveDraft(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notas adicionales (Opcional)'),
                      onChanged: (_) => _saveDraft(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _repController,
                      decoration: const InputDecoration(labelText: 'Elaborado por (Asesor / Técnico)'),
                      onChanged: (_) => _saveDraft(),
                    ),
                    const SizedBox(height: 14),
                    // Firma Digital Vinculada con Reportes
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2B48).withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.draw_outlined, size: 20, color: Color(0xFF0F2B48)),
                                  SizedBox(width: 8),
                                  Text(
                                    'Firma en la Cotización',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F2B48)),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _includeSignature,
                                activeColor: const Color(0xFF0F2B48),
                                onChanged: (val) {
                                  setState(() => _includeSignature = val);
                                  _saveDraft();
                                },
                              ),
                            ],
                          ),
                          if (_includeSignature) ...[
                            const SizedBox(height: 6),
                            if (_signatureBytes != null) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.verified, size: 14, color: Colors.green.shade700),
                                        const SizedBox(width: 5),
                                        Text(
                                          _hasSavedReportSignature
                                              ? 'Firma fija registrada en Reportes'
                                              : 'Firma asignada',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.edit, size: 14),
                                    label: const Text('Cambiar', style: TextStyle(fontSize: 12)),
                                    onPressed: _openFullScreenSignature,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 75,
                                width: double.infinity,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Image.memory(_signatureBytes!, fit: BoxFit.contain),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Aún no hay firma registrada fija en Reportes.',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Puedes firmar ahora aquí o registrarla fija en Reportes y se aplicará automáticamente a todas tus cotizaciones.',
                                      style: TextStyle(fontSize: 11.5, color: Colors.brown),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0F2B48),
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('Firmar ahora', style: TextStyle(fontSize: 12)),
                                      onPressed: _openFullScreenSignature,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botón Generar PDF
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2B48),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 24),
                label: const Text('GENERAR Y PREVISUALIZAR COTIZACIÓN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                onPressed: _generateAndPreviewQuote,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
