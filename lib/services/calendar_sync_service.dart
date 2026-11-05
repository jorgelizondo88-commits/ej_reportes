import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/schedule_model.dart';

class CalendarSyncService {
  static final CalendarSyncService _instance = CalendarSyncService._internal();
  factory CalendarSyncService() => _instance;

  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  bool _timeZoneInitialized = false;

  CalendarSyncService._internal() {
    _initTimeZone();
  }

  void _initTimeZone() {
    if (!_timeZoneInitialized) {
      try {
        tz.initializeTimeZones();
        _timeZoneInitialized = true;
      } catch (_) {}
    }
  }

  /// Verifica o solicita permisos para acceder al calendario
  Future<bool> checkOrRequestPermissions() async {
    _initTimeZone();
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && (permissionsGranted.data == true)) {
        return true;
      }
      permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      return permissionsGranted.isSuccess && (permissionsGranted.data == true);
    } catch (_) {
      return false;
    }
  }

  /// Obtiene el calendario principal de Google o el predeterminado del teléfono
  Future<Calendar?> getPrimaryCalendar() async {
    try {
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data == null || calendarsResult.data!.isEmpty) {
        return null;
      }

      final list = calendarsResult.data!;

      // 1. Buscar primero la cuenta Google (@gmail.com o accountName con 'google') no de solo lectura
      for (final cal in list) {
        final acc = (cal.accountName ?? '').toLowerCase();
        final name = (cal.name ?? '').toLowerCase();
        if (cal.isReadOnly == false && (acc.contains('gmail') || acc.contains('google') || name.contains('google'))) {
          return cal;
        }
      }

      // 2. Buscar calendario predeterminado no de solo lectura
      for (final cal in list) {
        if (cal.isReadOnly == false && cal.isDefault == true) {
          return cal;
        }
      }

      // 3. Primer calendario modificable
      for (final cal in list) {
        if (cal.isReadOnly == false) {
          return cal;
        }
      }

      return list.first;
    } catch (_) {
      return null;
    }
  }

  /// Parsea la hora en formato '09:00 AM' o '15:30' a TimeOfDay
  TimeOfDay parseTimeString(String timeStr) {
    try {
      final trimmed = timeStr.trim();
      final isPm = trimmed.toUpperCase().contains('PM');
      final isAm = trimmed.toUpperCase().contains('AM');
      final clean = trimmed.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = clean.split(':');
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  /// Sincroniza (crea o actualiza) una visita individual en Google Calendar
  Future<String?> syncVisitToGoogleCalendar(
    ScheduledVisit visit, {
    String? clientNameOverride,
    String? phoneOverride,
    String? addressOverride,
    String? notesOverride,
    List<int>? customReminderMinutes,
  }) async {
    _initTimeZone();
    try {
      final hasPerms = await checkOrRequestPermissions();
      if (!hasPerms) return null;

      final calendar = await getPrimaryCalendar();
      if (calendar == null || calendar.id == null) return null;

      final time = parseTimeString(visit.time);
      final startDt = DateTime(
        visit.date.year,
        visit.date.month,
        visit.date.day,
        time.hour,
        time.minute,
      );

      final location = tz.local;
      final tzStart = tz.TZDateTime.from(startDt, location);
      final tzEnd = tzStart.add(const Duration(hours: 1, minutes: 30));

      final clientName = clientNameOverride?.isNotEmpty == true
          ? clientNameOverride!
          : (visit.clientBusinessName.isNotEmpty
              ? visit.clientBusinessName
              : (visit.clientContactName.isNotEmpty ? visit.clientContactName : 'Cliente'));

      final phone = phoneOverride ?? visit.clientPhone;
      final address = addressOverride ?? visit.clientAddress;
      final notes = notesOverride ?? visit.notes;

      // Título con emojis descriptivos
      String prefix;
      if (visit.isProspect) {
        prefix = '🎯 EJ Exterminadores: 1ra Visita Prospecto';
      } else if (visit.serviceType.toLowerCase().contains('inspecc')) {
        prefix = '🔍 EJ Exterminadores: Inspección Inicial';
      } else if (visit.serviceType.toLowerCase().contains('residencial') || visit.serviceType.toLowerCase().contains('casa')) {
        prefix = '🏠 EJ Exterminadores: Servicio Residencial';
      } else {
        prefix = '🛡️ EJ Exterminadores: Visita #${visit.visitNumber}';
      }

      final eventTitle = '$prefix - $clientName';

      // Descripción completa y profesional
      final descBuf = StringBuffer();
      descBuf.writeln('🛡️ EJ EXTERMINADORES - CONTROL PROFESIONAL DE PLAGAS');
      descBuf.writeln('----------------------------------------');
      descBuf.writeln('📋 Cliente: $clientName');
      if (visit.clientContactName.isNotEmpty && visit.clientContactName != clientName) {
        descBuf.writeln('👤 Contacto: ${visit.clientContactName}');
      }
      if (phone.isNotEmpty) {
        descBuf.writeln('📞 Teléfono: $phone');
      }
      if (address.isNotEmpty) {
        descBuf.writeln('📍 Dirección: $address');
      }
      descBuf.writeln('🔧 Servicio: ${visit.serviceType}');
      descBuf.writeln('⏰ Horario: ${visit.time}');
      if (visit.scheduleId != null && visit.scheduleId!.isNotEmpty) {
        descBuf.writeln('📑 Folio: #${visit.scheduleId}');
      }
      if (notes.isNotEmpty) {
        descBuf.writeln('📝 Observaciones: $notes');
      }
      descBuf.writeln('----------------------------------------');
      descBuf.writeln('Contacto Empresa: ventas@ejexterminadores.com');

      final calId = visit.calendarId ?? calendar.id;

      final event = Event(
        calId,
        eventId: visit.calendarEventId,
        title: eventTitle,
        description: descBuf.toString(),
        location: address,
        start: tzStart,
        end: tzEnd,
      );

      // Recordatorios configurables (múltiples alertas: 1 semana, 2 días, 1 día, horas antes, etc.)
      final List<int> reminderMins = customReminderMinutes ??
          (visit.reminderMinutes.isNotEmpty ? visit.reminderMinutes : [2880, 60, 15]);
      event.reminders = reminderMins.map((m) => Reminder(minutes: m)).toList();

      final createResult = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      if (createResult != null && createResult.isSuccess && createResult.data != null) {
        visit.calendarEventId = createResult.data;
        visit.calendarId = calId;
        return createResult.data;
      }
    } catch (e) {
      debugPrint('Error en syncVisitToGoogleCalendar: $e');
    }
    return null;
  }

  /// Elimina una visita de Google Calendar
  Future<bool> deleteVisitFromGoogleCalendar(ScheduledVisit visit) async {
    if (visit.calendarEventId == null || visit.calendarEventId!.isEmpty) {
      return true;
    }
    try {
      final calendarId = visit.calendarId ?? (await getPrimaryCalendar())?.id;
      if (calendarId == null) return false;

      final delResult = await _deviceCalendarPlugin.deleteEvent(calendarId, visit.calendarEventId!);
      if (delResult.isSuccess && delResult.data == true) {
        visit.calendarEventId = null;
        visit.calendarId = null;
        return true;
      }
    } catch (e) {
      debugPrint('Error al eliminar de Google Calendar: $e');
    }
    return false;
  }

  /// Sincroniza una lista de visitas en lote
  Future<int> syncAllVisits(List<ScheduledVisit> visits, {String? businessName, String? phone, String? address}) async {
    int count = 0;
    for (final v in visits) {
      final res = await syncVisitToGoogleCalendar(
        v,
        clientNameOverride: businessName,
        phoneOverride: phone,
        addressOverride: address,
      );
      if (res != null) {
        count++;
      }
    }
    return count;
  }
}
