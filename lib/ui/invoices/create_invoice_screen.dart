import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/cfdi_invoice_data.dart';
import '../../models/client_model.dart';
import '../../models/sat_catalogs.dart';
import '../../services/cfdi_stamping_service.dart';
import '../../services/client_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/invoice_storage_service.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final ClientModel? preselectedClient;

  const CreateInvoiceScreen({super.key, this.preselectedClient});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final ClientService _clientService = ClientService();
  final currencyFmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  List<ClientModel> _clients = [];
  ClientModel? _selectedClient;
  bool _isLoadingClients = true;
  bool _isStamping = false;

  String _series = 'AFAD';
  int _nextFolioNumber = 383;
  late TextEditingController _folioCtrl;

  List<CfdiInvoiceItem> _items = [];
  List<CfdiInvoiceItem> _recentConcepts = [];

  String _paymentForm = '03 - Transferencia electrónica de fondos';
  String _paymentMethod = 'PUE - Pago en una sola exhibición';
  bool _includeBankInfo = true;
  final TextEditingController _observationsCtrl = TextEditingController();

  final List<String> _paymentForms = [
    '01 - Efectivo',
    '02 - Cheque nominativo',
    '03 - Transferencia electrónica de fondos',
    '04 - Tarjeta de crédito',
    '28 - Tarjeta de débito',
    '99 - Por definir',
  ];

  final List<String> _paymentMethods = [
    'PUE - Pago en una sola exhibición',
    'PPD - Pago en parcialidades o diferido',
  ];

  @override
  void initState() {
    super.initState();
    _folioCtrl = TextEditingController(text: '$_nextFolioNumber');
    _loadInitialData();
  }

  @override
  void dispose() {
    _folioCtrl.dispose();
    _observationsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingClients = true);
    final clients = await _clientService.getSavedClients();
    final series = await InvoiceStorageService.getSeries();
    final folio = await InvoiceStorageService.getNextFolioNumber();
    final recent = await InvoiceStorageService.getRecentConcepts();

    ClientModel? initial;
    if (widget.preselectedClient != null) {
      initial = clients.firstWhere(
        (c) => c.id == widget.preselectedClient!.id,
        orElse: () => widget.preselectedClient!,
      );
    } else if (clients.isNotEmpty) {
      initial = clients.first;
    }

    setState(() {
      _clients = clients;
      _selectedClient = initial;
      _series = series;
      _nextFolioNumber = folio;
      _folioCtrl.text = '$folio';
      _recentConcepts = recent;
      _isLoadingClients = false;
    });

    if (initial != null) {
      await _checkAndLoadClientDefaults(initial);
    }
  }

  Future<void> _checkAndLoadClientDefaults(ClientModel client) async {
    if (_items.isNotEmpty) return;

    final lastInvoice = await InvoiceStorageService.getClientLastInvoice(client.id);
    if (lastInvoice != null && lastInvoice.items.isNotEmpty) {
      setState(() {
        _items = List.from(lastInvoice.items);
        _paymentForm = lastInvoice.paymentForm;
        _paymentMethod = lastInvoice.paymentMethod;
      });
    } else {
      setState(() {
        _items = [
          CfdiInvoiceItem(
            quantity: 1,
            description: 'Servicio de Control y Manejo Integrado de Plagas',
            satProductCode: '72102100',
            satProductDesc: 'Servicios de control y exterminación de plagas',
            satUnitCode: 'E48',
            satUnitDesc: 'Unidad de servicio',
            unitPrice: 1500.0,
          ),
        ];
      });
    }
  }

  Future<void> _loadLastInvoiceTemplate() async {
    if (_selectedClient == null) return;
    final last = await InvoiceStorageService.getClientLastInvoice(_selectedClient!.id);
    if (last == null || last.items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este cliente aún no tiene facturas previas registradas para duplicar.')),
        );
      }
      return;
    }

    setState(() {
      _items = List.from(last.items);
      _paymentForm = last.paymentForm;
      _paymentMethod = last.paymentMethod;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Se cargaron los conceptos del mes anterior! Puedes editarlos libremente.'),
          backgroundColor: Color(0xFF1E6091),
        ),
      );
    }
  }

  double get _subtotal {
    double sum = 0.0;
    for (final it in _items) {
      sum += it.subtotal;
    }
    return double.parse(sum.toStringAsFixed(2));
  }

  double get _iva {
    double sum = 0.0;
    for (final it in _items) {
      sum += it.taxAmount;
    }
    return double.parse(sum.toStringAsFixed(2));
  }

  double get _total => double.parse((_subtotal + _iva).toStringAsFixed(2));

  // --- SELECTOR / CREACIÓN RÁPIDA DE CLIENTE ---
  void _openClientPickerModal() {
    final searchCtrl = TextEditingController();
    List<ClientModel> filtered = List.from(_clients);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Seleccionar Cliente', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre, comercial o RFC...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                        onChanged: (q) {
                          setModalState(() {
                            final query = q.trim().toLowerCase();
                            filtered = _clients.where((c) {
                              return c.businessName.toLowerCase().contains(query) ||
                                  c.contactName.toLowerCase().contains(query) ||
                                  c.taxRfc.toLowerCase().contains(query) ||
                                  c.taxBusinessName.toLowerCase().contains(query);
                            }).toList();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F2B48),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Nuevo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openQuickCreateClientDialog();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              const Text('No se encontraron clientes.', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2B48), foregroundColor: Colors.white),
                                icon: const Icon(Icons.add),
                                label: const Text('Crear Cliente Ahora'),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _openQuickCreateClientDialog();
                                },
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final c = filtered[i];
                            final title = c.businessName.isNotEmpty ? c.businessName : c.contactName;
                            final isSel = _selectedClient?.id == c.id;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: isSel ? const Color(0xFF1E6091) : Colors.grey.shade200,
                                foregroundColor: isSel ? Colors.white : const Color(0xFF0F2B48),
                                child: const Icon(Icons.business, size: 20),
                              ),
                              title: Text(title, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.w600, fontSize: 13.5)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (c.hasFiscalData)
                                    Text('RFC: ${c.taxRfc}  •  ${c.taxBusinessName}', style: const TextStyle(fontSize: 11, color: Color(0xFF1E6091), fontWeight: FontWeight.bold))
                                  else if (c.contactName.isNotEmpty && c.contactName != title)
                                    Text('Contacto: ${c.contactName}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                  if (c.address.isNotEmpty)
                                    Text(c.address, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                              trailing: isSel ? const Icon(Icons.check_circle, color: Color(0xFF1E6091)) : null,
                              onTap: () {
                                setState(() => _selectedClient = c);
                                _checkAndLoadClientDefaults(c);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openQuickCreateClientDialog() {
    final businessCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final taxRfcCtrl = TextEditingController();
    final taxBusinessCtrl = TextEditingController();
    final taxAddressCtrl = TextEditingController();
    final taxZipCtrl = TextEditingController();
    String taxRegime = '601 - General de Ley Personas Morales';
    String taxCfdiUse = 'G03 - Gastos en general';

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Color(0xFF0F2B48)),
              SizedBox(width: 8),
              Text('Registrar Nuevo Cliente', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2B48), fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. Datos Operativos (Sucursal / Servicio)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F2B48))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: businessCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre Comercial / Sucursal *', hintText: 'Ej. Confianza Médica', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: contactCtrl,
                          decoration: const InputDecoration(labelText: 'Persona de Contacto', hintText: 'Ej. Dra. Patricia', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Teléfono', hintText: 'Ej. 818-123-4567', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: addressCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Dirección de la Sucursal / Inmueble (Servicio)',
                      hintText: 'Ej. Av. Vasconcelos 100, Col. Del Valle, San Pedro Garza García, N.L.',
                      isDense: true,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const Divider(height: 24),
                  const Text('2. Datos Fiscales Oficiales (SAT CFDI 4.0)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E6091))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: taxBusinessCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Razón Social Oficial *', hintText: 'Ej. CORPORATIVO EQUIPO MEDICO 360', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: taxRfcCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'RFC del Cliente *', hintText: 'CEM140703EM8', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: taxZipCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 5,
                          decoration: const InputDecoration(labelText: 'C.P. Fiscal *', hintText: '64380', counterText: '', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: taxAddressCtrl,
                    minLines: 2,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Domicilio Fiscal Completo para Factura *',
                      hintText: 'Calle, número exterior/interior, colonia, municipio, estado',
                      isDense: true,
                      alignLabelWithHint: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copiar dirección de sucursal',
                        onPressed: () {
                          if (addressCtrl.text.isNotEmpty) {
                            taxAddressCtrl.text = addressCtrl.text.toUpperCase();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: taxRegime,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Régimen Fiscal (SAT)', isDense: true),
                    items: const [
                      DropdownMenuItem(value: '601 - General de Ley Personas Morales', child: Text('601 - General de Ley Personas Morales', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: '612 - Personas Físicas con Actividades Empresariales y Profesionales', child: Text('612 - PFAE', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: '626 - Régimen Simplificado de Confianza (RESICO)', child: Text('626 - RESICO', style: TextStyle(fontSize: 11))),
                    ],
                    onChanged: (v) => setDlgState(() => taxRegime = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2B48), foregroundColor: Colors.white),
              onPressed: () async {
                final bName = businessCtrl.text.trim();
                final cName = contactCtrl.text.trim();
                if (bName.isEmpty && cName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingresa el nombre del cliente.')),
                  );
                  return;
                }

                final finalTaxAddress = taxAddressCtrl.text.trim().isNotEmpty
                    ? taxAddressCtrl.text.trim().toUpperCase()
                    : addressCtrl.text.trim().toUpperCase();

                final newClient = ClientModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  businessName: bName,
                  contactName: cName,
                  phone: phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  email: '',
                  facilityType: 'Comercial / Restaurante',
                  hasTraps: false,
                  taxRfc: taxRfcCtrl.text.trim().toUpperCase(),
                  taxBusinessName: taxBusinessCtrl.text.trim().isNotEmpty
                      ? taxBusinessCtrl.text.trim().toUpperCase()
                      : (bName.isNotEmpty ? bName.toUpperCase() : cName.toUpperCase()),
                  taxAddress: finalTaxAddress,
                  taxZipCode: taxZipCtrl.text.trim(),
                  taxRegime: taxRegime,
                  taxCfdiUse: taxCfdiUse,
                );

                await _clientService.saveClient(newClient);
                final updatedList = await _clientService.getSavedClients();

                setState(() {
                  _clients = updatedList;
                  _selectedClient = newClient;
                });
                _checkAndLoadClientDefaults(newClient);

                Navigator.pop(dlgCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('¡Cliente registrado y seleccionado para facturar!'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Guardar y Seleccionar'),
            ),
          ],
        ),
      ),
    );
  }

  // --- CATÁLOGO Y BUSCADOR DE PRODUCTOS/SERVICIOS SAT ---
  void _openSatProductSearchModal(Function(SatProductItem item) onSelected) {
    final searchCtrl = TextEditingController();
    String selectedCategory = 'Todos';
    List<SatProductItem> filtered = SatCatalogs.products;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final categories = ['Todos', 'Control de Plagas', 'Dispositivos y Trampas', 'Desinfección', 'Jardinería'];

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Catálogo de Claves SAT (Plagas y Servicios)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),

                // Buscador
                TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por clave o nombre (ej. 72102100, roedores, trampa...)',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                  onChanged: (q) {
                    setModalState(() {
                      var list = SatCatalogs.searchProducts(q);
                      if (selectedCategory != 'Todos') {
                        list = list.where((p) => p.category == selectedCategory).toList();
                      }
                      filtered = list;
                    });
                  },
                ),
                const SizedBox(height: 10),

                // Filtros de categoría
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((cat) {
                      final isSel = selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(cat, style: TextStyle(fontSize: 11.5, color: isSel ? Colors.white : Colors.black87, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                          selected: isSel,
                          selectedColor: const Color(0xFF0F2B48),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                selectedCategory = cat;
                                var list = SatCatalogs.searchProducts(searchCtrl.text);
                                if (cat != 'Todos') {
                                  list = list.where((p) => p.category == cat).toList();
                                }
                                filtered = list;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),

                // Lista de productos
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No se encontraron claves SAT para esa búsqueda.', style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final p = filtered[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E6091).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF1E6091), width: 0.8),
                                ),
                                child: Text(p.code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E6091))),
                              ),
                              title: Text(p.description, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              subtitle: Text(p.category, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                              onTap: () {
                                onSelected(p);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- DIÁLOGO DE CONCEPTO / PARTIDA ---
  void _openItemDialog({CfdiInvoiceItem? existingItem, int? index}) {
    final descCtrl = TextEditingController(text: existingItem?.description ?? '');
    final satProdCtrl = TextEditingController(text: existingItem?.satProductCode ?? '72102100');
    final satProdDescCtrl = TextEditingController(text: existingItem?.satProductDesc ?? 'Servicios de control y exterminación de plagas');
    String satUnitCode = existingItem?.satUnitCode ?? 'E48';
    final qtyCtrl = TextEditingController(text: existingItem != null ? (existingItem.quantity % 1 == 0 ? existingItem.quantity.toInt().toString() : existingItem.quantity.toString()) : '1');
    final priceCtrl = TextEditingController(text: existingItem != null ? existingItem.unitPrice.toStringAsFixed(2) : '1500.00');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
          final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
          final lineSubtotal = qty * price;
          final lineIva = lineSubtotal * 0.16;
          final lineTotal = lineSubtotal + lineIva;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existingItem != null ? 'Editar Concepto' : 'Agregar Concepto / Partida',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Sugerencias rápidas de historial
                  if (_recentConcepts.isNotEmpty) ...[
                    const Text('Sugerencias de tu historial:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recentConcepts.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final r = _recentConcepts[i];
                          return ActionChip(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                            label: Text(r.description, style: const TextStyle(fontSize: 11.5)),
                            onPressed: () {
                              setModalState(() {
                                descCtrl.text = r.description;
                                satProdCtrl.text = r.satProductCode;
                                satProdDescCtrl.text = r.satProductDesc;
                                satUnitCode = r.satUnitCode;
                                priceCtrl.text = r.unitPrice.toStringAsFixed(2);
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Descripción libre
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descripción del Producto o Servicio *',
                      hintText: 'Ej. ESTACION DE CEBADO PARA ROEDORES o Fumigación Mensual',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cantidad y Precio
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Cantidad *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Precio Unitario (\$ MXN) *',
                            border: OutlineInputBorder(),
                            isDense: true,
                            prefixText: '\$ ',
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Clave SAT de Producto y Buscador
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            _openSatProductSearchModal((item) {
                              setModalState(() {
                                satProdCtrl.text = item.code;
                                satProdDescCtrl.text = item.description;
                                if (item.category == 'Dispositivos y Trampas') {
                                  satUnitCode = 'H87'; // Pieza automático para trampas
                                } else if (item.category == 'Control de Plagas') {
                                  satUnitCode = 'E48'; // Servicio automático para plagas
                                }
                              });
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.grey.shade50,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search, size: 18, color: Color(0xFF1E6091)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Clave SAT: ${satProdCtrl.text.isNotEmpty ? satProdCtrl.text : 'Seleccionar...'}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      Text(
                                        satProdDescCtrl.text.isNotEmpty ? satProdDescCtrl.text : 'Toca para buscar en catálogo SAT de plagas',
                                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Selector de Unidad de Medida SAT (Dropdown completo)
                  DropdownButtonFormField<String>(
                    value: SatCatalogs.units.any((u) => u.code == satUnitCode) ? satUnitCode : 'E48',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Unidad de Medida (SAT) *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: SatCatalogs.units.map((u) {
                      return DropdownMenuItem(
                        value: u.code,
                        child: Text(u.label, style: const TextStyle(fontSize: 12.5)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => satUnitCode = val);
                      }
                    },
                  ),

                  const SizedBox(height: 14),

                  // Desglose de la partida
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal: ${currencyFmt.format(lineSubtotal)}', style: const TextStyle(fontSize: 12)),
                        Text('IVA (16%): ${currencyFmt.format(lineIva)}', style: const TextStyle(fontSize: 12)),
                        Text(
                          'Total: ${currencyFmt.format(lineTotal)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F2B48),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(existingItem != null ? 'Actualizar Concepto' : 'Guardar Concepto'),
                      onPressed: () {
                        final desc = descCtrl.text.trim();
                        if (desc.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Ingresa una descripción para el concepto.')),
                          );
                          return;
                        }

                        final selectedUnit = SatCatalogs.units.firstWhere(
                          (u) => u.code == satUnitCode,
                          orElse: () => SatUnitItem(code: satUnitCode, name: 'Unidad'),
                        );

                        final newItem = CfdiInvoiceItem(
                          quantity: qty > 0 ? qty : 1.0,
                          description: desc,
                          satProductCode: satProdCtrl.text.trim().isNotEmpty ? satProdCtrl.text.trim() : '72102100',
                          satProductDesc: satProdDescCtrl.text.trim(),
                          satUnitCode: satUnitCode,
                          satUnitDesc: selectedUnit.name,
                          unitPrice: price,
                        );

                        setState(() {
                          if (index != null && index >= 0 && index < _items.length) {
                            _items[index] = newItem;
                          } else {
                            _items.add(newItem);
                          }
                        });

                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitAndStampInvoice() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona o registra un cliente para facturar.')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un concepto a la factura.')),
      );
      return;
    }

    final client = _selectedClient!;

    final rfc = client.taxRfc.trim().isNotEmpty ? client.taxRfc.trim() : 'XAXX010101000';
    final businessName = client.taxBusinessName.trim().isNotEmpty ? client.taxBusinessName.trim() : (client.businessName.isNotEmpty ? client.businessName : client.contactName);
    final zip = client.taxZipCode.trim().isNotEmpty ? client.taxZipCode.trim() : '64380';
    final regime = client.taxRegime.trim().isNotEmpty ? client.taxRegime : '601 - General de Ley Personas Morales';
    final cfdiUse = client.taxCfdiUse.trim().isNotEmpty ? client.taxCfdiUse : 'G03 - Gastos en general';

    setState(() => _isStamping = true);

    try {
      final invoiceData = CfdiInvoiceData(
        series: _series,
        folio: _folioCtrl.text.trim().isNotEmpty ? _folioCtrl.text.trim() : '$_nextFolioNumber',
        emissionDate: DateTime.now(),
        receiverBusinessName: businessName,
        receiverCommercialName: client.businessName,
        receiverRfc: rfc,
        receiverAddress: client.taxAddress.isNotEmpty ? client.taxAddress : client.address,
        receiverZip: zip,
        receiverRegime: regime,
        receiverCfdiUse: cfdiUse,
        items: _items,
        paymentForm: _paymentForm,
        paymentMethod: _paymentMethod,
        bankInstitution: _includeBankInfo ? 'HSBC' : '',
        bankAccount: _includeBankInfo ? '021580066278483086' : '',
        observations: _observationsCtrl.text.trim(),
      );

      final result = await CfdiStampingService.stampAndSaveInvoice(
        invoiceData: invoiceData,
        client: client,
        isSandbox: true,
      );

      if (!mounted) return;
      setState(() => _isStamping = false);

      _showSuccessDialog(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStamping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al timbrar factura: $e'), backgroundColor: Colors.red.shade800),
      );
    }
  }

  void _showSuccessDialog(StampedInvoiceResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('¡Factura Timbrada con Éxito!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Folio: ${result.invoice.fullFolio}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text('UUID: ${result.invoice.timbre?.uuid}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Cliente: ${result.invoice.receiverBusinessName}', style: const TextStyle(fontSize: 13)),
            Text('Total: ${currencyFmt.format(result.invoice.total)} MXN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F2B48))),
            const Divider(height: 20),
            Row(
              children: [
                Icon(
                  result.driveUploaded ? Icons.cloud_done : Icons.cloud_off,
                  color: result.driveUploaded ? Colors.green : Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.driveUploaded
                        ? 'PDF y XML subidos a Google Drive (5_Facturas/Pendientes_de_Pago)'
                        : 'Guardado en el dispositivo (sin sesión de Drive activa)',
                    style: TextStyle(fontSize: 11, color: result.driveUploaded ? Colors.green.shade800 : Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D), foregroundColor: Colors.white),
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Compartir PDF y XML'),
            onPressed: () async {
              try {
                await Share.shareXFiles(
                  [
                    XFile(result.localPdfFile.path, name: 'Factura_${result.invoice.fullFolio}.pdf'),
                    XFile(result.localXmlFile.path, name: 'Factura_${result.invoice.fullFolio}.xml'),
                  ],
                  text: 'Hola, te comparto la factura ${result.invoice.fullFolio} (PDF y XML) de EJ Exterminadores por un total de ${currencyFmt.format(result.invoice.total)} MXN.',
                  subject: 'Factura ${result.invoice.fullFolio} - EJ Exterminadores',
                );
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingClients) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0F2B48))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Factura (CFDI 4.0)', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          if (_selectedClient != null)
            TextButton.icon(
              icon: const Icon(Icons.history, color: Colors.amberAccent, size: 18),
              label: const Text('Mes Anterior', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
              onPressed: _loadLastInvoiceTemplate,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. DATOS DEL CLIENTE Y SERIE/FOLIO ---
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Color(0xFF0F2B48), size: 20),
                        const SizedBox(width: 8),
                        const Text('Receptor / Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F2B48))),
                        const Spacer(),
                        Text('Serie: $_series', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E6091))),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          height: 36,
                          child: TextField(
                            controller: _folioCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Folio', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Selector dinámico de cliente (funciona siempre)
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _openClientPickerModal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedClient != null ? Icons.business : Icons.person_add_outlined,
                              color: const Color(0xFF0F2B48),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedClient != null
                                        ? (_selectedClient!.businessName.isNotEmpty ? _selectedClient!.businessName : _selectedClient!.contactName)
                                        : 'Toca aquí para seleccionar o crear cliente *',
                                    style: TextStyle(
                                      fontWeight: _selectedClient != null ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13.5,
                                      color: _selectedClient != null ? Colors.black87 : Colors.blue.shade800,
                                    ),
                                  ),
                                  if (_selectedClient != null && _selectedClient!.hasFiscalData)
                                    Text('RFC: ${_selectedClient!.taxRfc}  •  ${_selectedClient!.taxBusinessName}', style: const TextStyle(fontSize: 11, color: Color(0xFF1E6091), fontWeight: FontWeight.bold))
                                  else if (_selectedClient == null)
                                    const Text('Toca para buscar o crear un cliente rápido', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),

                    if (_selectedClient != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _selectedClient!.hasFiscalData ? const Color(0xFF1E6091).withOpacity(0.08) : Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedClient!.hasFiscalData ? const Color(0xFF1E6091).withOpacity(0.3) : Colors.amber.shade700,
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedClient!.hasFiscalData) ...[
                              Text('Razón Social: ${_selectedClient!.taxBusinessName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('RFC: ${_selectedClient!.taxRfc}  •  C.P.: ${_selectedClient!.taxZipCode}', style: const TextStyle(fontSize: 11.5)),
                              Text('Régimen: ${_selectedClient!.taxRegime}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                              Text('Uso CFDI: ${_selectedClient!.taxCfdiUse}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                            ] else ...[
                              Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Este cliente no tiene RFC registrado. Se usará el genérico XAXX010101000 a menos que edites sus datos fiscales.',
                                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // --- 2. PARTIDAS / CONCEPTOS ---
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Conceptos a Facturar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F2B48))),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F2B48),
                            side: const BorderSide(color: Color(0xFF0F2B48)),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Agregar Concepto', style: TextStyle(fontSize: 12)),
                          onPressed: () => _openItemDialog(),
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: Text('No hay conceptos en la factura. Toca en "Agregar Concepto".', style: TextStyle(color: Colors.grey))),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 12),
                        itemBuilder: (ctx, idx) {
                          final it = _items[idx];
                          final qtyStr = it.quantity % 1 == 0 ? it.quantity.toInt().toString() : it.quantity.toString();

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(it.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text(
                              '$qtyStr ${it.satUnitDesc} x ${currencyFmt.format(it.unitPrice)} • SAT: ${it.satProductCode} (${it.satUnitCode})',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currencyFmt.format(it.total),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                                  onPressed: () => _openItemDialog(existingItem: it, index: idx),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  onPressed: () => setState(() => _items.removeAt(idx)),
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

            // --- 3. FORMAS DE PAGO Y CONDICIONES ---
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Condiciones de Pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F2B48))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _paymentForm,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Forma de Pago', border: OutlineInputBorder(), isDense: true),
                            items: _paymentForms.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() => _paymentForm = v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _paymentMethod,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Método de Pago', border: OutlineInputBorder(), isDense: true),
                            items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() => _paymentMethod = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Incluir datos de depósito HSBC en la factura', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Cuenta/CLABE: 021580066278483086 a nombre de Jorge Alberto Elizondo', style: TextStyle(fontSize: 11)),
                      value: _includeBankInfo,
                      activeColor: const Color(0xFF0F2B48),
                      onChanged: (v) => setState(() => _includeBankInfo = v),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _observationsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones / Notas (Opcional)',
                        hintText: 'Ej. Correspondiente al servicio quincenal de la segunda semana',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // --- 4. RESUMEN DE TOTALES Y BOTÓN DE TIMBRADO ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F2B48),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(currencyFmt.format(_subtotal), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('I.V.A. (16%):', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(currencyFmt.format(_iva), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(currencyFmt.format(_total), style: const TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E6091),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isStamping
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.verified, size: 20),
                      label: Text(
                        _isStamping ? 'Timbrando ante el SAT...' : 'Timbrar y Emitir Factura',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isStamping ? null : _submitAndStampInvoice,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
