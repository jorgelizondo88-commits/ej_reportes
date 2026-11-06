import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/schedule_model.dart';
import '../../services/calendar_sync_service.dart';
import '../../services/launcher_service.dart';
import '../../services/notification_service.dart';
import 'quick_appointment_screen.dart';
import 'schedule_preview_screen.dart';

class ScheduleHistoryScreen extends StatefulWidget {
  final int initialTab;

  const ScheduleHistoryScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<ScheduleHistoryScreen> createState() => _ScheduleHistoryScreenState();
}

class _ScheduleHistoryScreenState extends State<ScheduleHistoryScreen> with SingleTickerProviderStateMixin {
  static const String _schedulesHistoryKey = 'ej_schedules_history_list';

  late TabController _tabController;
  final CalendarSyncService _calendarSyncService = CalendarSyncService();

  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _agendaFilter = 'Todas'; // 'Todas', '🎯 Prospectos', 'Pendientes', 'Realizadas', 'Este Mes'

  // Variables para la Vista de Calendario Mensual
  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _loadSchedules();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_schedulesHistoryKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List list = jsonDecode(raw);
        _schedules = list.map((item) => Map<String, dynamic>.from(item)).toList();

        // Enriquecer visitas con datos del cliente si vinieron de versiones anteriores
        for (final s in _schedules) {
          if (s['scheduleData'] != null) {
            final model = ScheduleModel.fromMap(s['scheduleData']);
            bool modified = false;
            for (final v in model.visits) {
              if (v.clientBusinessName.isEmpty && s['businessName'] != null) {
                v.clientBusinessName = s['businessName'];
                modified = true;
              }
              if (v.clientContactName.isEmpty && s['clientName'] != null) {
                v.clientContactName = s['clientName'];
                modified = true;
              }
              if (v.clientPhone.isEmpty && s['phone'] != null) {
                v.clientPhone = s['phone'];
                modified = true;
              }
              if (v.clientAddress.isEmpty && s['clientAddress'] != null) {
                v.clientAddress = s['clientAddress'];
                modified = true;
              }
              if (v.scheduleId == null || v.scheduleId!.isEmpty) {
                v.scheduleId = s['folio'];
                modified = true;
              }
            }
            if (modified) {
              s['scheduleData'] = model.toMap();
            }
          }
        }
      } catch (_) {
        _schedules = [];
      }
    } else {
      _schedules = [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveSchedulesList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_schedulesHistoryKey, jsonEncode(_schedules));
  }

  /// Recopila ÚNICAMENTE las visitas que el usuario decidió incluir en su agenda
  /// (Citas directas, prospectos o pólizas que el usuario marcó para agregar a la agenda)
  List<Map<String, dynamic>> _getAllVisits() {
    final List<Map<String, dynamic>> list = [];
    for (final s in _schedules) {
      // Condición: Solo aparece en la Agenda si el usuario lo decidió explícitamente
      final bool isExplicitlyInAgenda = s['isInAgenda'] == true ||
          (s['scheduleData'] != null && s['scheduleData']['isInAgenda'] == true);
      final bool isSingleAppointment = s['recurrenceType'] == 'single' ||
          s['isProspect'] == true ||
          s['appointmentCategory'] == 'Prospecto' ||
          s['appointmentCategory'] == 'CitaIndividual';

      if ((isExplicitlyInAgenda || isSingleAppointment) && s['scheduleData'] != null) {
        final model = ScheduleModel.fromMap(s['scheduleData']);
        for (final v in model.visits) {
          list.add({
            'schedule': s,
            'model': model,
            'visit': v,
            'date': v.date,
          });
        }
      }
    }
    list.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return list;
  }

  /// Permite al usuario decidir si una póliza/cronograma aparece en la Agenda y Google Calendar
  Future<void> _toggleScheduleInAgenda(Map<String, dynamic> scheduleEntry, bool addToAgenda) async {
    final bName = scheduleEntry['businessName'] ?? 'Cliente';
    final total = scheduleEntry['totalVisits'] ?? 0;

    if (addToAgenda) {
      final syncGoogle = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('¿Agregar $total visitas a la Agenda?'),
          content: Text(
            'Se incluirán las $total visitas de "$bName" en tu Calendario y Agenda de la aplicación.\n\n'
            '¿Deseas también sincronizarlas con Google Calendar para verlas en tu PC y recibir alertas automáticas?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Solo agenda app
              child: const Text('Solo en la App'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2B48), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true), // App + Google Calendar
              child: const Text('Sí, en App y Google Calendar'),
            ),
          ],
        ),
      );

      if (syncGoogle == null) return; // Canceló

      setState(() {
        scheduleEntry['isInAgenda'] = true;
        if (scheduleEntry['scheduleData'] != null) {
          final model = ScheduleModel.fromMap(scheduleEntry['scheduleData']);
          final updated = ScheduleModel(
            id: model.id,
            folio: model.folio,
            createdAt: model.createdAt,
            title: model.title,
            clientBusinessName: model.clientBusinessName,
            clientContactName: model.clientContactName,
            clientPhone: model.clientPhone,
            clientAddress: model.clientAddress,
            clientEmail: model.clientEmail,
            facilityType: model.facilityType,
            isProspect: model.isProspect,
            appointmentCategory: model.appointmentCategory,
            recurrenceType: model.recurrenceType,
            visitsPerMonth: model.visitsPerMonth,
            ordinalWeek: model.ordinalWeek,
            secondOrdinalWeek: model.secondOrdinalWeek,
            weekday: model.weekday,
            fixedDay: model.fixedDay,
            secondFixedDay: model.secondFixedDay,
            durationMonths: model.durationMonths,
            startDate: model.startDate,
            defaultTime: model.defaultTime,
            serviceType: model.serviceType,
            conditions: model.conditions,
            notes: model.notes,
            elaboratedBy: model.elaboratedBy,
            isInAgenda: true,
            visits: model.visits,
          );
          scheduleEntry['scheduleData'] = updated.toMap();
        }
      });

      if (syncGoogle == true && scheduleEntry['scheduleData'] != null) {
        final model = ScheduleModel.fromMap(scheduleEntry['scheduleData']);
        for (final v in model.visits) {
          await _calendarSyncService.syncVisitToGoogleCalendar(v);
        }
        scheduleEntry['scheduleData'] = model.toMap();
      }

      await _saveSchedulesList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncGoogle == true
                  ? '¡Visitas de $bName agregadas a tu Agenda y Google Calendar!'
                  : '¡Visitas de $bName agregadas a tu Agenda!',
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } else {
      // Quitar de la agenda
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Quitar visitas de la Agenda?'),
          content: Text(
            'Las visitas de "$bName" ya no se mostrarán en tu calendario ni en la lista de próximas visitas.\n\n'
            'El documento PDF y la póliza se mantendrán intactos en tu historial.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Quitar de la Agenda'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        if (scheduleEntry['scheduleData'] != null) {
          final model = ScheduleModel.fromMap(scheduleEntry['scheduleData']);
          for (final v in model.visits) {
            await _calendarSyncService.deleteVisitFromGoogleCalendar(v);
          }
        }

        setState(() {
          scheduleEntry['isInAgenda'] = false;
          if (scheduleEntry['scheduleData'] != null) {
            final model = ScheduleModel.fromMap(scheduleEntry['scheduleData']);
            final updated = ScheduleModel(
              id: model.id,
              folio: model.folio,
              createdAt: model.createdAt,
              title: model.title,
              clientBusinessName: model.clientBusinessName,
              clientContactName: model.clientContactName,
              clientPhone: model.clientPhone,
              clientAddress: model.clientAddress,
              clientEmail: model.clientEmail,
              facilityType: model.facilityType,
              isProspect: model.isProspect,
              appointmentCategory: model.appointmentCategory,
              recurrenceType: model.recurrenceType,
              visitsPerMonth: model.visitsPerMonth,
              ordinalWeek: model.ordinalWeek,
              secondOrdinalWeek: model.secondOrdinalWeek,
              weekday: model.weekday,
              fixedDay: model.fixedDay,
              secondFixedDay: model.secondFixedDay,
              durationMonths: model.durationMonths,
              startDate: model.startDate,
              defaultTime: model.defaultTime,
              serviceType: model.serviceType,
              conditions: model.conditions,
              notes: model.notes,
              elaboratedBy: model.elaboratedBy,
              isInAgenda: false,
              visits: model.visits,
            );
            scheduleEntry['scheduleData'] = updated.toMap();
          }
        });

        await _saveSchedulesList();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Visitas de $bName removidas de la Agenda.')),
          );
        }
      }
    }
  }

  /// Cambia el estatus de una visita entre Realizada y Pendiente
  Future<void> _toggleVisitStatus(Map<String, dynamic> scheduleEntry, ScheduledVisit visit) async {
    setState(() {
      if (visit.status == 'Realizada') {
        visit.status = 'Pendiente';
        visit.completedDate = null;
        NotificationService().scheduleVisitReminders(visit);
      } else {
        visit.status = 'Realizada';
        visit.completedDate = DateTime.now();
        NotificationService().cancelVisitReminders(visit);
      }

      final scheduleModel = ScheduleModel.fromMap(scheduleEntry['scheduleData']);
      final vIdx = scheduleModel.visits.indexWhere((v) => v.id == visit.id);
      if (vIdx >= 0) {
        scheduleModel.visits[vIdx] = visit;
        scheduleEntry['scheduleData'] = scheduleModel.toMap();
        scheduleEntry['completedVisits'] = scheduleModel.completedVisits;
      }
    });

    await _saveSchedulesList();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            visit.status == 'Realizada'
                ? '¡Visita de ${visit.clientBusinessName} marcada como REALIZADA!'
                : 'Visita marcada como Pendiente.',
          ),
          backgroundColor: visit.status == 'Realizada' ? Colors.green.shade800 : Colors.blueGrey,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Modifica ÚNICAMENTE la fecha y/o la hora de una visita específica (sin afectar la serie)
  Future<void> _editSingleVisitDateTime(Map<String, dynamic> scheduleEntry, ScheduledVisit visit) async {
    final fullFormat = DateFormat('dd/MM/yyyy');
    DateTime newDate = visit.date;
    TimeOfDay newTime = _calendarSyncService.parseTimeString(visit.time);
    final notesController = TextEditingController(text: visit.notes);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_calendar, color: Color(0xFF0F2B48)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Modificar Fecha y Hora', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cliente: ${visit.clientBusinessName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48)),
                ),
                Text('Servicio: ${visit.serviceType}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ℹ️ Este cambio solo modificará la visita de este día. Las demás visitas de la serie se mantendrán intactas.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF0F2B48)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Nueva Fecha:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    alignment: Alignment.centerLeft,
                  ),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(fullFormat.format(newDate)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: newDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDialogState(() => newDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 10),
                const Text('Nuevo Horario:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    alignment: Alignment.centerLeft,
                  ),
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(_formatTimeOfDay(newTime)),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: newTime,
                    );
                    if (picked != null) {
                      setDialogState(() => newTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 10),
                const Text('Observaciones / Motivo de cambio:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Ej. Cliente solicitó moverlo para la tarde...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F2B48), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar Cambio'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final oldEventId = visit.calendarEventId;
      setState(() {
        visit.date = newDate;
        visit.time = _formatTimeOfDay(newTime);
        visit.notes = notesController.text.trim();
        if (visit.status == 'Pendiente') {
          visit.status = 'Reagendada';
        }

        final scheduleModel = ScheduleModel.fromMap(scheduleEntry['scheduleData']);
        final vIdx = scheduleModel.visits.indexWhere((v) => v.id == visit.id);
        if (vIdx >= 0) {
          scheduleModel.visits[vIdx] = visit;
          scheduleEntry['scheduleData'] = scheduleModel.toMap();
        }
      });

      // Sincronizar actualización con Google Calendar
      String? updatedEventId;
      try {
        updatedEventId = await _calendarSyncService.syncVisitToGoogleCalendar(visit);
        if (updatedEventId != null) {
          visit.calendarEventId = updatedEventId;
          final scheduleModel = ScheduleModel.fromMap(scheduleEntry['scheduleData']);
          final vIdx = scheduleModel.visits.indexWhere((v) => v.id == visit.id);
          if (vIdx >= 0) {
            scheduleModel.visits[vIdx] = visit;
            scheduleEntry['scheduleData'] = scheduleModel.toMap();
          }
        }
      } catch (_) {}

      // Actualizar recordatorios y alertas nativas en el dispositivo
      try {
        await NotificationService().cancelVisitReminders(visit);
        if (visit.status != 'Realizada') {
          await NotificationService().scheduleVisitReminders(visit);
        }
      } catch (_) {}

      await _saveSchedulesList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updatedEventId != null || oldEventId != null
                  ? '¡Visita actualizada y sincronizada en Google Calendar!'
                  : '¡Visita reagendada exitosamente!',
            ),
            backgroundColor: const Color(0xFF0F2B48),
          ),
        );
      }
    }
  }

  /// Sincroniza una visita individual a Google Calendar
  Future<void> _syncSingleVisitWithGoogle(Map<String, dynamic> scheduleEntry, ScheduledVisit visit) async {
    final eventId = await _calendarSyncService.syncVisitToGoogleCalendar(visit);
    if (eventId != null) {
      setState(() {
        visit.calendarEventId = eventId;
        final scheduleModel = ScheduleModel.fromMap(scheduleEntry['scheduleData']);
        final vIdx = scheduleModel.visits.indexWhere((v) => v.id == visit.id);
        if (vIdx >= 0) {
          scheduleModel.visits[vIdx] = visit;
          scheduleEntry['scheduleData'] = scheduleModel.toMap();
        }
      });
      await _saveSchedulesList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('¡Visita sincronizada en tu Google Calendar!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo sincronizar. Verifica los permisos de calendario de tu teléfono.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Sincroniza todas las visitas pendientes de la agenda con Google Calendar
  Future<void> _syncAllPendingVisits() async {
    final allVisits = _getAllVisits();
    final pending = allVisits.where((item) {
      final v = item['visit'] as ScheduledVisit;
      return v.status != 'Cancelada';
    }).toList();

    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay visitas pendientes en la agenda para sincronizar.')),
      );
      return;
    }

    int syncedCount = 0;
    for (final item in pending) {
      final s = item['schedule'] as Map<String, dynamic>;
      final v = item['visit'] as ScheduledVisit;
      final eventId = await _calendarSyncService.syncVisitToGoogleCalendar(v);
      if (eventId != null) {
        v.calendarEventId = eventId;
        final scheduleModel = ScheduleModel.fromMap(s['scheduleData']);
        final vIdx = scheduleModel.visits.indexWhere((x) => x.id == v.id);
        if (vIdx >= 0) {
          scheduleModel.visits[vIdx] = v;
          s['scheduleData'] = scheduleModel.toMap();
        }
        syncedCount++;
      }
    }

    await _saveSchedulesList();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡$syncedCount visitas sincronizadas con Google Calendar!'),
          backgroundColor: const Color(0xFF0F2B48),
        ),
      );
    }
  }

  /// Elimina una visita individual (y la borra de Google Calendar)
  Future<void> _deleteSingleVisit(Map<String, dynamic> scheduleEntry, ScheduledVisit visit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Visita?'),
        content: Text(
          'Se eliminará la visita de "${visit.clientBusinessName}" agendada para el '
          '${DateFormat('dd/MM/yyyy').format(visit.date)} a las ${visit.time}.\n\n'
          'Si está en Google Calendar, también se eliminará automáticamente de tu cuenta de Google.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _calendarSyncService.deleteVisitFromGoogleCalendar(visit);
      try {
        await NotificationService().cancelVisitReminders(visit);
      } catch (_) {}

      setState(() {
        final scheduleModel = ScheduleModel.fromMap(scheduleEntry['scheduleData']);
        scheduleModel.visits.removeWhere((v) => v.id == visit.id);

        if (scheduleModel.visits.isEmpty) {
          _schedules.remove(scheduleEntry);
        } else {
          scheduleEntry['scheduleData'] = scheduleModel.toMap();
          scheduleEntry['totalVisits'] = scheduleModel.totalVisits;
          scheduleEntry['completedVisits'] = scheduleModel.completedVisits;
        }
      });

      await _saveSchedulesList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visita eliminada de la agenda y de Google Calendar.')),
        );
      }
    }
  }

  /// Enviar recordatorio profesional por WhatsApp al cliente
  void _sendWhatsAppReminder(ScheduledVisit visit) {
    if (visit.clientPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este cliente no tiene registrado un número telefónico.')),
      );
      return;
    }

    final dateStr = DateFormat('EEEE, dd \'de\' MMMM', 'es_MX').format(visit.date);
    final clientName = visit.clientContactName.isNotEmpty ? visit.clientContactName : visit.clientBusinessName;

    final message = '''
🛡️ *EJ EXTERMINADORES - RECORDATORIO DE SERVICIO*

Hola *$clientName*, le saludamos de EJ Exterminadores.
Le confirmamos su servicio programado:

📅 *Fecha:* $dateStr
⏰ *Horario:* ${visit.time}
🔧 *Servicio:* ${visit.serviceType}
📍 *Ubicación:* ${visit.clientAddress}

¿Nos confirma su recepción para el día y hora acordados?
¡Muchas gracias y quedamos a sus órdenes!
''';

    LauncherService.openWhatsApp(phone: visit.clientPhone, message: message.trim());
  }

  /// Eliminar un cronograma completo
  Future<void> _deleteSchedule(int index) async {
    final schedule = _schedules[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Cronograma?'),
        content: Text(
          'Se eliminará la calendarización #${schedule['folio']} de ${schedule['businessName']} y todas sus visitas asociadas.\n\n'
          'Las visitas agendadas en Google Calendar también serán eliminadas.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar Todo'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (schedule['scheduleData'] != null) {
        final model = ScheduleModel.fromMap(schedule['scheduleData']);
        for (final v in model.visits) {
          await _calendarSyncService.deleteVisitFromGoogleCalendar(v);
        }
      }

      if (schedule['filePath'] != null) {
        try {
          final file = File(schedule['filePath']);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }

      setState(() {
        _schedules.removeAt(index);
      });
      await _saveSchedulesList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cronograma y visitas eliminados exitosamente.')),
        );
      }
    }
  }

  void _openSchedulePdf(Map<String, dynamic> entry) async {
    if (entry['scheduleData'] != null) {
      final model = ScheduleModel.fromMap(entry['scheduleData']);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SchedulePreviewScreen(schedule: model)),
      );
    } else if (entry['filePath'] != null && File(entry['filePath']).existsSync()) {
      final file = File(entry['filePath']);
      final folio = (entry['folio'] ?? '').toString().trim();
      final client = (entry['businessName'] ?? '').toString().trim();
      final cleanFolio = folio.replaceAll(RegExp(r'[^\w-]'), '_');
      final cleanClient = client
          .replaceAll(RegExp(r'[^\wáéíóúÁÉÍÓÚñÑ\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_');
      final fileName = cleanClient.isEmpty ? 'Cronograma_$cleanFolio.pdf' : 'Cronograma_${cleanFolio}_$cleanClient.pdf';

      try {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        await file.copy(tempFile.path);
        await Share.shareXFiles([XFile(tempFile.path, name: fileName)]);
      } catch (_) {
        await Share.shareXFiles([XFile(entry['filePath'])]);
      }
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda y Calendario', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Probar / Permisos de Notificaciones',
            onPressed: () async {
              final granted = await NotificationService().requestPermission();
              if (granted && mounted) {
                await NotificationService().showTestNotification();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('¡Notificación de prueba enviada con el logo de EJ Exterminadores!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor permite las notificaciones en la ventana emergente o en Ajustes.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar todo con Google Calendar',
            onPressed: _syncAllPendingVisits,
          ),
          IconButton(
            icon: const Icon(Icons.folder_shared_outlined),
            tooltip: 'Ver Pólizas y Cronogramas (PDF)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Pólizas y Cronogramas (PDF)'),
                      backgroundColor: const Color(0xFF0F2B48),
                      foregroundColor: Colors.white,
                    ),
                    body: _buildSchedulesTab(),
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month), text: 'Calendario Mes'),
            Tab(icon: Icon(Icons.event_note), text: 'Agenda Visitas'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agendar Cita / Servicio'),
        onPressed: () => _openQuickAppointment(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: CALENDARIO MENSUAL INTERACTIVO
                _buildCalendarMonthTab(),

                // TAB 2: AGENDA DE VISITAS (LISTA CRONOLÓGICA)
                _buildAgendaTab(),
              ],
            ),
    );
  }

  Future<void> _openQuickAppointment({bool isProspect = false, DateTime? date}) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuickAppointmentScreen(
          initialIsProspect: isProspect,
          initialDate: date ?? _selectedDay,
        ),
      ),
    );
    if (res == true) _loadSchedules();
  }

  // ===========================================================================
  // TAB 1: CALENDARIO MENSUAL INTERACTIVO
  // ===========================================================================

  Widget _buildCalendarMonthTab() {
    final allVisits = _getAllVisits();
    final monthFormat = DateFormat('MMMM yyyy', 'es_MX');
    final dayOfWeekFormat = DateFormat('EEEE, d \'de\' MMMM', 'es_MX');

    // Visitas del día seleccionado
    final selectedDayVisits = allVisits.where((item) {
      final d = item['date'] as DateTime;
      return d.year == _selectedDay.year && d.month == _selectedDay.month && d.day == _selectedDay.day;
    }).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    // Widget del calendario (Selector + Días de la semana + Grid)
    Widget buildCalendarCard({double aspectRatio = 1.35}) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: isDesktop ? Border.all(color: const Color(0xFFE2E8F0)) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Selector de Mes
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: isDesktop ? const BorderRadius.vertical(top: Radius.circular(9)) : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Color(0xFF0F2B48), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                      });
                    },
                  ),
                  Row(
                    children: [
                      Text(
                        monthFormat.format(_focusedMonth).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F2B48)),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          final now = DateTime.now();
                          setState(() {
                            _focusedMonth = DateTime(now.year, now.month, 1);
                            _selectedDay = DateTime(now.year, now.month, now.day);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F2B48),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Hoy', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Color(0xFF0F2B48), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                      });
                    },
                  ),
                ],
              ),
            ),

            // 2. Encabezados de Días (Dom, Lun...)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  Text('Dom', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.redAccent)),
                  Text('Lun', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
                  Text('Mar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
                  Text('Mié', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
                  Text('Jue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
                  Text('Vie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
                  Text('Sáb', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
                ],
              ),
            ),

            // 3. Grid de Días Compacto
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: _buildMonthDaysGrid(allVisits, childAspectRatio: aspectRatio),
            ),

            // Leyenda de puntos compacta
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendDot(Colors.orange, 'Prospecto'),
                  const SizedBox(width: 12),
                  _legendDot(const Color(0xFF0F2B48), 'Pendiente'),
                  const SizedBox(width: 12),
                  _legendDot(Colors.green, 'Realizada'),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Widget del detalle de visitas para el día seleccionado
    Widget buildDayVisitsPane() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: isDesktop ? Colors.white : Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    dayOfWeekFormat.format(_selectedDay),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F2B48)),
                  ),
                ),
                Text(
                  '${selectedDayVisits.length} ${selectedDayVisits.length == 1 ? 'visita' : 'visitas'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final res = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuickAppointmentScreen(initialDate: _selectedDay),
                      ),
                    );
                    if (res == true) _loadSchedules();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2B48).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: Color(0xFF0F2B48)),
                        Text(' Agendar aquí', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop) const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 6),
          Expanded(
            child: selectedDayVisits.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available, size: 44, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text('No hay visitas programadas para este día.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF0F2B48))),
                          icon: const Icon(Icons.add, size: 16, color: Color(0xFF0F2B48)),
                          label: const Text('Agendar servicio para hoy', style: TextStyle(color: Color(0xFF0F2B48))),
                          onPressed: () async {
                            final res = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => QuickAppointmentScreen(initialDate: _selectedDay)),
                            );
                            if (res == true) _loadSchedules();
                          },
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                    itemCount: selectedDayVisits.length,
                    itemBuilder: (context, idx) {
                      final item = selectedDayVisits[idx];
                      return _buildVisitCard(item);
                    },
                  ),
          ),
        ],
      );
    }

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 380,
              child: buildCalendarCard(aspectRatio: 1.35),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: buildDayVisitsPane(),
              ),
            ),
          ],
        ),
      );
    }

    // Modo móvil / estrecho
    return Column(
      children: [
        buildCalendarCard(aspectRatio: 1.6),
        const Divider(height: 8),
        Expanded(child: buildDayVisitsPane()),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
      ],
    );
  }

  /// Construye la matriz de días del mes con sus indicadores
  Widget _buildMonthDaysGrid(List<Map<String, dynamic>> allVisits, {double childAspectRatio = 1.35}) {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;

    final startOffset = firstDayOfMonth.weekday % 7;
    final totalCells = ((startOffset + daysInMonth + 6) ~/ 7) * 7;

    final now = DateTime.now();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        final dayNum = index - startOffset + 1;
        if (dayNum < 1 || dayNum > daysInMonth) {
          return const SizedBox.shrink();
        }

        final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
        final isToday = cellDate.year == now.year && cellDate.month == now.month && cellDate.day == now.day;
        final isSelected = cellDate.year == _selectedDay.year && cellDate.month == _selectedDay.month && cellDate.day == _selectedDay.day;

        // Buscar visitas de este día
        final visitsOfDay = allVisits.where((item) {
          final d = item['date'] as DateTime;
          return d.year == cellDate.year && d.month == cellDate.month && d.day == cellDate.day;
        }).toList();

        final hasProspect = visitsOfDay.any((item) => (item['visit'] as ScheduledVisit).isProspect);
        final hasCompleted = visitsOfDay.any((item) => (item['visit'] as ScheduledVisit).status == 'Realizada');
        final hasPending = visitsOfDay.any((item) => (item['visit'] as ScheduledVisit).status != 'Realizada');

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _selectedDay = cellDate;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF0F2B48)
                  : (isToday ? Colors.amber.shade100 : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected
                  ? Border.all(color: Colors.amber.shade800, width: 1.5)
                  : (visitsOfDay.isNotEmpty && !isSelected
                      ? Border.all(color: Colors.grey.shade300)
                      : null),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNum',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : (index % 7 == 0 ? Colors.redAccent : Colors.black87),
                  ),
                ),
                if (visitsOfDay.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasProspect)
                        Container(
                          width: 4.5,
                          height: 4.5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.amberAccent : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (hasPending)
                        Container(
                          width: 4.5,
                          height: 4.5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.lightBlueAccent : const Color(0xFF0F2B48),
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (hasCompleted)
                        Container(
                          width: 4.5,
                          height: 4.5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.lightGreenAccent : Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TARJETA DE VISITA (REDiseñada: Botones amplios sin recortes)
  // ===========================================================================

  Widget _buildVisitCard(Map<String, dynamic> item) {
    final s = item['schedule'] as Map<String, dynamic>;
    final v = item['visit'] as ScheduledVisit;
    final isDone = v.status == 'Realizada';
    final isProspect = v.isProspect;
    final hasGoogleCalendar = v.calendarEventId != null && v.calendarEventId!.isNotEmpty;

    final clientName = v.clientBusinessName.isNotEmpty ? v.clientBusinessName : (s['businessName'] ?? 'Cliente');
    final contactName = v.clientContactName.isNotEmpty ? v.clientContactName : (s['clientName'] ?? '');
    final phone = v.clientPhone.isNotEmpty ? v.clientPhone : (s['phone'] ?? '');
    final address = v.clientAddress.isNotEmpty ? v.clientAddress : (s['clientAddress'] ?? '');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Categoría + Indicador Google + Estatus
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isProspect
                          ? Colors.orange.shade50
                          : (v.serviceType.contains('Inspecc') ? Colors.purple.shade50 : const Color(0xFF0F2B48).withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isProspect
                            ? Colors.orange.shade300
                            : (v.serviceType.contains('Inspecc') ? Colors.purple.shade200 : const Color(0xFF0F2B48).withValues(alpha: 0.2)),
                      ),
                    ),
                    child: Text(
                      isProspect
                          ? '🎯 Prospecto / 1ra Visita'
                          : (v.serviceType.contains('Inspecc')
                              ? '🔍 Inspección'
                              : (v.visitNumber > 0 ? '🛡️ Visita #${v.visitNumber}' : '🛡️ Servicio')),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isProspect ? Colors.orange.shade900 : (v.serviceType.contains('Inspecc') ? Colors.purple.shade900 : const Color(0xFF0F2B48)),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasGoogleCalendar)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month, size: 12, color: Colors.blue.shade800),
                            const SizedBox(width: 3),
                            Text('Google Cal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDone ? Colors.green.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDone ? Colors.green.shade300 : Colors.amber.shade300),
                      ),
                      child: Text(
                        isDone ? 'Realizada ✓' : v.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDone ? Colors.green.shade900 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Nombre del Cliente y Horario
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F2B48)),
                      ),
                      if (contactName.isNotEmpty && contactName != clientName) ...[
                        const SizedBox(height: 2),
                        Text('Contacto: $contactName', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Color(0xFF0F2B48)),
                      const SizedBox(width: 5),
                      Text(v.time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F2B48))),
                    ],
                  ),
                ),
              ],
            ),

            if (address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on, size: 15, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(address, style: TextStyle(fontSize: 12, color: Colors.grey.shade800), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],

            if (v.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Notas: ${v.notes}', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade700)),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // FILA 1 DE HERRAMIENTAS: Contacto y Google Calendar
            Row(
              children: [
                if (phone.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.green.shade800,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.chat, size: 16),
                    label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _sendWhatsAppReminder(v),
                  ),
                if (phone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone, size: 18, color: Color(0xFF0F2B48)),
                    tooltip: 'Llamar al cliente',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => LauncherService.makePhoneCall(phone),
                  ),
                if (address.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.map_outlined, size: 18, color: Colors.blueAccent),
                    tooltip: 'Ver ubicación en Google Maps',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => LauncherService.openMap(address),
                  ),
                const Spacer(),
                if (!hasGoogleCalendar)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.blue.shade800,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    icon: const Icon(Icons.sync, size: 15),
                    label: const Text('+ Google Cal', style: TextStyle(fontSize: 11.5)),
                    onPressed: () => _syncSingleVisitWithGoogle(s, v),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  tooltip: 'Eliminar esta visita',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deleteSingleVisit(s, v),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // FILA 2 DE ACCIONES PRINCIPALES: Botones Amplios (Nunca amontonados ni cortados)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFF0F2B48)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.edit_calendar, size: 16, color: Color(0xFF0F2B48)),
                    label: const Text(
                      'Cambiar fecha',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                    ),
                    onPressed: () => _editSingleVisitDateTime(s, v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDone ? Colors.green.shade700 : const Color(0xFF0F2B48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(isDone ? Icons.undo : Icons.check_circle_outline, size: 16),
                    label: Text(
                      isDone ? 'Realizada ✓' : 'Marcar Realizada',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _toggleVisitStatus(s, v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: AGENDA DE TODAS LAS VISITAS (LISTA CRONOLÓGICA CON FILTROS)
  // ===========================================================================

  Widget _buildAgendaTab() {
    final allVisits = _getAllVisits();
    final now = DateTime.now();

    final filtered = allVisits.where((item) {
      final v = item['visit'] as ScheduledVisit;
      final d = item['date'] as DateTime;
      final s = item['schedule'] as Map<String, dynamic>;

      if (_agendaFilter == '🎯 Prospectos' && !v.isProspect) return false;
      if (_agendaFilter == 'Pendientes' && v.status != 'Pendiente' && v.status != 'Reagendada') return false;
      if (_agendaFilter == 'Realizadas' && v.status != 'Realizada') return false;
      if (_agendaFilter == 'Este Mes' && (d.month != now.month || d.year != now.year)) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final bName = (v.clientBusinessName.isNotEmpty ? v.clientBusinessName : (s['businessName'] ?? '')).toString().toLowerCase();
        final cName = (v.clientContactName.isNotEmpty ? v.clientContactName : (s['clientName'] ?? '')).toString().toLowerCase();
        final phone = (v.clientPhone.isNotEmpty ? v.clientPhone : (s['phone'] ?? '')).toString().toLowerCase();
        final folio = (v.scheduleId ?? s['folio'] ?? '').toString().toLowerCase();
        return bName.contains(q) || cName.contains(q) || phone.contains(q) || folio.contains(q);
      }

      return true;
    }).toList();

    return Column(
      children: [
        // Buscador
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por cliente, prospecto, teléfono o folio...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
        ),

        // Filtros rápidos
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: ['Todas', '🎯 Prospectos', 'Este Mes', 'Pendientes', 'Realizadas'].map((filter) {
              final isSel = _agendaFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter, style: TextStyle(color: isSel ? Colors.white : Colors.black87, fontSize: 12)),
                  selected: isSel,
                  selectedColor: const Color(0xFF0F2B48),
                  checkmarkColor: Colors.white,
                  onSelected: (_) => setState(() => _agendaFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No se encontraron resultados para "$_searchQuery".'
                            : 'No hay visitas en tu agenda con el filtro "$_agendaFilter".',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    return _buildVisitCard(item);
                  },
                ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: PÓLIZAS Y CRONOGRAMAS COMPLETOS (CONTRATOS Y PDF)
  // ===========================================================================

  Widget _buildSchedulesTab() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final filteredSchedules = _schedules.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final folio = (s['folio'] ?? '').toString().toLowerCase();
      final bName = (s['businessName'] ?? '').toString().toLowerCase();
      final cName = (s['clientName'] ?? '').toString().toLowerCase();
      return folio.contains(q) || bName.contains(q) || cName.contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por cliente o folio (#EJ-CAL)...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
        ),

        Expanded(
          child: filteredSchedules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Aún no tienes cronogramas guardados.'
                            : 'No se encontraron resultados para "$_searchQuery".',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                  itemCount: filteredSchedules.length,
                  itemBuilder: (context, idx) {
                    final item = filteredSchedules[idx];
                    final total = item['totalVisits'] ?? 0;
                    final completed = item['completedVisits'] ?? 0;
                    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
                    final isComplete = total > 0 && completed == total;
                    final created = DateTime.tryParse(item['createdAt'] ?? '') ?? DateTime.now();
                    final inAgenda = item['isInAgenda'] == true ||
                        (item['scheduleData'] != null && item['scheduleData']['isInAgenda'] == true);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F2B48).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#${item['folio']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2B48)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isComplete ? Colors.green.shade50 : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isComplete ? Colors.green.shade300 : Colors.blue.shade300),
                                  ),
                                  child: Text(
                                    isComplete ? 'Completado ✓' : '$completed de $total visitas',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isComplete ? Colors.green.shade800 : Colors.blue.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['businessName']?.isNotEmpty == true ? item['businessName'] : (item['clientName'] ?? 'Cliente'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                            ),
                            if (item['clientName']?.isNotEmpty == true && item['clientName'] != item['businessName']) ...[
                              const SizedBox(height: 2),
                              Text('Contacto: ${item['clientName']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'Regla: ${item['recurrenceDescription'] ?? 'Mensual'}',
                              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            // Barra de progreso
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade200,
                                color: isComplete ? Colors.green : const Color(0xFF0F2B48),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // BOTÓN DE CONTROL: ¿Está en la Agenda o no?
                            SizedBox(
                              width: double.infinity,
                              child: inAgenda
                                  ? OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.green.shade800,
                                        side: BorderSide(color: Colors.green.shade400),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      icon: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                      label: Text('En tu Agenda ($total visitas) • Toca para Quitar', style: const TextStyle(fontSize: 11.5)),
                                      onPressed: () => _toggleScheduleInAgenda(item, false),
                                    )
                                  : ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0F2B48),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      icon: const Icon(Icons.add_task, size: 16),
                                      label: Text('+ Agregar las $total visitas a mi Agenda', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                      onPressed: () => _toggleScheduleInAgenda(item, true),
                                    ),
                            ),
                            const SizedBox(height: 8),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Emisión: ${dateFormat.format(created)}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.list_alt, size: 20, color: Color(0xFF0F2B48)),
                                      tooltip: 'Gestionar Visitas',
                                      onPressed: () => _manageVisitsBottomSheet(item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: Color(0xFF0F2B48)),
                                      tooltip: 'Ver PDF',
                                      onPressed: () => _openSchedulePdf(item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                      tooltip: 'Eliminar',
                                      onPressed: () => _deleteSchedule(idx),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _manageVisitsBottomSheet(Map<String, dynamic> entry) {
    final model = ScheduleModel.fromMap(entry['scheduleData']);
    final fullFormat = DateFormat('EEEE, dd \'de\' MMMM \'de\' yyyy', 'es_MX');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                        Text('Visitas de #${entry['folio']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F2B48))),
                        Text('${entry['businessName']} • ${model.completedVisits} de ${model.totalVisits} realizadas',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.separated(
                  itemCount: model.visits.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final v = model.visits[idx];
                    final isDone = v.status == 'Realizada';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: isDone ? Colors.green.shade100 : Colors.grey.shade200,
                        child: Icon(
                          isDone ? Icons.check_circle : Icons.schedule,
                          color: isDone ? Colors.green.shade800 : Colors.grey.shade600,
                        ),
                      ),
                      title: Text(
                        'Visita #${v.visitNumber} • ${fullFormat.format(v.date)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDone ? Colors.green.shade900 : Colors.black87,
                        ),
                      ),
                      subtitle: Text('${v.time} • ${v.serviceType}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_calendar, size: 18),
                            tooltip: 'Cambiar fecha de esta visita',
                            onPressed: () async {
                              await _editSingleVisitDateTime(entry, v);
                              setModalState(() {});
                            },
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDone ? Colors.green.shade700 : const Color(0xFF0F2B48),
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            child: Text(isDone ? 'Realizada ✓' : 'Marcar'),
                            onPressed: () async {
                              await _toggleVisitStatus(entry, v);
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
