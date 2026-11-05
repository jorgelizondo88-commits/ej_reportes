import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/client_model.dart';
import '../../models/schedule_model.dart';
import '../../services/client_service.dart';
import 'schedule_history_screen.dart';
import 'schedule_preview_screen.dart';

class ScheduleFormScreen extends StatefulWidget {
  final ClientModel? preselectedClient;

  const ScheduleFormScreen({super.key, this.preselectedClient});

  @override
  State<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  static const String _scheduleDraftKey = 'ej_active_schedule_draft';
  static const String _scheduleFolioCounterKey = 'ej_consecutive_schedule_counter';
  static const String _prefTechNameKey = 'ej_saved_tech_name';

  final ClientService _clientService = ClientService();
  List<ClientModel> _savedClients = [];
  ClientModel? _selectedClient;

  late TextEditingController _folioController;
  late TextEditingController _titleController;
  late TextEditingController _businessController;
  late TextEditingController _contactController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _serviceTypeController;
  late TextEditingController _conditionsController;
  late TextEditingController _notesController;
  late TextEditingController _repController;

  DateTime _startDate = DateTime.now();
  String _facilityType = 'Comercial / Restaurante';
  bool _saveNewClientToDb = true;

  // Recurrencia
  int _visitsPerMonth = 1; // 1 = Mensual, 2 = Quincenal / 2 visitas al mes
  String _recurrenceMode = 'relative'; // 'relative' o 'fixed_day'
  int _ordinalWeek = 1; // 1 = 1er, 2 = 2do, 3 = 3er, 4 = 4to, 5 = Último
  int _secondOrdinalWeek = 3; // 3 = 3er para 2da visita si es relative
  int _weekday = 7; // 1 = Lunes, ..., 7 = Domingo (Default: Domingo)
  int _fixedDay = 1; // 1..31
  int _secondFixedDay = 15; // Día 15 para 2da visita si es fixed_day
  int _durationMonths = 12; // 3, 5, 6, 12...
  TimeOfDay _defaultTime = const TimeOfDay(hour: 9, minute: 0);
  bool _addToAgenda = false; // Control de inclusión en Agenda

  final List<ScheduledVisit> _visits = [];

  final List<String> _facilityTypes = [
    'Comercial / Restaurante',
    'Industrial / Bodega',
    'Residencial / Casa',
    'Oficinas / Corporativo',
    'Hospitalario / Clínica',
  ];

  final Map<int, String> _ordinals = {
    1: '1er (Primer)',
    2: '2do (Segundo)',
    3: '3er (Tercer)',
    4: '4to (Cuarto)',
    5: 'Último',
  };

  final Map<int, String> _weekdays = {
    7: 'Domingo',
    1: 'Lunes',
    2: 'Martes',
    3: 'Miércoles',
    4: 'Jueves',
    5: 'Viernes',
    6: 'Sábado',
  };

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadClients();
    _loadTechName();

    if (widget.preselectedClient != null) {
      _applyClient(widget.preselectedClient!);
    } else {
      _initDraftOrNew();
    }
  }

  void _initControllers() {
    _folioController = TextEditingController(text: _formatFolio(1, DateTime.now()));
    _titleController = TextEditingController(text: 'Programa Periódico de Control de Plagas');
    _businessController = TextEditingController();
    _contactController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _serviceTypeController = TextEditingController(text: 'Servicio de Control de Plagas');
    _conditionsController = TextEditingController(text: ScheduleModel.defaultConditions());
    _notesController = TextEditingController();
    _repController = TextEditingController(text: 'EJ Exterminadores');
  }

  @override
  void dispose() {
    _folioController.dispose();
    _titleController.dispose();
    _businessController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _serviceTypeController.dispose();
    _conditionsController.dispose();
    _notesController.dispose();
    _repController.dispose();
    super.dispose();
  }

  String _formatFolio(int counter, DateTime date) {
    final monthStr = date.month.toString().padLeft(2, '0');
    final yearStr = (date.year % 100).toString().padLeft(2, '0');
    final sequenceStr = counter.toString().padLeft(4, '0');
    return 'EJ-CAL-$monthStr$yearStr-$sequenceStr';
  }

  Future<void> _loadClients() async {
    final clients = await _clientService.getSavedClients();
    if (mounted) setState(() => _savedClients = clients);
  }

  Future<void> _loadTechName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString(_prefTechNameKey);
    if (savedName != null && savedName.isNotEmpty && _repController.text == 'EJ Exterminadores') {
      if (mounted) setState(() => _repController.text = savedName);
    }
  }

  Future<void> _initDraftOrNew() async {
    final prefs = await SharedPreferences.getInstance();
    final rawDraft = prefs.getString(_scheduleDraftKey);

    if (rawDraft != null && rawDraft.isNotEmpty) {
      _restoreDraft(rawDraft);
    } else {
      final int currentCounter = prefs.getInt(_scheduleFolioCounterKey) ?? 1;
      setState(() {
        _folioController.text = _formatFolio(currentCounter, DateTime.now());
      });
      _generateVisits();
    }
  }

  void _restoreDraft(String raw) {
    try {
      final map = jsonDecode(raw);
      setState(() {
        _folioController.text = map['folio'] ?? _folioController.text;
        _titleController.text = map['title'] ?? _titleController.text;
        _startDate = DateTime.tryParse(map['startDate'] ?? '') ?? DateTime.now();
        _durationMonths = map['durationMonths'] ?? 12;
        _visitsPerMonth = map['visitsPerMonth'] ?? 1;
        _recurrenceMode = map['recurrenceMode'] ?? 'relative';
        _ordinalWeek = map['ordinalWeek'] ?? 1;
        _secondOrdinalWeek = map['secondOrdinalWeek'] ?? 3;
        _weekday = map['weekday'] ?? 7;
        _fixedDay = map['fixedDay'] ?? 1;
        _secondFixedDay = map['secondFixedDay'] ?? 15;
        _businessController.text = map['businessName'] ?? '';
        _contactController.text = map['contactName'] ?? '';
        _addressController.text = map['address'] ?? '';
        _phoneController.text = map['phone'] ?? '';
        _emailController.text = map['email'] ?? '';
        _facilityType = map['facilityType'] ?? 'Comercial / Restaurante';
        final savedServiceType = (map['serviceType'] ?? '').toString();
        if (savedServiceType.isEmpty || savedServiceType.toLowerCase().contains('dormitorio') || savedServiceType == 'Control y Mantenimiento Periódico') {
          _serviceTypeController.text = 'Servicio de Control de Plagas';
        } else {
          _serviceTypeController.text = savedServiceType;
        }
        _conditionsController.text = map['conditions'] ?? ScheduleModel.defaultConditions();
        _notesController.text = map['notes'] ?? '';
        _repController.text = map['elaboratedBy'] ?? _repController.text;
        _addToAgenda = map['addToAgenda'] ?? false;

        _visits.clear();
        if (map['visits'] != null) {
          for (var vMap in (map['visits'] as List)) {
            final v = ScheduledVisit.fromMap(vMap);
            if (v.serviceType.toLowerCase().contains('dormitorio') || v.serviceType.isEmpty) {
              v.serviceType = 'Servicio de Control de Plagas';
            }
            _visits.add(v);
          }
        }
      });

      if (_visits.isEmpty) {
        _generateVisits();
      }
    } catch (_) {
      _generateVisits();
    }
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftMap = {
      'folio': _folioController.text,
      'title': _titleController.text,
      'startDate': _startDate.toIso8601String(),
      'durationMonths': _durationMonths,
      'visitsPerMonth': _visitsPerMonth,
      'recurrenceMode': _recurrenceMode,
      'ordinalWeek': _ordinalWeek,
      'secondOrdinalWeek': _secondOrdinalWeek,
      'weekday': _weekday,
      'fixedDay': _fixedDay,
      'secondFixedDay': _secondFixedDay,
      'businessName': _businessController.text,
      'contactName': _contactController.text,
      'address': _addressController.text,
      'phone': _phoneController.text,
      'email': _emailController.text,
      'facilityType': _facilityType,
      'serviceType': _serviceTypeController.text,
      'conditions': _conditionsController.text,
      'notes': _notesController.text,
      'elaboratedBy': _repController.text,
      'addToAgenda': _addToAgenda,
      'visits': _visits.map((v) => v.toMap()).toList(),
    };
    await prefs.setString(_scheduleDraftKey, jsonEncode(draftMap));
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

  /// Calcula la fecha del N-ésimo día de la semana en un mes determinado
  DateTime _calculateNthWeekdayOfMonth(int year, int month, int ordinal, int weekday) {
    if (ordinal <= 4) {
      final firstOfMonth = DateTime(year, month, 1);
      final daysDiff = (weekday - firstOfMonth.weekday + 7) % 7;
      final day = 1 + daysDiff + (ordinal - 1) * 7;
      return DateTime(year, month, day);
    } else {
      // 5 = Último de ese mes
      final nextMonthFirst = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
      final lastOfMonth = nextMonthFirst.subtract(const Duration(days: 1));
      final daysDiff = (lastOfMonth.weekday - weekday + 7) % 7;
      final day = lastOfMonth.day - daysDiff;
      return DateTime(year, month, day);
    }
  }

  /// Calcula la fecha en un día fijo del mes con clamp automático
  DateTime _calculateFixedDayOfMonth(int year, int month, int targetDay) {
    final nextMonthFirst = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final lastDay = nextMonthFirst.subtract(const Duration(days: 1)).day;
    final actualDay = targetDay.clamp(1, lastDay);
    return DateTime(year, month, actualDay);
  }

  /// Genera las visitas automáticas según las reglas elegidas
  void _generateVisits() {
    setState(() {
      _visits.clear();
      final defaultTimeStr = _formatTimeOfDay(_defaultTime);
      final serviceTypeStr = _serviceTypeController.text.trim().isNotEmpty
          ? _serviceTypeController.text.trim()
          : 'Servicio de Control de Plagas';

      final List<ScheduledVisit> generated = [];

      for (int i = 0; i < _durationMonths; i++) {
        final totalMonth = _startDate.month + i;
        final year = _startDate.year + ((totalMonth - 1) ~/ 12);
        final month = ((totalMonth - 1) % 12) + 1;

        // Visita 1 del mes
        DateTime visitDate1;
        if (_recurrenceMode == 'relative') {
          visitDate1 = _calculateNthWeekdayOfMonth(year, month, _ordinalWeek, _weekday);
        } else {
          visitDate1 = _calculateFixedDayOfMonth(year, month, _fixedDay);
        }

        generated.add(
          ScheduledVisit(
            id: '${DateTime.now().millisecondsSinceEpoch}_${i}_1',
            visitNumber: 0,
            date: visitDate1,
            time: defaultTimeStr,
            serviceType: serviceTypeStr,
            status: 'Pendiente',
            clientBusinessName: _businessController.text.trim(),
            clientContactName: _contactController.text.trim(),
            clientPhone: _phoneController.text.trim(),
            clientAddress: _addressController.text.trim(),
            scheduleId: _folioController.text.trim(),
          ),
        );

        // Si son 2 visitas por mes (Quincenal)
        if (_visitsPerMonth == 2) {
          DateTime visitDate2;
          if (_recurrenceMode == 'relative') {
            visitDate2 = _calculateNthWeekdayOfMonth(year, month, _secondOrdinalWeek, _weekday);
          } else {
            visitDate2 = _calculateFixedDayOfMonth(year, month, _secondFixedDay);
          }

          generated.add(
            ScheduledVisit(
              id: '${DateTime.now().millisecondsSinceEpoch}_${i}_2',
              visitNumber: 0,
              date: visitDate2,
              time: defaultTimeStr,
              serviceType: serviceTypeStr,
              status: 'Pendiente',
              clientBusinessName: _businessController.text.trim(),
              clientContactName: _contactController.text.trim(),
              clientPhone: _phoneController.text.trim(),
              clientAddress: _addressController.text.trim(),
              scheduleId: _folioController.text.trim(),
            ),
          );
        }
      }

      // Ordenar cronológicamente todas las visitas generadas
      generated.sort((a, b) => a.date.compareTo(b.date));

      // Asignar numeración consecutiva
      for (int idx = 0; idx < generated.length; idx++) {
        _visits.add(
          ScheduledVisit(
            id: generated[idx].id,
            visitNumber: idx + 1,
            date: generated[idx].date,
            time: generated[idx].time,
            serviceType: generated[idx].serviceType,
            status: generated[idx].status,
            clientBusinessName: generated[idx].clientBusinessName,
            clientContactName: generated[idx].clientContactName,
            clientPhone: generated[idx].clientPhone,
            clientAddress: generated[idx].clientAddress,
            scheduleId: generated[idx].scheduleId,
            calendarEventId: generated[idx].calendarEventId,
          ),
        );
      }
    });
    _saveDraft();
  }

  Future<void> _showMonthYearPickerDialog() async {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril',
      'Mayo', 'Junio', 'Julio', 'Agosto',
      'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    int selectedYear = _startDate.year;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setDialogState(() => selectedYear--),
              ),
              Text(
                '$selectedYear',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F2B48)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setDialogState(() => selectedYear++),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.6,
              ),
              itemCount: 12,
              itemBuilder: (context, idx) {
                final monthNum = idx + 1;
                final isCurrent = _startDate.year == selectedYear && _startDate.month == monthNum;
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _startDate = DateTime(selectedYear, monthNum, 1);
                    });
                    _generateVisits();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrent ? const Color(0xFF0F2B48) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent ? const Color(0xFF0F2B48) : Colors.grey.shade300,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      months[idx],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                        color: isCurrent ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  Future<void> _editSpecificVisitDate(ScheduledVisit visit) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: visit.date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Selecciona la fecha para la Visita #${visit.visitNumber}',
    );

    if (picked != null) {
      setState(() {
        visit.date = picked;
      });
      _saveDraft();
    }
  }

  Future<void> _editSpecificVisitTime(ScheduledVisit visit) async {
    TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0);
    try {
      final parts = visit.time.split(' ');
      final timeParts = parts[0].split(':');
      int h = int.parse(timeParts[0]);
      int m = int.parse(timeParts[1]);
      if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && h < 12) h += 12;
      if (parts.length > 1 && parts[1].toUpperCase() == 'AM' && h == 12) h = 0;
      initial = TimeOfDay(hour: h, minute: m);
    } catch (_) {}

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Horario para Visita #${visit.visitNumber}',
    );

    if (picked != null) {
      setState(() {
        visit.time = _formatTimeOfDay(picked);
      });
      _saveDraft();
    }
  }

  Future<void> _clearDraftAndNewSchedule() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Iniciar Nueva Calendarización?'),
        content: const Text(
          'Esto limpiará el formulario para comenzar un nuevo cronograma y generará el siguiente folio consecutivo.\n\n(Los clientes e historial se mantienen intactos).',
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
      await prefs.remove(_scheduleDraftKey);

      final int currentCounter = prefs.getInt(_scheduleFolioCounterKey) ?? 1;
      final int nextCounter = currentCounter + 1;
      await prefs.setInt(_scheduleFolioCounterKey, nextCounter);

      setState(() {
        _folioController.text = _formatFolio(nextCounter, DateTime.now());
        _businessController.clear();
        _contactController.clear();
        _addressController.clear();
        _phoneController.clear();
        _emailController.clear();
        _conditionsController.text = ScheduleModel.defaultConditions();
        _notesController.clear();
        _selectedClient = null;
        _startDate = DateTime.now();
        _durationMonths = 12;
        _visitsPerMonth = 1;
        _recurrenceMode = 'relative';
        _ordinalWeek = 1;
        _secondOrdinalWeek = 3;
        _weekday = 7;
        _fixedDay = 1;
        _secondFixedDay = 15;
        _addToAgenda = false;
        _serviceTypeController.text = 'Servicio de Control de Plagas';
      });
      _generateVisits();
    }
  }

  void _generateAndPreviewSchedule() async {
    final business = _businessController.text.trim();
    final contact = _contactController.text.trim();

    if (business.isEmpty && contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa al menos la Razón Social o el Nombre de Contacto del cliente.')),
      );
      return;
    }

    if (_visits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El cronograma no tiene visitas generadas.')),
      );
      return;
    }

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

    final schedule = ScheduleModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      folio: _folioController.text.trim(),
      createdAt: DateTime.now(),
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : 'Programa Periódico de Control de Plagas',
      clientBusinessName: business,
      clientContactName: contact,
      clientAddress: _addressController.text.trim(),
      clientPhone: _phoneController.text.trim(),
      clientEmail: _emailController.text.trim(),
      facilityType: _facilityType,
      recurrenceType: _recurrenceMode,
      visitsPerMonth: _visitsPerMonth,
      ordinalWeek: _ordinalWeek,
      secondOrdinalWeek: _secondOrdinalWeek,
      weekday: _weekday,
      fixedDay: _fixedDay,
      secondFixedDay: _secondFixedDay,
      durationMonths: _durationMonths,
      startDate: _startDate,
      defaultTime: _formatTimeOfDay(_defaultTime),
      serviceType: _serviceTypeController.text.trim(),
      conditions: _conditionsController.text.trim(),
      notes: _notesController.text.trim(),
      elaboratedBy: _repController.text.trim().isNotEmpty ? _repController.text.trim() : 'EJ Exterminadores',
      isInAgenda: _addToAgenda,
      visits: _visits.map((v) {
        return ScheduledVisit(
          id: v.id,
          visitNumber: v.visitNumber,
          date: v.date,
          time: v.time,
          serviceType: v.serviceType,
          status: v.status,
          clientBusinessName: business.isNotEmpty ? business : v.clientBusinessName,
          clientContactName: contact.isNotEmpty ? contact : v.clientContactName,
          clientPhone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : v.clientPhone,
          clientAddress: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : v.clientAddress,
          scheduleId: _folioController.text.trim(),
          calendarEventId: v.calendarEventId,
          calendarId: v.calendarId,
          isProspect: false,
          isInAgenda: _addToAgenda,
        );
      }).toList(),
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SchedulePreviewScreen(schedule: schedule),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthFormat = DateFormat('MMMM yyyy', 'es_MX');
    final fullDateFormat = DateFormat('EEEE, dd \'de\' MMMM \'de\' yyyy', 'es_MX');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Calendarización', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Historial y Agenda',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScheduleHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Limpiar / Nueva Calendarización',
            onPressed: _clearDraftAndNewSchedule,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // 1. Datos Generales del Programa
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Datos del Programa de Calendarización',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48))),
                  const SizedBox(height: 12),
                  // Folio con ancho completo para visualizar siempre hasta el último dígito
                  TextField(
                    controller: _folioController,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48), letterSpacing: 0.5),
                    decoration: const InputDecoration(
                      labelText: 'Folio del Cronograma',
                      prefixIcon: Icon(Icons.tag, size: 20, color: Color(0xFF0F2B48)),
                    ),
                    onChanged: (_) => _saveDraft(),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Color(0xFF0F2B48)),
                          tooltip: 'Mes anterior',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() {
                              _startDate = DateTime(_startDate.year, _startDate.month - 1, 1);
                            });
                            _generateVisits();
                          },
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: _showMonthYearPickerDialog,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Mes Inicial del Cronograma (Toca para elegir)',
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  monthFormat.format(_startDate).toUpperCase(),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Color(0xFF0F2B48)),
                          tooltip: 'Siguiente mes',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() {
                              _startDate = DateTime(_startDate.year, _startDate.month + 1, 1);
                            });
                            _generateVisits();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre / Título de la Póliza',
                      prefixIcon: Icon(Icons.badge_outlined, size: 20),
                    ),
                    onChanged: (_) => _saveDraft(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. Datos del Cliente
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
                      const Text('Datos del Cliente',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48))),
                      if (_savedClients.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.people_outline, size: 18),
                          label: const Text('Cargar Cliente'),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                              builder: (context) => ListView.builder(
                                itemCount: _savedClients.length,
                                itemBuilder: (context, i) {
                                  final c = _savedClients[i];
                                  return ListTile(
                                    title: Text(
                                        c.businessName.isNotEmpty ? c.businessName : c.contactName,
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
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

          // 3. Reglas de Periodicidad y Recurrencia
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.repeat, color: Color(0xFF0F2B48), size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Regla de Periodicidad del Servicio',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Frecuencia del Servicio
                  const Text('Frecuencia del Servicio:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              '1 Visita / Mes (Mensual)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _visitsPerMonth == 1 ? Colors.white : Colors.black87,
                                fontWeight: _visitsPerMonth == 1 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          selected: _visitsPerMonth == 1,
                          selectedColor: const Color(0xFF0F2B48),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _visitsPerMonth = 1);
                              _generateVisits();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              '2 Visitas / Mes (Quincenal)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _visitsPerMonth == 2 ? Colors.white : Colors.black87,
                                fontWeight: _visitsPerMonth == 2 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          selected: _visitsPerMonth == 2,
                          selectedColor: const Color(0xFF0F2B48),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _visitsPerMonth = 2);
                              _generateVisits();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Selector de Tipo de Regla
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              _visitsPerMonth == 1 ? 'Día Relativo (1er Dom)' : 'Días Relativos (1er y 3er)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _recurrenceMode == 'relative' ? Colors.white : Colors.black87,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          selected: _recurrenceMode == 'relative',
                          selectedColor: const Color(0xFF0F2B48),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _recurrenceMode = 'relative');
                              _generateVisits();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              _visitsPerMonth == 1 ? 'Día Fijo (Ej. Día 15)' : 'Días Fijos (Ej. 1 y 15)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _recurrenceMode == 'fixed_day' ? Colors.white : Colors.black87,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          selected: _recurrenceMode == 'fixed_day',
                          selectedColor: const Color(0xFF0F2B48),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _recurrenceMode = 'fixed_day');
                              _generateVisits();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_recurrenceMode == 'relative') ...[
                    if (_visitsPerMonth == 1) ...[
                      Row(
                        children: [
                          // Ordinal
                          Expanded(
                            flex: 5,
                            child: DropdownButtonFormField<int>(
                              value: _ordinalWeek,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Semana / Posición'),
                              items: _ordinals.entries
                                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _ordinalWeek = val);
                                  _generateVisits();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Día de la Semana
                          Expanded(
                            flex: 6,
                            child: DropdownButtonFormField<int>(
                              value: _weekday,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Día de la Semana'),
                              items: _weekdays.entries
                                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _weekday = val);
                                  _generateVisits();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // 2 Visitas al mes - Relativas
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _ordinalWeek,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: '1ra Visita (Semana)'),
                              items: _ordinals.entries
                                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12.5))))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _ordinalWeek = val);
                                  _generateVisits();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _secondOrdinalWeek,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: '2da Visita (Semana)'),
                              items: _ordinals.entries
                                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12.5))))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _secondOrdinalWeek = val);
                                  _generateVisits();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        value: _weekday,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Día de la Semana para ambas visitas',
                          prefixIcon: Icon(Icons.event_repeat, size: 20),
                        ),
                        items: _weekdays.entries
                            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _weekday = val);
                            _generateVisits();
                          }
                        },
                      ),
                    ],
                  ] else ...[
                    // Día fijo
                    if (_visitsPerMonth == 1) ...[
                      DropdownButtonFormField<int>(
                        value: _fixedDay,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Día fijo de cada mes',
                          prefixIcon: Icon(Icons.event, size: 20),
                        ),
                        items: List.generate(31, (i) => i + 1)
                            .map((d) => DropdownMenuItem(value: d, child: Text('Día $d de cada mes')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _fixedDay = val);
                            _generateVisits();
                          }
                        },
                      ),
                    ] else ...[
                      // 2 Visitas al mes - Días fijos
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _fixedDay,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: '1er Día del Mes',
                                prefixIcon: Icon(Icons.event, size: 18),
                              ),
                              items: List.generate(31, (i) => i + 1)
                                  .map((d) => DropdownMenuItem(value: d, child: Text('Día $d')))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _fixedDay = val);
                                  _generateVisits();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _secondFixedDay,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: '2do Día del Mes',
                                prefixIcon: Icon(Icons.event, size: 18),
                              ),
                              items: List.generate(31, (i) => i + 1)
                                  .map((d) => DropdownMenuItem(value: d, child: Text('Día $d')))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _secondFixedDay = val);
                                  _generateVisits();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],

                  const SizedBox(height: 14),

                  // Duración de la Póliza (Meses)
                  const Text('Duración de la Póliza o Contrato:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [3, 5, 6, 12].map((months) {
                      final isSelected = _durationMonths == months;
                      return ChoiceChip(
                        label: Text(months == 12 ? '12 meses (Anual)' : '$months meses'),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0F2B48),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _durationMonths = months);
                            _generateVisits();
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // Horario Base y Tipo de Servicio
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(context: context, initialTime: _defaultTime);
                            if (picked != null) {
                              setState(() => _defaultTime = picked);
                              _generateVisits();
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Horario Habitual'),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 18, color: Color(0xFF0F2B48)),
                                const SizedBox(width: 8),
                                Text(_formatTimeOfDay(_defaultTime), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _serviceTypeController,
                          decoration: const InputDecoration(labelText: 'Tipo de Servicio'),
                          onChanged: (_) {
                            for (var v in _visits) {
                              v.serviceType = _serviceTypeController.text;
                            }
                            _saveDraft();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4. Lista Interactiva de Visitas (Se pueden editar fechas individualmente)
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Visitas Programadas (${_visits.length})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48))),
                            const SizedBox(height: 2),
                            const Text('Toca para cambiar fecha u hora',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F2B48),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Visita Extra', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          setState(() {
                            final lastDate = _visits.isNotEmpty ? _visits.last.date : DateTime.now();
                            final newDate = lastDate.add(const Duration(days: 30));
                            _visits.add(ScheduledVisit(
                              id: '${DateTime.now().millisecondsSinceEpoch}_extra',
                              visitNumber: _visits.length + 1,
                              date: newDate,
                              time: _formatTimeOfDay(_defaultTime),
                              serviceType: _serviceTypeController.text,
                            ));
                          });
                          _saveDraft();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _visits.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final v = _visits[idx];
                      final isRealizada = v.status == 'Realizada';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: isRealizada ? Colors.green.shade100 : const Color(0xFF0F2B48).withValues(alpha: 0.1),
                          child: Text(
                            '#${v.visitNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isRealizada ? Colors.green.shade800 : const Color(0xFF0F2B48),
                            ),
                          ),
                        ),
                        title: Text(
                          fullDateFormat.format(v.date),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: isRealizada ? Colors.green.shade900 : Colors.black87,
                            decoration: isRealizada ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          '${v.time} • ${v.serviceType}',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.calendar_today, size: 18, color: Color(0xFF0F2B48)),
                              tooltip: 'Cambiar Fecha de esta Visita',
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _editSpecificVisitDate(v),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.access_time, size: 18, color: Color(0xFF0F2B48)),
                              tooltip: 'Cambiar Horario',
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _editSpecificVisitTime(v),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              tooltip: 'Eliminar esta visita',
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() => _visits.removeAt(idx));
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

          // 5. Condiciones del Cronograma
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
                      const Text('Condiciones del Cronograma',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48))),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1E6091),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Restaurar', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          setState(() {
                            _conditionsController.text = ScheduleModel.defaultConditions();
                          });
                          _saveDraft();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Puedes editar o agregar puntos extras según el acuerdo con el cliente.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _conditionsController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Condiciones y acuerdos aplicables',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => _saveDraft(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 6. Notas y Responsable
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notas del Cronograma',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48))),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Indicaciones especiales / accesos (Opcional)'),
                    onChanged: (_) => _saveDraft(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _repController,
                    decoration: const InputDecoration(labelText: 'Elaborado por (Coordinación / Asesor)'),
                    onChanged: (_) => _saveDraft(),
                  ),
                ],
              ),
            ),
          ),
          // 7. Opciones de Agenda y Recordatorios
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _addToAgenda ? const Color(0xFF0F2B48) : Colors.grey.shade300,
                width: _addToAgenda ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _addToAgenda ? const Color(0xFF0F2B48).withOpacity(0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.event_available,
                    color: _addToAgenda ? const Color(0xFF0F2B48) : Colors.grey,
                  ),
                ),
                title: const Text(
                  '¿Agregar visitas a mi Agenda de Trabajo?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                subtitle: Text(
                  _addToAgenda
                      ? '✓ Se programarán en tu Agenda y podrás sincronizarlas con Google Calendar.'
                      : '○ Solo se generará el documento PDF del Cronograma sin llenar tu agenda.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _addToAgenda ? Colors.green.shade800 : Colors.grey.shade700,
                    fontWeight: _addToAgenda ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                value: _addToAgenda,
                activeColor: const Color(0xFF0F2B48),
                onChanged: (val) {
                  setState(() => _addToAgenda = val);
                  _saveDraft();
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

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
              label: const Text('GENERAR Y PREVISUALIZAR CALENDARIO',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              onPressed: _generateAndPreviewSchedule,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
