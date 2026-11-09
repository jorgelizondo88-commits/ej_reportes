import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/client_model.dart';
import '../../models/trap_monitoring_model.dart';
import '../../services/client_service.dart';

class GeneralInfoData {
  String reportFolio;
  DateTime serviceDate;
  TimeOfDay serviceTimeStart;
  TimeOfDay serviceTimeEnd;
  String technicianName;
  String clientName;
  String businessName;
  String clientAddress;
  String clientPhone;
  String clientEmail;
  String facilityType;
  bool hasTraps;
  List<String> targetedPests;
  String inspectionFindings;
  String recommendations;
  String warranties;
  String? activeClientId;

  GeneralInfoData({
    required this.reportFolio,
    required this.serviceDate,
    required this.serviceTimeStart,
    required this.serviceTimeEnd,
    required this.technicianName,
    required this.clientName,
    required this.businessName,
    required this.clientAddress,
    required this.clientPhone,
    required this.clientEmail,
    required this.facilityType,
    required this.hasTraps,
    required this.targetedPests,
    required this.inspectionFindings,
    required this.recommendations,
    this.warranties = '',
    this.activeClientId,
  });
}

class GeneralInfoStep extends StatefulWidget {
  final GeneralInfoData data;
  final ValueChanged<GeneralInfoData> onChanged;
  final Function(List<TrapMonitoring>) onTrapsPreloaded;

  const GeneralInfoStep({
    super.key,
    required this.data,
    required this.onChanged,
    required this.onTrapsPreloaded,
  });

  @override
  State<GeneralInfoStep> createState() => _GeneralInfoStepState();
}

class _GeneralInfoStepState extends State<GeneralInfoStep> {
  final ClientService _clientService = ClientService();
  List<ClientModel> _savedClients = [];
  List<ClientTrapTemplate> _currentClientTraps = [];
  bool _isSavingClient = false;

  late TextEditingController _folioController;
  late TextEditingController _techController;
  late TextEditingController _clientController;
  late TextEditingController _businessController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _findingsController;
  late TextEditingController _recController;

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
  }

  void _initControllers() {
    _folioController = TextEditingController(text: widget.data.reportFolio);
    _techController = TextEditingController(text: widget.data.technicianName);
    _clientController = TextEditingController(text: widget.data.clientName);
    _businessController = TextEditingController(text: widget.data.businessName);
    _addressController = TextEditingController(text: widget.data.clientAddress);
    _phoneController = TextEditingController(text: widget.data.clientPhone);
    _emailController = TextEditingController(text: widget.data.clientEmail);
    _findingsController = TextEditingController(text: widget.data.inspectionFindings);
    _recController = TextEditingController(text: widget.data.recommendations);
  }

  @override
  void didUpdateWidget(covariant GeneralInfoStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _folioController.text = widget.data.reportFolio;
      _techController.text = widget.data.technicianName;
      _clientController.text = widget.data.clientName;
      _businessController.text = widget.data.businessName;
      _addressController.text = widget.data.clientAddress;
      _phoneController.text = widget.data.clientPhone;
      _emailController.text = widget.data.clientEmail;
      _findingsController.text = widget.data.inspectionFindings;
      _recController.text = widget.data.recommendations;

      if (widget.data.activeClientId == null) {
        _currentClientTraps = [];
      }
    }
  }

  @override
  void dispose() {
    _folioController.dispose();
    _techController.dispose();
    _clientController.dispose();
    _businessController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _findingsController.dispose();
    _recController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final list = await _clientService.getSavedClients();
    setState(() => _savedClients = list);
  }

  void _applySelectedClient(ClientModel client) {
    setState(() {
      widget.data.activeClientId = client.id;
      widget.data.businessName = client.businessName;
      widget.data.clientName = client.contactName;
      widget.data.clientAddress = client.address;
      widget.data.clientPhone = client.phone;
      widget.data.clientEmail = client.email;
      widget.data.facilityType = client.facilityType;
      widget.data.hasTraps = client.hasTraps;
      _currentClientTraps = List.from(client.defaultTraps);

      _businessController.text = client.businessName;
      _clientController.text = client.contactName;
      _addressController.text = client.address;
      _phoneController.text = client.phone;
      _emailController.text = client.email;
    });

    widget.onChanged(widget.data);

    if (client.hasTraps && client.defaultTraps.isNotEmpty) {
      final freshServiceTraps = client.defaultTraps.map((t) {
        return TrapMonitoring(
          id: t.id,
          location: t.location,
          trapType: t.trapType,
          consumptionPercentage: 0,
          status: 'Sin actividad',
          captureCount: 0,
          observations: '',
        );
      }).toList();

      widget.onTrapsPreloaded(freshServiceTraps);
    } else {
      widget.onTrapsPreloaded([]);
    }
  }

  void _showQuickTrapSetupDialog() {
    int baitCount = _currentClientTraps.where((t) => t.trapType.contains('cebado')).length;
    int mechanicalCount = _currentClientTraps.where((t) => !t.trapType.contains('cebado')).length;

    final baitController = TextEditingController(text: baitCount > 0 ? baitCount.toString() : '3');
    final mechController = TextEditingController(text: mechanicalCount > 0 ? mechanicalCount.toString() : '5');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Configurar Trampas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Indica la cantidad de trampas fijas del cliente. Se crearán automáticamente en cada servicio.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: baitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estaciones de Cebado (Roedor)',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mechController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Trampas Mecánicas / Goma',
                  prefixIcon: Icon(Icons.pest_control_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2B48),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final int b = int.tryParse(baitController.text.trim()) ?? 0;
                final int m = int.tryParse(mechController.text.trim()) ?? 0;

                List<ClientTrapTemplate> generated = [];
                for (int i = 1; i <= b; i++) {
                  generated.add(ClientTrapTemplate(
                    id: 'C-${i.toString().padLeft(2, '0')}',
                    trapType: 'Estación de cebado (Roedor)',
                    location: 'Perímetro exterior',
                  ));
                }
                for (int i = 1; i <= m; i++) {
                  generated.add(ClientTrapTemplate(
                    id: 'TM-${i.toString().padLeft(2, '0')}',
                    trapType: 'Trampa mecánica / Goma',
                    location: 'Área interior',
                  ));
                }

                setState(() {
                  _currentClientTraps = generated;
                  widget.data.hasTraps = generated.isNotEmpty;
                });

                final freshList = generated.map((t) => TrapMonitoring(
                  id: t.id,
                  location: t.location,
                  trapType: t.trapType,
                  consumptionPercentage: 0,
                  status: 'Sin actividad',
                  captureCount: 0,
                )).toList();

                widget.onTrapsPreloaded(freshList);
                widget.onChanged(widget.data);
                Navigator.pop(context);
              },
              child: const Text('Aplicar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveCurrentClient() async {
    if (_isSavingClient) return;

    if (_businessController.text.trim().isEmpty && _clientController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa al menos la empresa o el nombre del cliente.')),
      );
      return;
    }

    setState(() => _isSavingClient = true);

    bool cloudOk = false;
    try {
      final newClient = ClientModel(
        id: widget.data.activeClientId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        businessName: _businessController.text.trim(),
        contactName: _clientController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        facilityType: widget.data.facilityType,
        hasTraps: widget.data.hasTraps,
        defaultTraps: _currentClientTraps,
      );

      cloudOk = await _clientService.saveClient(newClient);
      widget.data.activeClientId = newClient.id;
      await _loadClients();
    } finally {
      if (mounted) {
        setState(() => _isSavingClient = false);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cloudOk
                ? '¡Cliente guardado (${_currentClientTraps.length} trampas) y Copia Maestra actualizada en Drive!'
                : '¡Cliente guardado localmente con ${_currentClientTraps.length} trampas! (Sin conexión a Drive)',
          ),
          backgroundColor: cloudOk ? Colors.green.shade800 : Colors.orange.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.data.serviceDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => widget.data.serviceDate = picked);
      widget.onChanged(widget.data);
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? widget.data.serviceTimeStart : widget.data.serviceTimeEnd,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          widget.data.serviceTimeStart = picked;
        } else {
          widget.data.serviceTimeEnd = picked;
        }
      });
      widget.onChanged(widget.data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_savedClients.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Color(0xFF0F2B48)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ClientModel>(
                        hint: const Text('Cargar cliente frecuente...', style: TextStyle(fontWeight: FontWeight.w600)),
                        isExpanded: true,
                        items: _savedClients.map((c) {
                          final label = c.businessName.isNotEmpty ? c.businessName : c.contactName;
                          final info = c.hasTraps ? '(${c.defaultTraps.length} trampas)' : '(Sin trampas)';
                          return DropdownMenuItem(value: c, child: Text('$label $info'));
                        }).toList(),
                        onChanged: (client) {
                          if (client != null) _applySelectedClient(client);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Folio y Horarios
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Folio y Horarios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Campo de folio sin icono que estorbe y con espacio completo
                      Expanded(
                        flex: 11,
                        child: TextField(
                          controller: _folioController,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'Folio',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          onChanged: (val) {
                            widget.data.reportFolio = val;
                            widget.onChanged(widget.data);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 9,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          ),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            dateFormat.format(widget.data.serviceDate),
                            style: const TextStyle(fontSize: 13),
                          ),
                          onPressed: _selectDate,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          icon: const Icon(Icons.access_time, size: 18),
                          label: Text('Inicio: ${widget.data.serviceTimeStart.format(context)}'),
                          onPressed: () => _selectTime(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          icon: const Icon(Icons.access_time_filled, size: 18),
                          label: Text('Fin: ${widget.data.serviceTimeEnd.format(context)}'),
                          onPressed: () => _selectTime(false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Información del Cliente
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Datos del Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F2B48)),
                        icon: _isSavingClient
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save, size: 16),
                        label: Text(_isSavingClient ? 'Guardando...' : 'Guardar'),
                        onPressed: _isSavingClient ? null : _saveCurrentClient,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _businessController,
                    decoration: const InputDecoration(
                      labelText: 'Empresa / Razón Social',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    onChanged: (val) {
                      widget.data.businessName = val;
                      widget.onChanged(widget.data);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clientController,
                    decoration: const InputDecoration(
                      labelText: 'Encargado / Contacto',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    onChanged: (val) {
                      widget.data.clientName = val;
                      widget.onChanged(widget.data);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Dirección completa',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    onChanged: (val) {
                      widget.data.clientAddress = val;
                      widget.onChanged(widget.data);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          onChanged: (val) {
                            widget.data.clientPhone = val;
                            widget.onChanged(widget.data);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo (Opcional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          onChanged: (val) {
                            widget.data.clientEmail = val;
                            widget.onChanged(widget.data);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // BLOQUE DE TRAMPAS ADAPTADO PARA EVITAR DESBORDES
                  Material(
                    color: widget.data.hasTraps ? Colors.teal.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.data.hasTraps ? Colors.teal.shade300 : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              '¿Maneja Estaciones o Trampas?',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              widget.data.hasTraps
                                  ? 'Activo: ${_currentClientTraps.length} trampas en inventario.'
                                  : 'Inactivo: No maneja roedores (se oculta del PDF).',
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: widget.data.hasTraps,
                            activeColor: const Color(0xFF0F2B48),
                            onChanged: (val) {
                              setState(() => widget.data.hasTraps = val);
                              widget.onChanged(widget.data);
                            },
                          ),
                          if (widget.data.hasTraps) ...[
                            const Divider(height: 14),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Text(
                                  '${_currentClientTraps.length} trampas registradas',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  icon: const Icon(Icons.tune, size: 16),
                                  label: const Text('Configurar Cantidades'),
                                  onPressed: _showQuickTrapSetupDialog,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Diagnóstico y Plagas
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Diagnóstico y Plagas Objetivo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _availablePests.map((pest) {
                      final isSelected = widget.data.targetedPests.contains(pest);
                      return FilterChip(
                        label: Text(pest),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              widget.data.targetedPests.add(pest);
                            } else {
                              widget.data.targetedPests.remove(pest);
                            }
                          });
                          widget.onChanged(widget.data);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _findingsController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Hallazgos de la inspección inicial', border: OutlineInputBorder()),
                    onChanged: (val) {
                      widget.data.inspectionFindings = val;
                      widget.onChanged(widget.data);
                    },
                  ),
                  const SizedBox(height: 12),
                   TextField(
                    controller: _recController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Recomendaciones de exclusión e higiene', border: OutlineInputBorder()),
                    onChanged: (val) {
                      widget.data.recommendations = val;
                      widget.onChanged(widget.data);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}