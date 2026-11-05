import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/client_model.dart';
import '../../services/client_service.dart';
import '../../services/google_drive_sync_service.dart';
import '../cloud/google_drive_sync_screen.dart';
import '../invoices/invoices_hub_screen.dart';
import '../quotes/quote_form_screen.dart';

class ClientsDirectoryScreen extends StatefulWidget {
  const ClientsDirectoryScreen({super.key});

  @override
  State<ClientsDirectoryScreen> createState() => _ClientsDirectoryScreenState();
}

class _ClientsDirectoryScreenState extends State<ClientsDirectoryScreen> {
  final ClientService _clientService = ClientService();
  List<ClientModel> _allClients = [];
  List<ClientModel> _filteredClients = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    final clients = await _clientService.getSavedClients();
    setState(() {
      _allClients = clients;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredClients = _allClients.where((c) {
        return query.isEmpty ||
            c.businessName.toLowerCase().contains(query) ||
            c.contactName.toLowerCase().contains(query) ||
            c.phone.toLowerCase().contains(query) ||
            c.address.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _shareClientFolder(ClientModel client) async {
    final driveService = GoogleDriveSyncService();
    if (!driveService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Para compartir la carpeta del cliente, conecta Google Drive primero.'),
          backgroundColor: const Color(0xFF0F2B48),
          action: SnackBarAction(
            label: 'Conectar Nube',
            textColor: Colors.amberAccent,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GoogleDriveSyncScreen()),
              );
            },
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando enlace de solo lectura para el cliente...'),
        duration: Duration(seconds: 1),
      ),
    );

    final link = await driveService.getOrCreateClientFolderShareLink(client.businessName);
    if (link != null && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.folder_shared, color: Color(0xFF0F2B48)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Expediente en la Nube: ${client.businessName}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Este enlace es permanente y de "Solo Lectura". El cliente puede ver y descargar todos sus reportes, cotizaciones y planos sin poder borrar nada:',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(link, style: const TextStyle(fontSize: 11, color: Colors.blue)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D), foregroundColor: Colors.white),
              icon: const Icon(Icons.share, size: 16),
              label: const Text('Enviar por WhatsApp'),
              onPressed: () async {
                Navigator.pop(context);
                final message = 'Estimado cliente ${client.businessName}, le compartimos el enlace oficial a su Expediente Digital de EJ Exterminadores en la nube. Aquí tendrá disponible su historial de reportes de servicio, cotizaciones y planos en tiempo real:\n$link';
                await Share.share(message);
              },
            ),
          ],
        ),
      );
    }
  }

  void _openClientDialog({ClientModel? client}) {
    final businessCtrl = TextEditingController(text: client?.businessName ?? '');
    final contactCtrl = TextEditingController(text: client?.contactName ?? '');
    final addressCtrl = TextEditingController(text: client?.address ?? '');
    final phoneCtrl = TextEditingController(text: client?.phone ?? '');
    final emailCtrl = TextEditingController(text: client?.email ?? '');
    String facilityType = client?.facilityType ?? 'Comercial / Restaurante';

    final facilityTypes = [
      'Comercial / Restaurante',
      'Industrial / Bodega',
      'Residencial / Casa',
      'Oficinas / Corporativo',
      'Hospitalario / Clínica',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            client != null ? 'Editar Cliente' : 'Nuevo Cliente',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: businessCtrl,
                  decoration: const InputDecoration(labelText: 'Razón Social / Negocio *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contactCtrl,
                  decoration: const InputDecoration(labelText: 'Persona de Contacto'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Dirección'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: facilityTypes.contains(facilityType) ? facilityType : facilityTypes.first,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Giro / Instalación'),
                  items: facilityTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => facilityType = val);
                  },
                ),
              ],
            ),
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
              onPressed: () async {
                final business = businessCtrl.text.trim();
                final contact = contactCtrl.text.trim();

                if (business.isEmpty && contact.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingresa al menos la razón social o el contacto.')),
                  );
                  return;
                }

                final saved = ClientModel(
                  id: client?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  businessName: business,
                  contactName: contact,
                  address: addressCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  facilityType: facilityType,
                  hasTraps: client?.hasTraps ?? false,
                  defaultTraps: client?.defaultTraps ?? [],
                );

                await _clientService.saveClient(saved);
                if (!mounted) return;
                Navigator.pop(context);
                _loadClients();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Directorio de Clientes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Nuevo Cliente',
            onPressed: () => _openClientDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar cliente por nombre, teléfono o dirección...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilter();
                  },
                )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (_) => _applyFilter(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F2B48)))
                : _filteredClients.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    _searchController.text.isNotEmpty
                        ? 'No se encontraron clientes para esa búsqueda.'
                        : 'No tienes clientes guardados aún.\nSe guardan automáticamente al generar un reporte o cotización.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredClients.length,
              itemBuilder: (context, index) {
                final c = _filteredClients[index];
                final title = c.businessName.isNotEmpty ? c.businessName : c.contactName;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2B48)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: 'Editar',
                              onPressed: () => _openClientDialog(client: c),
                            ),
                          ],
                        ),
                        if (c.contactName.isNotEmpty && c.contactName != title) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(c.contactName, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                            ],
                          ),
                        ],
                        if (c.phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(c.phone, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                            ],
                          ),
                        ],
                        if (c.address.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  c.address,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                side: const BorderSide(color: Color(0xFF15803D)),
                                foregroundColor: const Color(0xFF15803D),
                              ),
                              icon: const Icon(Icons.folder_shared_outlined, size: 16),
                              label: const Text('Expediente', style: TextStyle(fontSize: 12)),
                              onPressed: () => _shareClientFolder(c),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                side: const BorderSide(color: Color(0xFF0F2B48)),
                                foregroundColor: const Color(0xFF0F2B48),
                              ),
                              icon: const Icon(Icons.receipt_long_outlined, size: 16),
                              label: const Text('Facturas', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => InvoicesHubScreen(
                                      initialClientFilter: c.businessName,
                                    ),
                                  ),
                                );
                              },
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                side: const BorderSide(color: Color(0xFF1E6091)),
                                foregroundColor: const Color(0xFF1E6091),
                              ),
                              icon: const Icon(Icons.request_quote_outlined, size: 16),
                              label: const Text('Cotizar', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => QuoteFormScreen(preselectedClient: c),
                                  ),
                                );
                              },
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
      ),
    );
  }
}
