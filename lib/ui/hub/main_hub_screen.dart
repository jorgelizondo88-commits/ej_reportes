import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/client_service.dart';
import '../clients/clients_directory_screen.dart';
import '../contracts/contract_form_screen.dart';
import '../contracts/contract_history_screen.dart';
import '../history/report_history_screen.dart';
import '../home_screen.dart';
import '../quotes/quote_form_screen.dart';
import '../quotes/quote_history_screen.dart';
import '../schedule/quick_appointment_screen.dart';
import '../schedule/schedule_form_screen.dart';
import '../schedule/schedule_history_screen.dart';
import '../resources/resources_hub_screen.dart';
import '../resources/company_presentation_screen.dart';
import '../../services/trap_layout_service.dart';
import '../layouts/trap_layouts_history_screen.dart';
import '../layouts/trap_layout_canvas_screen.dart';
import '../cloud/google_drive_sync_screen.dart';
import '../invoices/invoices_hub_screen.dart';

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
  int _contractCount = 0;
  int _layoutCount = 0;

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

    final rawContracts = prefs.getString('ej_contracts_history_list');
    final contractsList = (rawContracts != null && rawContracts.isNotEmpty) ? jsonDecode(rawContracts) : [];

    final layoutsList = await TrapLayoutService().getAllLayouts();

    if (mounted) {
      setState(() {
        _clientCount = clients.length;
        _reportCount = reportsList.length;
        _quoteCount = quotesList.length;
        _scheduleCount = schedulesList.length;
        _contractCount = contractsList.length;
        _layoutCount = layoutsList.length;
      });
    }

    // Auto-sincronización bidireccional silenciosa en segundo plano con Google Drive
    if (GoogleDriveSyncService().isSignedIn) {
      GoogleDriveSyncService().pullAndMergeCloudDatabase().then((merged) async {
        final discovered = await GoogleDriveSyncService().discoverDriveDocuments();
        if ((merged || discovered > 0) && mounted) {
          final p = await SharedPreferences.getInstance();
          final rR = p.getString('ej_reports_history_list');
          final rQ = p.getString('ej_quotes_history_list');
          final cL = await ClientService().getSavedClients();
          final repL = (rR != null && rR.isNotEmpty) ? jsonDecode(rR) : [];
          final quoL = (rQ != null && rQ.isNotEmpty) ? jsonDecode(rQ) : [];
          if (mounted) {
            setState(() {
              _clientCount = cL.length;
              _reportCount = repL.length;
              _quoteCount = quoL.length;
            });
          }
        }
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
                        const SizedBox(width: 4),
                        _metricBadge(Icons.request_quote, '$_quoteCount', 'Cotiz.'),
                        const SizedBox(width: 4),
                        _metricBadge(Icons.calendar_month, '$_scheduleCount', 'Agendas'),
                        const SizedBox(width: 4),
                        _metricBadge(Icons.draw, '$_contractCount', 'Contratos'),
                        const SizedBox(width: 4),
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

              // 3. Tarjeta AGENDA Y CALENDARIO
              _moduleCard(
                icon: Icons.calendar_today_outlined,
                iconColor: Colors.teal.shade800,
                badgeText: 'Google Sync',
                badgeColor: Colors.teal,
                title: 'Agenda y Calendario de Servicios',
                subtitle: 'Agenda interactiva de citas, prospectos, inspecciones y visitas de control de plagas sincronizadas con Google Calendar (móvil y PC).',
                primaryButtonText: 'Abrir Agenda y Calendario',
                onPrimaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScheduleHistoryScreen(initialTab: 0)),
                  );
                  _loadMetrics();
                },
                secondaryButtonText: '+ Agendar Cita o Prospecto',
                onSecondaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const QuickAppointmentScreen()),
                  );
                  _loadMetrics();
                },
              ),
              const SizedBox(height: 14),

              // 4. Tarjeta FACTURACIÓN & COBRANZA
              _moduleCard(
                icon: Icons.receipt_long_outlined,
                iconColor: const Color(0xFF16A34A),
                badgeText: 'CFDI en Drive',
                badgeColor: const Color(0xFF16A34A),
                title: 'Facturación & Cobranza',
                subtitle: 'Control de facturas pendientes de pago y pagadas (PDF + XML). Visualiza el PDF en el móvil, envíalo por WhatsApp con recordatorio y confirma pagos en tiempo real.',
                primaryButtonText: 'Ver Facturas y Cobranza',
                onPrimaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const InvoicesHubScreen()),
                  );
                },
                secondaryButtonText: 'Ver Facturas Pendientes',
                onSecondaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const InvoicesHubScreen(initialTab: 0)),
                  );
                },
              ),
              const SizedBox(height: 14),

              // 5. Tarjeta CRONOGRAMAS DE SERVICIO EN PDF
              _moduleCard(
                icon: Icons.picture_as_pdf_outlined,
                iconColor: Colors.orange.shade800,
                badgeText: _scheduleCount > 0 ? '$_scheduleCount registrados' : 'Formatos PDF',
                badgeColor: Colors.orange,
                title: 'Cronogramas de Servicio (PDF)',
                subtitle: 'Elaboración de cronogramas y calendarios periódicos de servicio en formato PDF oficial para empresas y pólizas.',
                primaryButtonText: 'Nuevo Cronograma PDF',
                onPrimaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScheduleFormScreen()),
                  );
                  _loadMetrics();
                },
                secondaryButtonText: 'Historial de Cronogramas PDF',
                onSecondaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScheduleHistoryScreen(initialTab: 2)),
                  );
                  _loadMetrics();
                },
              ),
              const SizedBox(height: 14),

              // 6. Tarjeta PÓLIZAS Y CONTRATOS DIGITALES
              _moduleCard(
                icon: Icons.draw_outlined,
                iconColor: Colors.indigo.shade800,
                badgeText: _contractCount > 0 ? '$_contractCount registrados' : 'Legal',
                badgeColor: Colors.indigo,
                title: 'Pólizas y Contratos Digitales',
                subtitle: 'Contratos legales de 1, 3, 6 o 12 meses con firma en pantalla (S-Pen), cotejo fotográfico de INE y PDF oficial.',
                primaryButtonText: 'Nueva Póliza / Contrato',
                onPrimaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ContractFormScreen()),
                  );
                  _loadMetrics();
                },
                secondaryButtonText: 'Historial de Contratos',
                onSecondaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ContractHistoryScreen()),
                  );
                  _loadMetrics();
                },
              ),
              const SizedBox(height: 14),

              // 7. Tarjeta PLANOS Y LAYOUTS DE TRAMPAS
              _moduleCard(
                icon: Icons.architecture_outlined,
                iconColor: Colors.blueGrey.shade800,
                badgeText: _layoutCount > 0 ? '$_layoutCount planos' : 'Auditorías AIB',
                badgeColor: const Color(0xFF0F2B48),
                title: 'Planos y Layouts de Trampas',
                subtitle: 'Diseño interactivo de croquis y planos con ubicación de cebaderos exteriores, trampas mecánicas interiores y censo oficial en PDF.',
                primaryButtonText: 'Ver Planos y Layouts',
                onPrimaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TrapLayoutsHistoryScreen()),
                  );
                  _loadMetrics();
                },
                secondaryButtonText: '+ Nuevo Plano / Layout',
                onSecondaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TrapLayoutCanvasScreen()),
                  );
                  _loadMetrics();
                },
              ),
              const SizedBox(height: 14),

              // 8. Tarjeta DIRECTORIO DE CLIENTES
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

              // 9. Tarjeta DOCUMENTOS OFICIALES, PROTOCOLOS Y FICHAS
              _moduleCard(
                icon: Icons.menu_book_outlined,
                iconColor: Colors.deepPurple.shade700,
                badgeText: 'Fichas y PDFs',
                badgeColor: Colors.deepPurple,
                title: 'Documentos Oficiales, Protocolos y Fichas',
                subtitle: 'Documentos listos para enviar a clientes (Fiprax/Gel, Oficinas, Casas), fichas de plagas y presentación corporativa en PDF.',
                primaryButtonText: 'Abrir Documentos y Protocolos',
                onPrimaryPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ResourcesHubScreen(initialTab: 1)),
                  );
                },
                secondaryButtonText: 'Presentación Corporativa',
                onSecondaryPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CompanyPresentationScreen()),
                  );
                },
              ),
              const SizedBox(height: 14),

              // 10. Tarjeta NUBE GOOGLE DRIVE (5 TB) & EXPEDIENTES DIGITALES
              _moduleCard(
                icon: Icons.cloud_done_outlined,
                iconColor: Colors.blue.shade800,
                badgeText: '5 TB Nube',
                badgeColor: Colors.blue.shade700,
                title: 'Nube Google Drive & Respaldos',
                subtitle: 'Sincronización automática de PDFs organizada por cliente, respaldo de base de datos maestra y enlaces de solo lectura para compartir por WhatsApp.',
                primaryButtonText: 'Abrir Nube y Respaldos',
                onPrimaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GoogleDriveSyncScreen()),
                  );
                  _loadMetrics();
                },
                secondaryButtonText: 'Sincronizar Historial Ahora',
                onSecondaryPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GoogleDriveSyncScreen()),
                  );
                  _loadMetrics();
                },
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
