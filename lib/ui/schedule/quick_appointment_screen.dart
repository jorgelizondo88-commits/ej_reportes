import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/client_model.dart';
import '../../models/schedule_model.dart';
import '../../services/calendar_sync_service.dart';
import '../../services/client_service.dart';
import '../../services/google_drive_sync_service.dart';
import '../../services/notification_service.dart';

class QuickAppointmentScreen extends StatefulWidget {
  final bool initialIsProspect;
  final DateTime? initialDate;

  const QuickAppointmentScreen({
    super.key,
    this.initialIsProspect = false,
    this.initialDate,
  });

  @override
  State<QuickAppointmentScreen> createState() => _QuickAppointmentScreenState();
}

class _QuickAppointmentScreenState extends State<QuickAppointmentScreen> {
  static const String _schedulesHistoryKey = 'ej_schedules_history_list';
  static const String _quickFolioCounterKey = 'ej_quick_appointment_folio_counter';

  final ClientService _clientService = ClientService();
  final CalendarSyncService _calendarSyncService = CalendarSyncService();

  List<ClientModel> _savedClients = [];
  ClientModel? _selectedClient;
  bool _isNewClient = true;
  bool _saveToClientDirectory = true;

  late TextEditingController _businessController;
  late TextEditingController _contactController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;

  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);

  String _appointmentCategory = 'Servicio de Control de Plagas';
  bool _syncGoogleCalendar = true;
  bool _isSaving = false;

  // Recordatorios y Notificaciones seleccionables (Múltiples avisos)
  final List<Map<String, dynamic>> _reminderOptions = [
    {'mins': 10080, 'label': '1 semana antes'},
    {'mins': 4320, 'label': '3 días antes'},
    {'mins': 2880, 'label': '2 días antes'},
    {'mins': 1440, 'label': '1 día antes'},
    {'mins': 120, 'label': '2 horas antes'},
    {'mins': 30, 'label': '30 min antes'},
  ];
  late Set<int> _selectedReminderMinutes;

  // Repetición / Recurrencia Sencilla (Opcional)
  bool _isRecurring = false;
  String _recurrencePattern = 'relative_weekday'; // 'relative_weekday', 'same_day_number', 'biweekly'
  int _selectedOrdinal = 1; // 1 = 1er, 2 = 2do, 3 = 3er, 4 = 4to, 5 = Último
  int _selectedWeekday = 7; // 7 = Domingo, 6 = Sábado, 1 = Lunes, etc.
  int _recurrenceMonths = 12; // 3, 6, 12 meses

  final Map<int, String> _ordinals = {
    1: '1er',
    2: '2do',
    3: '3er',
    4: '4to',
    5: 'Último',
  };

  final Map<int, String> _ordinalsFull = {
    1: '1er (Primer)',
    2: '2do (Segundo)',
    3: '3er (Tercer)',
    4: '4to (Cuarto)',
    5: 'Último',
  };

  final Map<int, String> _weekdays = {
    7: 'Domingo',
    6: 'Sábado',
    5: 'Viernes',
    4: 'Jueves',
    3: 'Miércoles',
    2: 'Martes',
    1: 'Lunes',
  };

  final List<String> _categoryOptions = [
    'Servicio de Control de Plagas',
    '🎯 Prospecto / 1ra Visita',
    '🔍 Inspección y Diagnóstico Inicial',
    '🏠 Servicio Residencial / Casa',
    '🏢 Servicio Comercial / Negocio',
    '🛡️ Garantía / Refuerzo',
    '📋 Servicio General',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now().add(const Duration(days: 1));
    _selectedWeekday = _selectedDate.weekday;
    if (widget.initialIsProspect) {
      _appointmentCategory = '🎯 Prospecto / 1ra Visita';
    } else {
      _appointmentCategory = 'Servicio de Control de Plagas';
    }

    // Por defecto: 1 semana antes, 2 días antes y 2 horas antes
    _selectedReminderMinutes = {10080, 2880, 120};

    _businessController = TextEditingController();
    _contactController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _notesController = TextEditingController();

    _loadClients();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPermissions();
    });
  }

  Future<void> _checkNotificationPermissions() async {
    final enabled = await NotificationService().areNotificationsEnabled();
    if (!enabled && mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.notifications_active, color: Color(0xFF0F2B48)),
              SizedBox(width: 8),
              Expanded(child: Text('Activar Recordatorios', style: TextStyle(fontSize: 16))),
            ],
          ),
          content: const Text(
            'Para que EJ Reportes te envíe alertas automáticas con su logotipo antes de cada servicio (1 semana antes, 2 días antes o según configures), por favor permite las notificaciones.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Más tarde'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2B48), foregroundColor: Colors.white),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(this.context);
                Navigator.pop(context);
                final granted = await NotificationService().requestPermission();
                if (granted && mounted) {
                  await NotificationService().showTestNotification();
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('¡Notificaciones activadas con éxito!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Permitir Notificaciones'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _businessController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final clients = await _clientService.getSavedClients();
    if (mounted) {
      setState(() {
        _savedClients = clients;
      });
    }
  }

  void _onClientSelected(ClientModel? client) {
    setState(() {
      _selectedClient = client;
      if (client != null) {
        _businessController.text = client.businessName;
        _contactController.text = client.contactName;
        _phoneController.text = client.phone;
        _addressController.text = client.address;
        _isNewClient = false;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: 'Selecciona la fecha del servicio',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: 'Selecciona el horario del servicio',
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  DateTime _calculateNthWeekdayOfMonth(int year, int month, int ordinal, int weekday) {
    if (ordinal <= 4) {
      final firstOfMonth = DateTime(year, month, 1);
      final daysDiff = (weekday - firstOfMonth.weekday + 7) % 7;
      final day = 1 + daysDiff + (ordinal - 1) * 7;
      final nextMonthFirst = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
      final lastDay = nextMonthFirst.subtract(const Duration(days: 1)).day;
      return DateTime(year, month, day.clamp(1, lastDay));
    } else {
      // 5 = Último de ese mes
      final nextMonthFirst = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
      final lastOfMonth = nextMonthFirst.subtract(const Duration(days: 1));
      final daysDiff = (lastOfMonth.weekday - weekday + 7) % 7;
      final day = lastOfMonth.day - daysDiff;
      return DateTime(year, month, day);
    }
  }

  /// Calcula la lista de fechas exactas para la vista previa en tiempo real
  List<DateTime> _calculatePreviewDates() {
    final List<DateTime> dates = [];
    final int count = _recurrencePattern == 'biweekly' ? _recurrenceMonths * 2 : _recurrenceMonths;

    for (int i = 0; i < count; i++) {
      if (_recurrencePattern == 'relative_weekday') {
        final totalMonth = _selectedDate.month + i;
        final year = _selectedDate.year + ((totalMonth - 1) ~/ 12);
        final month = ((totalMonth - 1) % 12) + 1;
        dates.add(_calculateNthWeekdayOfMonth(year, month, _selectedOrdinal, _selectedWeekday));
      } else if (_recurrencePattern == 'same_day_number') {
        final totalMonth = _selectedDate.month + i;
        final year = _selectedDate.year + ((totalMonth - 1) ~/ 12);
        final month = ((totalMonth - 1) % 12) + 1;
        final nextMonthFirst = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
        final lastDay = nextMonthFirst.subtract(const Duration(days: 1)).day;
        final actualDay = _selectedDate.day.clamp(1, lastDay);
        dates.add(DateTime(year, month, actualDay));
      } else {
        // biweekly
        dates.add(_selectedDate.add(Duration(days: 14 * i)));
      }
    }
    return dates;
  }

  Future<void> _saveAppointment() async {
    final business = _businessController.text.trim();
    final contact = _contactController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final notes = _notesController.text.trim();

    if (business.isEmpty && contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa el nombre del cliente o prospecto.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Folio consecutivo para citas rápidas / prospectos
      final isProspect = _appointmentCategory.contains('Prospecto');
      final currentCounter = (prefs.getInt(_quickFolioCounterKey) ?? 0) + 1;
      await prefs.setInt(_quickFolioCounterKey, currentCounter);

      final prefix = isProspect ? 'PROSP' : 'CITA';
      final folio = 'EJ-$prefix-${currentCounter.toString().padLeft(3, '0')}';

      final displayName = business.isNotEmpty ? business : contact;
      final timeStr = _formatTimeOfDay(_selectedTime);

      // Guardar en Directorio de Clientes si está marcado y es nuevo (la Copia Maestra se actualiza al finalizar la cita)
      if (_isNewClient && _saveToClientDirectory) {
        final newClient = ClientModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          businessName: business.isNotEmpty ? business : contact,
          contactName: contact,
          phone: phone,
          address: address,
          email: '',
          facilityType: _appointmentCategory.contains('Residencial') ? 'Residencial / Casa' : 'Comercial / Empresa',
          hasTraps: false,
        );
        await _clientService.saveClient(newClient, syncMasterBackup: false);
      }

      // Descripción legible del patrón de recurrencia
      String recurrenceDesc = 'Cita individual';
      if (_isRecurring) {
        if (_recurrencePattern == 'relative_weekday') {
          recurrenceDesc = 'Cada ${_ordinalsFull[_selectedOrdinal]} ${_weekdays[_selectedWeekday]} de cada mes';
        } else if (_recurrencePattern == 'same_day_number') {
          recurrenceDesc = 'Día ${_selectedDate.day} de cada mes';
        } else {
          recurrenceDesc = 'Cada 15 días (quincenal)';
        }
      }

      // Generación de visitas (1 visita individual o serie recurrente)
      final List<ScheduledVisit> generatedVisits = [];
      final int totalVisits = _isRecurring
          ? (_recurrencePattern == 'biweekly' ? _recurrenceMonths * 2 : _recurrenceMonths)
          : 1;

      for (int i = 0; i < totalVisits; i++) {
        DateTime visitDate;
        if (!_isRecurring) {
          visitDate = _selectedDate;
        } else if (_recurrencePattern == 'relative_weekday') {
          final totalMonth = _selectedDate.month + i;
          final year = _selectedDate.year + ((totalMonth - 1) ~/ 12);
          final month = ((totalMonth - 1) % 12) + 1;
          visitDate = _calculateNthWeekdayOfMonth(year, month, _selectedOrdinal, _selectedWeekday);
        } else if (_recurrencePattern == 'same_day_number') {
          final totalMonth = _selectedDate.month + i;
          final year = _selectedDate.year + ((totalMonth - 1) ~/ 12);
          final month = ((totalMonth - 1) % 12) + 1;
          final nextMonthFirst = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
          final lastDay = nextMonthFirst.subtract(const Duration(days: 1)).day;
          final actualDay = _selectedDate.day.clamp(1, lastDay);
          visitDate = DateTime(year, month, actualDay);
        } else {
          // quincenal
          visitDate = _selectedDate.add(Duration(days: 14 * i));
        }

        final visit = ScheduledVisit(
          id: '${DateTime.now().millisecondsSinceEpoch}_${i}_quick',
          visitNumber: i + 1,
          date: visitDate,
          time: timeStr,
          serviceType: _appointmentCategory,
          status: 'Pendiente',
          notes: notes,
          scheduleId: folio,
          clientBusinessName: displayName,
          clientContactName: contact,
          clientPhone: phone,
          clientAddress: address,
          isProspect: isProspect,
          isInAgenda: true,
          reminderMinutes: _selectedReminderMinutes.toList(),
        );

        // Sincronizar de inmediato con Google Calendar con los recordatorios elegidos
        if (_syncGoogleCalendar) {
          final eventId = await _calendarSyncService.syncVisitToGoogleCalendar(
            visit,
            clientNameOverride: displayName,
            phoneOverride: phone,
            addressOverride: address,
            notesOverride: notes,
            customReminderMinutes: _selectedReminderMinutes.toList(),
          );
          if (eventId != null) {
            visit.calendarEventId = eventId;
          }
        }

        // Programar alertas nativas en el dispositivo (notificación push local con sonido y logo de EJ)
        try {
          await NotificationService().scheduleVisitReminders(visit);
        } catch (e) {
          debugPrint('Error programando alertas locales: $e');
        }

        generatedVisits.add(visit);
      }

      // Crear ScheduleModel envolvente para que conviva uniformemente en la base de datos
      final scheduleModel = ScheduleModel(
        id: 'schedule_${DateTime.now().millisecondsSinceEpoch}',
        folio: folio,
        createdAt: DateTime.now(),
        title: isProspect
            ? 'Visita Prospecto / Levantamiento'
            : (_isRecurring ? 'Servicio Recurrente ($recurrenceDesc)' : 'Cita de Servicio Agendada'),
        clientBusinessName: displayName,
        clientContactName: contact,
        clientPhone: phone,
        clientAddress: address,
        clientEmail: '',
        facilityType: _appointmentCategory.contains('Residencial') ? 'Residencial' : 'Comercial',
        isProspect: isProspect,
        appointmentCategory: isProspect ? 'Prospecto' : (_isRecurring ? 'Recurrente' : 'CitaIndividual'),
        recurrenceType: _isRecurring ? _recurrencePattern : 'single',
        visitsPerMonth: _isRecurring ? (_recurrencePattern == 'biweekly' ? 2 : 1) : 0,
        durationMonths: _isRecurring ? _recurrenceMonths : 1,
        startDate: _selectedDate,
        defaultTime: timeStr,
        serviceType: _appointmentCategory,
        notes: notes,
        isInAgenda: true,
        visits: generatedVisits,
      );

      // Guardar en historial general
      final raw = prefs.getString(_schedulesHistoryKey);
      List list = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          list = jsonDecode(raw);
        } catch (_) {}
      }

      final scheduleEntry = {
        'id': scheduleModel.id,
        'folio': scheduleModel.folio,
        'createdAt': scheduleModel.createdAt.toIso8601String(),
        'businessName': scheduleModel.clientBusinessName,
        'clientName': scheduleModel.clientContactName,
        'phone': scheduleModel.clientPhone,
        'clientAddress': scheduleModel.clientAddress,
        'recurrenceDescription': recurrenceDesc,
        'totalVisits': totalVisits,
        'completedVisits': 0,
        'isProspect': isProspect,
        'isInAgenda': true,
        'appointmentCategory': scheduleModel.appointmentCategory,
        'scheduleData': scheduleModel.toMap(),
      };

      list.insert(0, scheduleEntry);
      await prefs.setString(_schedulesHistoryKey, jsonEncode(list));

      final bool cloudMasterUpdated = await GoogleDriveSyncService().saveAndSyncMasterBackup();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (_isRecurring
                            ? '¡$totalVisits citas agendadas ($recurrenceDesc)'
                            : (_syncGoogleCalendar && generatedVisits.first.calendarEventId != null
                                ? '¡Cita agendada en Calendar'
                                : '¡Cita guardada en tu Agenda')) +
                        (cloudMasterUpdated
                            ? ' y Copia Maestra actualizada en Drive!'
                            : ' (guardado local, pendiente conexión a Drive)!'),
                  ),
                ),
              ],
            ),
            backgroundColor: cloudMasterUpdated ? Colors.green.shade800 : Colors.orange.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al agendar cita: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, dd \'de\' MMMM \'de\' yyyy', 'es_MX');
    final isProspect = _appointmentCategory.contains('Prospecto');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isProspect ? 'Agendar Visita Prospecto' : 'Agendar Cita / Servicio',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner explicativo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isProspect ? Colors.orange.shade50 : const Color(0xFF0F2B48).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isProspect ? Colors.orange.shade300 : const Color(0xFF0F2B48).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isProspect ? Icons.person_search : Icons.event_available,
                    color: isProspect ? Colors.orange.shade800 : const Color(0xFF0F2B48),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isProspect
                          ? 'Agenda una visita inicial para evaluar áreas de un nuevo prospecto o realizar un levantamiento técnico.'
                          : 'Agenda una visita individual (inspección, casa habitación, empresa o servicio puntual).',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isProspect ? Colors.orange.shade900 : const Color(0xFF0F2B48),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 1. TIPO DE SERVICIO / CITA
            const Text('1. Tipo de Servicio o Visita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _appointmentCategory,
                  items: _categoryOptions.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt,
                      child: Text(opt, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _appointmentCategory = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 2. CLIENTE O PROSPECTO
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    '2. Datos del Cliente o Prospecto',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_savedClients.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    icon: Icon(_isNewClient ? Icons.contacts : Icons.add_circle_outline, size: 16),
                    label: Text(
                      _isNewClient ? 'Directorio' : 'Nuevo',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      setState(() {
                        _isNewClient = !_isNewClient;
                        if (_isNewClient) {
                          _selectedClient = null;
                          _businessController.clear();
                          _contactController.clear();
                          _phoneController.clear();
                          _addressController.clear();
                        }
                      });
                    },
                  ),
              ],
            ),
            if (!_isNewClient && _savedClients.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ClientModel>(
                    isExpanded: true,
                    hint: const Text('Seleccionar cliente guardado...'),
                    value: _selectedClient,
                    items: _savedClients.map((c) {
                      return DropdownMenuItem<ClientModel>(
                        value: c,
                        child: Text('${c.businessName} (${c.contactName})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: _onClientSelected,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            TextFormField(
              controller: _businessController,
              decoration: InputDecoration(
                labelText: isProspect ? 'Nombre de la Empresa o Prospecto *' : 'Nombre Comercial o Casa *',
                hintText: isProspect ? 'Ej. Restaurante La Parroquia o Familia Garza' : 'Ej. Colegio San José',
                prefixIcon: const Icon(Icons.business),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _contactController,
              decoration: const InputDecoration(
                labelText: 'Persona de Contacto / Encargado',
                hintText: 'Ej. Ing. Carlos Salinas / Sra. Laura',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono (WhatsApp)',
                      hintText: 'Ej. 8112345678',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Dirección o Ubicación',
                hintText: 'Ej. Av. Constitución #450, Col. Centro',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
            ),

            if (_isNewClient) ...[
              const SizedBox(height: 6),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _saveToClientDirectory,
                title: const Text('Guardar datos en el Directorio de Clientes', style: TextStyle(fontSize: 13)),
                onChanged: (val) => setState(() => _saveToClientDirectory = val ?? true),
              ),
            ],
            const SizedBox(height: 14),

            // 3. FECHA Y HORA
            const Text('3. Fecha y Horario de la Visita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.calendar_today, size: 18, color: Color(0xFF0F2B48)),
                    label: Text(
                      dateFormat.format(_selectedDate),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.access_time, size: 18, color: Color(0xFF0F2B48)),
                    label: Text(
                      _formatTimeOfDay(_selectedTime),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                    ),
                    onPressed: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 4. REPETICIÓN / RECURRENCIA (OPCIONAL)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isRecurring ? const Color(0xFF0F2B48).withValues(alpha: 0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isRecurring ? const Color(0xFF0F2B48) : Colors.grey.shade300,
                  width: _isRecurring ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.repeat, size: 20, color: _isRecurring ? const Color(0xFF0F2B48) : Colors.grey),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '¿Repetir este servicio periódico?',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isRecurring,
                        activeColor: const Color(0xFF0F2B48),
                        onChanged: (val) => setState(() => _isRecurring = val),
                      ),
                    ],
                  ),
                  if (_isRecurring) ...[
                    const Divider(height: 18),
                    const Text('Modalidad de repetición:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('Día de la semana de cada mes', style: TextStyle(fontSize: 11.5)),
                          selected: _recurrencePattern == 'relative_weekday',
                          selectedColor: const Color(0xFF0F2B48),
                          labelStyle: TextStyle(
                            color: _recurrencePattern == 'relative_weekday' ? Colors.white : Colors.black87,
                            fontWeight: _recurrencePattern == 'relative_weekday' ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) => setState(() => _recurrencePattern = 'relative_weekday'),
                        ),
                        ChoiceChip(
                          label: Text('Mismo día cada mes (Día ${_selectedDate.day})', style: const TextStyle(fontSize: 11.5)),
                          selected: _recurrencePattern == 'same_day_number',
                          selectedColor: const Color(0xFF0F2B48),
                          labelStyle: TextStyle(
                            color: _recurrencePattern == 'same_day_number' ? Colors.white : Colors.black87,
                            fontWeight: _recurrencePattern == 'same_day_number' ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) => setState(() => _recurrencePattern = 'same_day_number'),
                        ),
                        ChoiceChip(
                          label: const Text('Cada 15 días (quincenal)', style: TextStyle(fontSize: 11.5)),
                          selected: _recurrencePattern == 'biweekly',
                          selectedColor: const Color(0xFF0F2B48),
                          labelStyle: TextStyle(
                            color: _recurrencePattern == 'biweekly' ? Colors.white : Colors.black87,
                            fontWeight: _recurrencePattern == 'biweekly' ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) => setState(() => _recurrencePattern = 'biweekly'),
                        ),
                      ],
                    ),

                    if (_recurrencePattern == 'relative_weekday') ...[
                      const SizedBox(height: 14),
                      // 1. Selector de Semana (1er, 2do, 3er, 4to, Último)
                      const Text('1. ¿Qué semana del mes?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _ordinals.entries.map((entry) {
                          final isSel = _selectedOrdinal == entry.key;
                          return ChoiceChip(
                            label: Text(entry.value, style: const TextStyle(fontSize: 12)),
                            selected: isSel,
                            selectedColor: const Color(0xFF0F2B48),
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : Colors.black87,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (_) => setState(() => _selectedOrdinal = entry.key),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 12),
                      // 2. Selector de Día de la semana (Domingo, Sábado, etc.)
                      const Text('2. ¿Qué día de la semana?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _weekdays.entries.map((entry) {
                          final isSel = _selectedWeekday == entry.key;
                          return ChoiceChip(
                            label: Text(entry.value, style: const TextStyle(fontSize: 11.5)),
                            selected: isSel,
                            selectedColor: const Color(0xFF0F2B48),
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : Colors.black87,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (_) => setState(() => _selectedWeekday = entry.key),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 10),
                      // Resumen visual destacado
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F2B48).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, size: 16, color: Color(0xFF0F2B48)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Programar cada ${_ordinalsFull[_selectedOrdinal]} ${_weekdays[_selectedWeekday]} de cada mes',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F2B48)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    const Text('3. Duración de la serie:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [3, 6, 12].map((m) {
                        final isSel = _recurrenceMonths == m;
                        final count = _recurrencePattern == 'biweekly' ? m * 2 : m;
                        return ChoiceChip(
                          label: Text('$m meses ($count visitas)', style: const TextStyle(fontSize: 11.5)),
                          selected: isSel,
                          selectedColor: const Color(0xFF0F2B48),
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : Colors.black87,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) => setState(() => _recurrenceMonths = m),
                        );
                      }).toList(),
                    ),

                    // 4. Vista previa interactiva de las fechas calculadas
                    Builder(
                      builder: (context) {
                        final previewDates = _calculatePreviewDates();
                        final previewFormat = DateFormat('EEEE, d \'de\' MMMM \'de\' yyyy', 'es_MX');
                        return Container(
                          margin: const EdgeInsets.only(top: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.event_note, size: 18, color: Color(0xFF0F2B48)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Fechas calculadas (${previewDates.length} visitas):',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 180),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const ClampingScrollPhysics(),
                                  itemCount: previewDates.length,
                                  separatorBuilder: (_, __) => const Divider(height: 6, thickness: 0.5),
                                  itemBuilder: (context, idx) {
                                    final d = previewDates[idx];
                                    final rawFormatted = previewFormat.format(d);
                                    final formatted = rawFormatted.isNotEmpty
                                        ? '${rawFormatted[0].toUpperCase()}${rawFormatted.substring(1)}'
                                        : '';
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F2B48).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '#${idx + 1}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F2B48),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              formatted,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 5. RECORDATORIOS Y NOTIFICACIONES MÚLTIPLES
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notifications_active, size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Recordatorios y Notificaciones (Alertas)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F2B48)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Toca para activar o desactivar cuántos avisos deseas recibir antes de cada servicio (se sincronizan a Google Calendar para alertarte en tu móvil y PC):',
                    style: TextStyle(fontSize: 11.5, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _reminderOptions.map((opt) {
                      final mins = opt['mins'] as int;
                      final label = opt['label'] as String;
                      final isSelected = _selectedReminderMinutes.contains(mins);
                      return FilterChip(
                        label: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0F2B48),
                        checkmarkColor: Colors.white,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: isSelected ? const Color(0xFF0F2B48) : Colors.grey.shade400),
                        ),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedReminderMinutes.add(mins);
                            } else {
                              if (_selectedReminderMinutes.length > 1) {
                                _selectedReminderMinutes.remove(mins);
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 6. NOTAS / OBSERVACIONES
            const Text('6. Notas / Motivo de la Visita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: isProspect
                    ? 'Ej. Primera visita para cotizar. Problemas con cucaracha americana en cocina.'
                    : 'Ej. Acceso por puerta trasera, preguntar por Don Mario.',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),

            // 7. GOOGLE CALENDAR SYNC
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sync, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Sincronizar con Google Calendar',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F2B48)),
                        ),
                      ),
                      Switch(
                        value: _syncGoogleCalendar,
                        activeColor: const Color(0xFF0F2B48),
                        onChanged: (val) => setState(() => _syncGoogleCalendar = val),
                      ),
                    ],
                  ),
                  const Text(
                    'Se añadirá automáticamente al calendario de tu cuenta Google en el móvil y se reflejará en tiempo real en tu PC (Google Chrome en calendar.google.com) con los recordatorios elegidos.',
                    style: TextStyle(fontSize: 11.5, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // BOTÓN GUARDAR
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2B48),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline, size: 22),
                label: Text(
                  _isSaving
                      ? 'Agendando y sincronizando...'
                      : (isProspect ? 'AGENDAR VISITA PROSPECTO' : 'AGENDAR EN CALENDARIO'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
                onPressed: _isSaving ? null : _saveAppointment,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
