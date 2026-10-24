import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';
import '../../models/contract_model.dart';
import '../../services/client_service.dart';
import '../../services/image_service.dart';
import 'contract_preview_screen.dart';

class ContractFormScreen extends StatefulWidget {
  const ContractFormScreen({super.key});

  @override
  State<ContractFormScreen> createState() => _ContractFormScreenState();
}

class _ContractFormScreenState extends State<ContractFormScreen> {
  static const String _contractsHistoryKey = 'ej_contracts_history_list';
  static const String _prefTechSignKey = 'ej_saved_tech_sign';

  final _formKey = GlobalKey<FormState>();
  final ImageService _imageService = ImageService();
  final ImagePicker _picker = ImagePicker();

  // Controladores - Datos del Cliente
  final _folioController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _rfcController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Controladores - Representante Legal
  final _repNameController = TextEditingController();
  final _repRoleController = TextEditingController(text: 'Representante Legal');
  final _repPhoneController = TextEditingController();
  String? _ineFrontPath;
  String? _ineBackPath;

  // Condiciones de la Póliza
  String _serviceType = 'Póliza Comercial / Industrial';
  int _durationMonths = 12;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 365));
  String _visitFrequency = 'Mensual (1 visita/mes)';
  final _totalVisitsController = TextEditingController(text: '12');
  final _coveredAreasController = TextEditingController(text: 'Comedores, oficinas, almacén de producto, cuartos de máquinas y perímetro exterior');

  // Plagas a controlar
  final List<String> _availablePests = [
    'Cucarachas',
    'Roedores (Ratas y Ratones)',
    'Alacranes',
    'Moscas y Mosquitos',
    'Arañas',
    'Ciempiés',
    'Hormigas',
    'Termitas',
    'Chinches de Cama',
    'Pulgas y Garrapatas',
    'Gorgojos de Granos',
  ];
  final Set<String> _selectedPests = {
    'Cucarachas',
    'Roedores (Ratas y Ratones)',
    'Alacranes',
    'Arañas',
  };

  // Condiciones Financieras
  final _costPerVisitController = TextEditingController(text: '1200');
  final _monthlyCostController = TextEditingController(text: '1200');
  final _totalContractCostController = TextEditingController(text: '14400');
  String _paymentMethod = 'Transferencia Electrónica';
  final _paymentTermsController = TextEditingController(text: 'Pago los primeros 5 días hábiles de cada mes facturado');
  final _specialClausesController = TextEditingController();

  // Firmas en Pantalla
  Uint8List? _clientSignatureBytes;
  Uint8List? _contractorSignatureBytes;

  @override
  void initState() {
    super.initState();
    _generateNextFolio();
    _loadSavedContractorSignature();
    _recalculateEndDateAndVisits();
  }

  @override
  void dispose() {
    _folioController.dispose();
    _clientNameController.dispose();
    _businessNameController.dispose();
    _rfcController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _repNameController.dispose();
    _repRoleController.dispose();
    _repPhoneController.dispose();
    _totalVisitsController.dispose();
    _coveredAreasController.dispose();
    _costPerVisitController.dispose();
    _monthlyCostController.dispose();
    _totalContractCostController.dispose();
    _paymentTermsController.dispose();
    _specialClausesController.dispose();
    super.dispose();
  }

  Future<void> _generateNextFolio() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_contractsHistoryKey);
    int count = 1;

    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonString);
        count = list.length + 1;
      } catch (_) {}
    }

    final year = DateTime.now().year;
    final folio = 'EJ-POL-$year-${count.toString().padLeft(4, '0')}';
    setState(() {
      _folioController.text = folio;
    });
  }

  Future<void> _loadSavedContractorSignature() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSignBase64 = prefs.getString(_prefTechSignKey);
    if (savedSignBase64 != null && savedSignBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(savedSignBase64);
        setState(() {
          _contractorSignatureBytes = bytes;
        });
      } catch (_) {}
    }
  }

  void _recalculateEndDateAndVisits() {
    final newEnd = DateTime(_startDate.year, _startDate.month + _durationMonths, _startDate.day);
    int multiplier = 1;
    if (_visitFrequency.startsWith('Semanal')) {
      multiplier = 4;
    } else if (_visitFrequency.startsWith('Quincenal')) {
      multiplier = 2;
    } else if (_visitFrequency.startsWith('Mensual')) {
      multiplier = 1;
    } else if (_visitFrequency.startsWith('Bimestral')) {
      multiplier = (_durationMonths / 2).ceil();
    }

    final visits = _durationMonths * multiplier;
    final costVisit = double.tryParse(_costPerVisitController.text.trim()) ?? 0.0;
    final monthly = costVisit * multiplier;
    final total = monthly * _durationMonths;

    setState(() {
      _endDate = newEnd;
      _totalVisitsController.text = '$visits';
      _monthlyCostController.text = monthly.toStringAsFixed(2);
      _totalContractCostController.text = total.toStringAsFixed(2);
    });
  }

  Future<void> _selectClientFromDirectory() async {
    final clientService = ClientService();
    final clients = await clientService.getSavedClients();

    if (!mounted) return;

    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay clientes guardados en el directorio.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = clients.where((c) {
              final q = query.toLowerCase();
              return q.isEmpty ||
                  c.businessName.toLowerCase().contains(q) ||
                  c.contactName.toLowerCase().contains(q) ||
                  c.phone.contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Seleccionar Cliente',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F2B48)),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por empresa o contacto...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) => setModalState(() => query = val),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final c = filtered[idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF0F2B48).withOpacity(0.1),
                            child: const Icon(Icons.business, color: Color(0xFF0F2B48)),
                          ),
                          title: Text(
                            c.businessName.isNotEmpty ? c.businessName : c.contactName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '${c.contactName} • ${c.phone}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          onTap: () {
                            setState(() {
                              _clientNameController.text = c.contactName;
                              _businessNameController.text = c.businessName;
                              _addressController.text = c.address;
                              _phoneController.text = c.phone;
                              _emailController.text = c.email;
                              if (_repNameController.text.isEmpty) {
                                _repNameController.text = c.contactName;
                              }
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _captureInePhoto({required bool isFront}) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF0F2B48)),
              title: const Text('Tomar Foto con la Cámara'),
              onTap: () async {
                Navigator.pop(context);
                final file = await _imageService.capturePhoto();
                if (file != null) {
                  setState(() {
                    if (isFront) {
                      _ineFrontPath = file.path;
                    } else {
                      _ineBackPath = file.path;
                    }
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF0F2B48)),
              title: const Text('Seleccionar de la Galería'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  final compressed = await _imageService.compressImage(File(picked.path));
                  if (compressed != null) {
                    setState(() {
                      if (isFront) {
                        _ineFrontPath = compressed.path;
                      } else {
                        _ineBackPath = compressed.path;
                      }
                    });
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSignatureDialog({
    required String title,
    required Uint8List? initialSignature,
    required Function(Uint8List?) onSaved,
  }) async {
    final controller = SignatureController(
      penStrokeWidth: 4,
      penColor: const Color(0xFF0F2B48),
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
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              backgroundColor: const Color(0xFF0F2B48),
              foregroundColor: Colors.white,
              actions: [
                TextButton(
                  onPressed: () => controller.clear(),
                  child: const Text('Limpiar', style: TextStyle(color: Colors.white)),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black87),
                  onPressed: () async {
                    if (controller.isNotEmpty) {
                      final bytes = await controller.toPngBytes();
                      if (context.mounted) Navigator.pop(context, bytes);
                    } else {
                      if (context.mounted) Navigator.pop(context, initialSignature);
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
            body: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.amber.shade50,
                  child: const Row(
                    children: [
                      Icon(Icons.edit, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Firme en pantalla usando su dedo o el S-Pen. El trazo se guardará en alta resolución en el contrato.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Signature(
                    controller: controller,
                    backgroundColor: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.center,
                  child: const Text(
                    'Espacio para firma autógrafa digital',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (result != null) {
      onSaved(result);
    }
  }

  void _onGenerateContract() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa los campos requeridos con asterisco (*).')),
      );
      return;
    }

    if (_clientSignatureBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Es indispensable la firma en pantalla del cliente/representante con S-Pen.'),
        ),
      );
      return;
    }

    final contract = ContractModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      folio: _folioController.text.trim(),
      creationDate: DateTime.now(),
      clientName: _clientNameController.text.trim(),
      businessName: _businessNameController.text.trim().isNotEmpty ? _businessNameController.text.trim() : _clientNameController.text.trim(),
      rfc: _rfcController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      representativeName: _repNameController.text.trim().isNotEmpty ? _repNameController.text.trim() : _clientNameController.text.trim(),
      representativeRole: _repRoleController.text.trim(),
      representativePhone: _repPhoneController.text.trim(),
      ineFrontPath: _ineFrontPath,
      ineBackPath: _ineBackPath,
      serviceType: _serviceType,
      durationMonths: _durationMonths,
      startDate: _startDate,
      endDate: _endDate,
      visitFrequency: _visitFrequency,
      totalVisits: int.tryParse(_totalVisitsController.text.trim()) ?? 12,
      targetPests: _selectedPests.toList(),
      coveredAreas: _coveredAreasController.text.trim(),
      costPerVisit: double.tryParse(_costPerVisitController.text.trim()) ?? 0.0,
      monthlyCost: double.tryParse(_monthlyCostController.text.trim()) ?? 0.0,
      totalContractCost: double.tryParse(_totalContractCostController.text.trim()) ?? 0.0,
      paymentMethod: _paymentMethod,
      paymentTerms: _paymentTermsController.text.trim(),
      specialClauses: _specialClausesController.text.trim(),
      jurisdiction: 'Monterrey, Nuevo León',
      clientSignatureBytes: _clientSignatureBytes,
      contractorSignatureBytes: _contractorSignatureBytes,
      signerFullName: _repNameController.text.trim().isNotEmpty ? _repNameController.text.trim() : _clientNameController.text.trim(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ContractPreviewScreen(contract: contract)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Póliza / Contrato', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'Directorio de Clientes',
            onPressed: _selectClientFromDirectory,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BANNER SUPERIOR INFORMATIVO
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F2B48), Color(0xFF1E6091)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.draw, color: Colors.amberAccent, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Contrato Legal Digital con Firma en Pantalla',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Válido según Código de Comercio (Art. 89-93). Incluye cotejo de INE y S-Pen.',
                            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // SECCIÓN 1: DATOS GENERALES DEL CLIENTE
              _sectionCard(
                title: '1. Datos del Cliente / Empresa',
                icon: Icons.business,
                action: TextButton.icon(
                  onPressed: _selectClientFromDirectory,
                  icon: const Icon(Icons.contact_phone, size: 16),
                  label: const Text('Directorio', style: TextStyle(fontSize: 12)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _folioController,
                            decoration: const InputDecoration(
                              labelText: 'Folio Contrato *',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _rfcController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'RFC (Empresa o Persona)',
                              hintText: 'XAXX010101000',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessNameController,
                      decoration: const InputDecoration(
                        labelText: 'Razón Social / Nombre Comercial *',
                        hintText: 'Ej. Alimentos del Norte S.A. de C.V.',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Ingresa la razón social o nombre' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _clientNameController,
                            decoration: const InputDecoration(
                              labelText: 'Contacto / Titular *',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono Principal *',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Domicilio de las Instalaciones / Inmueble *',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Ingresa la dirección' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico para Facturación / Notificaciones',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // SECCIÓN 2: CONDICIONES DE LA PÓLIZA
              _sectionCard(
                title: '2. Alcance y Plazos de la Póliza',
                icon: Icons.calendar_month,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipo de Póliza
                    DropdownButtonFormField<String>(
                      value: _serviceType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Servicio',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        'Póliza Comercial / Industrial',
                        'Póliza Residencial',
                        'Servicio de Mantenimiento Específico',
                      ].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _serviceType = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Duración en Meses (Chips)
                    const Text('Vigencia del Contrato:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [1, 3, 6, 12].map((m) {
                          final isSel = _durationMonths == m;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('$m ${m == 1 ? 'Mes' : 'Meses'}${m == 12 ? ' (Anual)' : ''}'),
                              selected: isSel,
                              selectedColor: const Color(0xFF0F2B48),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : const Color(0xFF0F2B48),
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setState(() => _durationMonths = m);
                                  _recalculateEndDateAndVisits();
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Fechas de Inicio y Fin
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setState(() => _startDate = picked);
                                _recalculateEndDateAndVisits();
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Fecha de Inicio',
                                isDense: true,
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.date_range, size: 20),
                              ),
                              child: Text(dateFormat.format(_startDate), style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Fecha de Término',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            child: Text(dateFormat.format(_endDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Frecuencia y Total de Visitas
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: _visitFrequency,
                            decoration: const InputDecoration(
                              labelText: 'Frecuencia de Visita',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              'Semanal (4 visitas/mes)',
                              'Quincenal (2 visitas/mes)',
                              'Mensual (1 visita/mes)',
                              'Bimestral (1 visita c/2 meses)',
                            ].map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12.5)))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _visitFrequency = val);
                                _recalculateEndDateAndVisits();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _totalVisitsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Total Visitas',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Plagas a controlar
                    const Text('Plagas Amparadas por la Póliza:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _availablePests.map((pest) {
                        final isSel = _selectedPests.contains(pest);
                        return FilterChip(
                          label: Text(pest, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : Colors.black87)),
                          selected: isSel,
                          selectedColor: const Color(0xFF1E6091),
                          checkmarkColor: Colors.white,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedPests.add(pest);
                              } else {
                                _selectedPests.remove(pest);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _coveredAreasController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Áreas e Instalaciones Comprendidas',
                        hintText: 'Ej. Comedores, oficinas, almacén de producto, cuartos de máquinas y perímetro exterior',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // SECCIÓN 3: CONDICIONES ECONÓMICAS
              _sectionCard(
                title: '3. Términos Económicos y Pago',
                icon: Icons.payments_outlined,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _costPerVisitController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Costo por Visita (\$)',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => _recalculateEndDateAndVisits(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _monthlyCostController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Costo Mensual (\$)',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _totalContractCostController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Valor Total Póliza (\$)',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _paymentMethod,
                            decoration: const InputDecoration(
                              labelText: 'Método de Pago',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              'Transferencia Electrónica',
                              'Efectivo',
                              'Tarjeta Bancaria',
                              'Cheque',
                            ].map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12.5)))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _paymentMethod = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _paymentTermsController,
                      decoration: const InputDecoration(
                        labelText: 'Esquema y Condiciones de Pago',
                        hintText: 'Ej. Pago los primeros 5 días hábiles de cada mes facturado',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _specialClausesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Acuerdos o Cláusulas Especiales (Opcional)',
                        hintText: 'Ej. Se incluyen 2 aplicaciones extraordinarias de nebulización sin costo en caso de contingencia.',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // SECCIÓN 4: REPRESENTANTE LEGAL Y CAPTURA DE INE
              _sectionCard(
                title: '4. Representante Legal y Cotejo de INE',
                icon: Icons.badge_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _repNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre Completo del Firmante *',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _repRoleController,
                            decoration: const InputDecoration(
                              labelText: 'Cargo / Puesto *',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _repPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono Móvil del Firmante',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Fotografía de Identificación Oficial (INE / IFE):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tome foto frontal y reverso para certificar la identidad legal del firmante.',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        // Frente de INE
                        Expanded(
                          child: _ineCaptureBox(
                            title: 'Frente del INE',
                            path: _ineFrontPath,
                            onTap: () => _captureInePhoto(isFront: true),
                            onDelete: () => setState(() => _ineFrontPath = null),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Reverso de INE
                        Expanded(
                          child: _ineCaptureBox(
                            title: 'Reverso del INE',
                            path: _ineBackPath,
                            onTap: () => _captureInePhoto(isFront: false),
                            onDelete: () => setState(() => _ineBackPath = null),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // SECCIÓN 5: FIRMAS DIGITALES EN PANTALLA (S-PEN)
              _sectionCard(
                title: '5. Firmas Digitales en Pantalla (S-Pen)',
                icon: Icons.draw_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Firma del Cliente / Representante Legal *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48)),
                    ),
                    const SizedBox(height: 6),
                    _signatureBox(
                      bytes: _clientSignatureBytes,
                      signerTitle: _repNameController.text.isNotEmpty ? _repNameController.text : 'Representante Legal',
                      hintText: 'Tocar para firmar en pantalla con el S-Pen',
                      onTap: () {
                        _openSignatureDialog(
                          title: 'Firma del Representante del Cliente',
                          initialSignature: _clientSignatureBytes,
                          onSaved: (bytes) => setState(() => _clientSignatureBytes = bytes),
                        );
                      },
                      onClear: () => setState(() => _clientSignatureBytes = null),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Firma de EJ Exterminadores (Prestador)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48)),
                    ),
                    const SizedBox(height: 6),
                    _signatureBox(
                      bytes: _contractorSignatureBytes,
                      signerTitle: 'Ing. Jorge Lizondo / Representante Técnico',
                      hintText: 'Tocar para firmar o usar firma registrada',
                      onTap: () {
                        _openSignatureDialog(
                          title: 'Firma de EJ Exterminadores',
                          initialSignature: _contractorSignatureBytes,
                          onSaved: (bytes) => setState(() => _contractorSignatureBytes = bytes),
                        );
                      },
                      onClear: () => setState(() => _contractorSignatureBytes = null),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // BOTÓN PRINCIPAL
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
                  icon: const Icon(Icons.picture_as_pdf, size: 22),
                  label: const Text(
                    'Generar Contrato Digital',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _onGenerateContract,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    Widget? action,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF0F2B48), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: 6),
                  action,
                ],
              ],
            ),
            const Divider(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _ineCaptureBox({
    required String title,
    required String? path,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    final hasPhoto = path != null && File(path).existsSync();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hasPhoto ? const Color(0xFF0F2B48) : Colors.grey.shade400, width: hasPhoto ? 1.5 : 1),
        ),
        child: hasPhoto
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.file(File(path), fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 14, color: Colors.white),
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      color: Colors.black54,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined, color: Color(0xFF0F2B48), size: 28),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                  ),
                  const SizedBox(height: 2),
                  const Text('Tocar para capturar', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
      ),
    );
  }

  Widget _signatureBox({
    required Uint8List? bytes,
    required String signerTitle,
    required String hintText,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final hasSign = bytes != null;

    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hasSign ? Colors.green.shade700 : Colors.grey.shade400, width: hasSign ? 1.5 : 1),
      ),
      child: hasSign
          ? Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 10,
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        signerTitle,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18, color: Color(0xFF0F2B48)),
                        tooltip: 'Volver a firmar',
                        onPressed: onTap,
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.redAccent),
                        tooltip: 'Borrar',
                        onPressed: onClear,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gesture, color: Color(0xFF0F2B48), size: 30),
                    const SizedBox(height: 6),
                    Text(
                      hintText,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48)),
                    ),
                    const SizedBox(height: 2),
                    const Text('Compatible con S-Pen y dedo', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ),
    );
  }
}
