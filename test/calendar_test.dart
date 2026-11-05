import 'package:flutter_test/flutter_test.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:ej_reportes/models/schedule_model.dart';
import 'package:ej_reportes/services/calendar_sync_service.dart';

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  test('Event with reminders', () {
    final now = DateTime.now();
    final location = tz.local;
    final start = tz.TZDateTime.from(now, location);
    final end = start.add(const Duration(hours: 1));

    final event = Event(
      'calendar_id_123',
      title: '🛡️ EJ Exterminadores: Visita #1 - Cliente Prueba',
      description: 'Servicio de Control de Plagas\nTel: 8112345678',
      location: 'Calle Principal 123',
      start: start,
      end: end,
    );

    event.reminders = [
      Reminder(minutes: 2880), // 2 días antes
      Reminder(minutes: 60),   // 1 hora antes
    ];

    expect(event.reminders!.length, equals(2));
    expect(event.reminders!.first.minutes, equals(2880));
  });

  test('CalendarSyncService parseTimeString tests', () {
    final service = CalendarSyncService();
    final t1 = service.parseTimeString('09:30 AM');
    expect(t1.hour, equals(9));
    expect(t1.minute, equals(30));

    final t2 = service.parseTimeString('04:15 PM');
    expect(t2.hour, equals(16));
    expect(t2.minute, equals(15));

    final t3 = service.parseTimeString('12:00 PM');
    expect(t3.hour, equals(12));
    expect(t3.minute, equals(0));

    final t4 = service.parseTimeString('12:30 AM');
    expect(t4.hour, equals(0));
    expect(t4.minute, equals(30));
  });

  test('Prospect and Standalone ScheduledVisit model verification', () {
    final visit = ScheduledVisit(
      id: 'visit_test_1',
      visitNumber: 1,
      date: DateTime(2026, 11, 15),
      time: '10:00 AM',
      serviceType: 'Prospección / Levantamiento Técnico',
      isProspect: true,
      clientBusinessName: 'Colegio Monterrey',
      clientPhone: '8180001122',
      clientAddress: 'Av. Las Palmas 500',
    );

    expect(visit.isProspect, isTrue);
    expect(visit.calendarEventId, isNull);

    final map = visit.toMap();
    expect(map['isProspect'], isTrue);
    expect(map['clientBusinessName'], equals('Colegio Monterrey'));

    final restored = ScheduledVisit.fromMap(map);
    expect(restored.isProspect, isTrue);
    expect(restored.clientBusinessName, equals('Colegio Monterrey'));
  });

  test('Recurrence calculation: 1st Sunday of November 2026 is Nov 1', () {
    // 1st Sunday of November 2026
    final year = 2026;
    final month = 11;
    final weekday = 7; // Domingo
    final ordinal = 1;

    final firstOfMonth = DateTime(year, month, 1);
    final daysDiff = (weekday - firstOfMonth.weekday + 7) % 7;
    final day = 1 + daysDiff + (ordinal - 1) * 7;
    final calculatedDate = DateTime(year, month, day);

    expect(calculatedDate.year, equals(2026));
    expect(calculatedDate.month, equals(11));
    expect(calculatedDate.day, equals(1)); // ¡Es exactamente 1 de Noviembre!

    // 1st Saturday of November 2026 (weekday = 6)
    final satDaysDiff = (6 - firstOfMonth.weekday + 7) % 7;
    final satDay = 1 + satDaysDiff + (1 - 1) * 7;
    expect(DateTime(2026, 11, satDay).day, equals(7)); // 1er Sábado es Nov 7

    // 2nd Sunday of November 2026 (ordinal = 2, weekday = 7)
    final sun2Day = 1 + daysDiff + (2 - 1) * 7;
    expect(DateTime(2026, 11, sun2Day).day, equals(8)); // 2do Domingo es Nov 8
  });

  test('ScheduledVisit supports multiple customizable reminder alerts', () {
    final visit = ScheduledVisit(
      id: 'visit_reminders_test',
      visitNumber: 1,
      date: DateTime(2026, 11, 20),
      time: '11:00 AM',
      serviceType: 'Servicio de Control de Plagas',
      clientBusinessName: 'Empresa Test',
      reminderMinutes: [10080, 4320, 2880, 120], // 1 semana, 3 días, 2 días, 2 horas
    );

    expect(visit.reminderMinutes.length, equals(4));
    expect(visit.reminderMinutes, contains(10080)); // 1 semana antes
    expect(visit.reminderMinutes, contains(2880));  // 2 días antes

    final map = visit.toMap();
    expect(map['reminderMinutes'], equals([10080, 4320, 2880, 120]));

    final fromMap = ScheduledVisit.fromMap(map);
    expect(fromMap.reminderMinutes, equals([10080, 4320, 2880, 120]));
  });
}
