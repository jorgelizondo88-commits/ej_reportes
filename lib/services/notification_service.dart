import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/schedule_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  NotificationService._internal();

  /// Inicializa el servicio de notificaciones y zonas horarias
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
    } catch (_) {}

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notificación tocada: ${response.payload}');
      },
    );

    _isInitialized = true;
  }

  /// Solicita explícitamente los permisos de notificación al usuario (Android 13+ e iOS)
  Future<bool> requestPermission() async {
    await init();
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }

      final IOSFlutterLocalNotificationsPlugin? iosImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

      if (iosImplementation != null) {
        final bool? granted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error solicitando permisos de notificación: $e');
    }
    return false;
  }

  /// Verifica si las notificaciones están permitidas
  Future<bool> areNotificationsEnabled() async {
    await init();
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final bool? enabled = await androidImplementation.areNotificationsEnabled();
        return enabled ?? false;
      }
    } catch (_) {}
    return true;
  }

  /// Lanza una notificación de prueba instantánea con el logotipo de EJ Exterminadores
  Future<void> showTestNotification() async {
    await init();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ej_alerts_channel',
      'Recordatorios de Servicios',
      channelDescription: 'Alertas y recordatorios programados de servicios y visitas.',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      color: Color(0xFF0F2B48),
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    await _notificationsPlugin.show(
      99999,
      '🛡️ EJ Exterminadores',
      '¡Notificaciones activadas correctamente! Recibirás tus recordatorios antes de cada servicio.',
      details,
    );
  }

  /// Programa las alertas automáticas para una visita según sus minutos de recordatorio
  Future<void> scheduleVisitReminders(ScheduledVisit visit) async {
    await init();

    final time = _parseTimeString(visit.time);
    final visitDateTime = DateTime(
      visit.date.year,
      visit.date.month,
      visit.date.day,
      time.hour,
      time.minute,
    );

    final now = DateTime.now();
    final clientName = visit.clientBusinessName.isNotEmpty
        ? visit.clientBusinessName
        : (visit.clientContactName.isNotEmpty ? visit.clientContactName : 'Cliente');

    final reminders = visit.reminderMinutes.isNotEmpty ? visit.reminderMinutes : [10080, 2880, 120];

    for (final minutesBefore in reminders) {
      final scheduledTime = visitDateTime.subtract(Duration(minutes: minutesBefore));
      if (scheduledTime.isBefore(now)) continue; // Si ya pasó, no programar

      final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);
      final notificationId = _generateNotificationId(visit.id, minutesBefore);

      String timeLabel;
      String targetDateDesc;
      if (minutesBefore >= 10080) {
        timeLabel = 'en 1 semana';
        targetDateDesc = 'el ${visit.date.day.toString().padLeft(2, '0')}/${visit.date.month.toString().padLeft(2, '0')}/${visit.date.year} a las ${visit.time}';
      } else if (minutesBefore >= 4320) {
        timeLabel = 'en 3 días';
        targetDateDesc = 'el ${visit.date.day.toString().padLeft(2, '0')}/${visit.date.month.toString().padLeft(2, '0')}/${visit.date.year} a las ${visit.time}';
      } else if (minutesBefore >= 2880) {
        timeLabel = 'en 2 días';
        targetDateDesc = 'el ${visit.date.day.toString().padLeft(2, '0')}/${visit.date.month.toString().padLeft(2, '0')}/${visit.date.year} a las ${visit.time}';
      } else if (minutesBefore >= 1440) {
        timeLabel = 'mañana';
        targetDateDesc = 'mañana a las ${visit.time}';
      } else if (minutesBefore >= 60) {
        final hours = (minutesBefore / 60).round();
        timeLabel = 'en $hours hora${hours > 1 ? 's' : ''}';
        targetDateDesc = 'hoy a las ${visit.time}';
      } else {
        timeLabel = 'en $minutesBefore minutos';
        targetDateDesc = 'hoy a las ${visit.time}';
      }

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'ej_alerts_channel',
        'Recordatorios de Servicios',
        channelDescription: 'Alertas y recordatorios programados de servicios y visitas.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
        color: const Color(0xFF0F2B48),
        playSound: true,
        enableVibration: true,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

      final addressInfo = visit.clientAddress.isNotEmpty ? ' Dirección: ${visit.clientAddress}' : '';

      try {
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          '🛡️ Recordatorio de Servicio ($timeLabel)',
          '${visit.serviceType} para $clientName $targetDateDesc.$addressInfo',
          tzScheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: visit.id,
        );
      } catch (e) {
        debugPrint('Error programando notificación local: $e');
      }
    }
  }

  /// Cancela los recordatorios de una visita
  Future<void> cancelVisitReminders(ScheduledVisit visit) async {
    await init();
    final reminders = visit.reminderMinutes.isNotEmpty ? visit.reminderMinutes : [10080, 4320, 2880, 1440, 120, 60, 30, 15];
    for (final m in reminders) {
      final id = _generateNotificationId(visit.id, m);
      await _notificationsPlugin.cancel(id);
    }
  }

  int _generateNotificationId(String visitId, int minutes) {
    return (visitId.hashCode ^ minutes).abs() % 2147483647;
  }

  TimeOfDay _parseTimeString(String timeStr) {
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
}
