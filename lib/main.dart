import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/notification_service.dart';
import 'ui/hub/main_hub_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('es_MX', null);
  } catch (_) {}
  try {
    await NotificationService().init();
  } catch (_) {}
  runApp(const EJReportesApp());
}

class EJReportesApp extends StatelessWidget {
  const EJReportesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EJ Exterminadores',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F2B48),
          primary: const Color(0xFF0F2B48),
          secondary: const Color(0xFF1E6091),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      home: const MainHubScreen(),
    );
  }
}