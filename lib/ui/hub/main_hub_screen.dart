import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/client_service.dart';
import '../clients/clients_directory_screen.dart';
import '../history/report_history_screen.dart';
import '../home_screen.dart';
import '../quotes/quote_form_screen.dart';
import '../quotes/quote_history_screen.dart';
import '../schedule/schedule_form_screen.dart';
import '../schedule/schedule_history_screen.dart';
import '../resources/resources_hub_screen.dart';

class MainHubScreen extends StatefulWidget {
  const MainHubScreen({super.key});

  @override
  State<MainHubScreen> createState() => _MainHubScreenState();
}

class _MainHubScreenState extends State<MainHubScreen> {
  int _clientCount = 0;
  int _reportCount = 0;
  int _quoteCount = 0;
  int _scheduleCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    final prefs = await SharedPreferences.getInstance();

    final clients = await ClientService().getSavedClients();

    final rawReports = prefs.getString('ej_reports_history_list');
    final reportsList = (rawReports != null && rawReports.isNotEmpty) ? jsonDecode(rawReports) : [];

    final rawQuotes = prefs.getString('ej_quotes_history_list');
    final quotesList = (rawQuotes != null && rawQuotes.isNotEmpty) ? jsonDecode(rawQuotes) : [];

    final rawSchedules = prefs.getString('ej_schedules_history_list');
    final schedulesList = (rawSchedules != null && rawSchedules.isNotEmpty) ? jsonDecode(rawSchedules) : [];

    if (mounted) {
      setState(() {
        _clientCount = clients.length;
        _reportCount = reportsList.length;
        _quoteCount = quotesList.length;
        _scheduleCount = schedulesList.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, d \'de\' MMMM \'de\' yyyy', 'es_MX');
    final formattedDate = dateFormat.format(DateTime.now());
    final capitalizedDate = formattedDate.isNotEmpty
        ? formattedDate[0].toUpperCase() + formattedDate.substring(1)
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 34,
              height: 34,
              errorBuilder: (_, __, _) => const Icon(Icons.shield, color: Colors.amberAccent),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EJ EXTERMINADORES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Centro de Operaciones', style: TextStyle(fontSize: 10, color: Colors.white70)),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loadMetrics,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMetrics,
        color: const Color(0xFF0F2B48),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Saludo y Fecha
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F2B48), Color(0xFF1E6091)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF0F2B48).withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capitalizedDate,
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade200, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Bienvenido a tu Sistema de Gestión',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Control y Manejo Integral de Plagas Urbanas e Industriales',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    // Resumen rápido en métricas
                    Row(
                      children: [
                        _metricBadge(Icons.description, '$_reportCount', 'Reportes'),
                        const SizedBox(width: 6),
                        _metricBadge(Icons.request_quote, '$_quoteCount', 'Cotizaciones'),
                        const SizedBox(width: 6),
                        _metricBadge(Icons.calendar_month, '$_scheduleCount', 'Pólizas'),
                        const SizedBox(width: 6),
                        _metricBadge(Icons.people, '$_clientCount', 'Clientes'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'MÓDULOS DEL SISTEMA',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),

              // 1. Tarjeta REPORTES DE SERVICIO
              _moduleCard(
                icon: Icons.assignment_outlined,
                iconColor: const Color(0xFF0F2B48),
                badgeText: 'Activo',
                badgeColor: Colors.green,
                title: 'Reportes de Servicio Técnico',
                subtitle: 'Generación de reportes de servicio con monitoreo de trampas, control químico, fotos y firmas.',
                primaryButtonText: 'Generar Reporte',
                onPrimaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                  _loadMetrics();
                },
                secondaryButtonText: 'Historial de Reportes',
                onSecondaryPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReportHistoryScreen()),
                  );
                },
              ),
              const SizedBox(height: 14),

              // 2. Tarjeta COTIZACIONES
              _moduleCard(
                icon: Icons.request_quote_outlined,
                iconColor: const Color(0xFF1E6091),
                badgeText: 'Activo',
                badgeColor: Colors.blueAccent,
                title: 'Cotizaciones y Presupuestos',
                subtitle: 'Genera cotizaciones formales en PDF con cálculo de precios, IVA, plagas objetivo y condiciones comerciales.',
                primaryButtonText: 'Nueva Cotización',
                onPrimaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const QuoteFormScreen()),
                  );
                  _loadMetrics();
                },
                secondaryButtonText: 'Historial de Cotizaciones',
                onSecondaryPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const QuoteHistoryScreen()),
                  );
                },
              ),
              const SizedBox(height: 14),

              // 3. Tarjeta CALENDARIZACIÓN
              _moduleCard(
                icon: Icons.calendar_month_outlined,
                iconColor: Colors.orange.shade800,
                badgeText: _scheduleCount > 0 ? '$_scheduleCount activas' : 'Activo',
                badgeColor: Colors.orange,
                title: 'Calendarización y Cronograma',
                subtitle: 'Programa periódico de visitas mensuales/bimestrales y calendario oficial en PDF para clientes.',
                primaryButtonText: 'Nueva Calendarización',
                onPrimaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScheduleFormScreen()),
                  );
                  _loadMetrics();
                },
                secondaryButtonText: 'Historial y Agenda',
                onSecondaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScheduleHistoryScreen()),
                  );
                  _loadMetrics();
                },
              ),
              const SizedBox(height: 14),

              // 4. Tarjeta DIRECTORIO DE CLIENTES
              _moduleCard(
                icon: Icons.people_alt_outlined,
                iconColor: Colors.teal.shade800,
                badgeText: '$_clientCount guardados',
                badgeColor: Colors.teal,
                title: 'Directorio de Clientes',
                subtitle: 'Base de datos unificada de clientes compartida para generar reportes, cotizaciones y visitas.',
                primaryButtonText: 'Ver Directorio de Clientes',
                onPrimaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ClientsDirectoryScreen()),
                  );
                  _loadMetrics();
                },
                secondaryButtonText: null,
                onSecondaryPressed: null,
              ),
              const SizedBox(height: 14),

              // 5. Tarjeta BIBLIOTECA DE PLAGAS Y COMUNICADOS
              _moduleCard(
                icon: Icons.menu_book_outlined,
                iconColor: Colors.deepPurple.shade700,
                badgeText: 'Fichas y PDFs',
                badgeColor: Colors.deepPurple,
                title: 'Biblioteca de Plagas y Comunicados',
                subtitle: 'Fichas técnicas de plagas (alacranes, roedores, etc.) y avisos oficiales para clientes (buenas prácticas en oficinas, cocinas y pre/post servicio).',
                primaryButtonText: 'Abrir Biblioteca y Avisos',
                onPrimaryPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ResourcesHubScreen()),
                  );
                },
                secondaryButtonText: null,
                onSecondaryPressed: null,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricBadge(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 9.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _moduleCard({
    required IconData icon,
    required Color iconColor,
    required String badgeText,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required String primaryButtonText,
    required VoidCallback onPrimaryPressed,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F2B48)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(color: badgeColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: iconColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      elevation: 0,
                    ),
                    onPressed: onPrimaryPressed,
                    child: Text(
                      primaryButtonText,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                if (secondaryButtonText != null && onSecondaryPressed != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: iconColor,
                        side: BorderSide(color: iconColor.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      ),
                      onPressed: onSecondaryPressed,
                      child: Text(
                        secondaryButtonText,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
