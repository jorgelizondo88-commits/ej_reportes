import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/pest_info_model.dart';
import '../../models/advisory_notice_model.dart';
import '../../services/resource_pdf_service.dart';
import 'pest_detail_screen.dart';
import 'advisory_detail_screen.dart';

class ResourcesHubScreen extends StatefulWidget {
  const ResourcesHubScreen({super.key});

  @override
  State<ResourcesHubScreen> createState() => _ResourcesHubScreenState();
}

class _ResourcesHubScreenState extends State<ResourcesHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<PestInfoModel> _allPests = PestInfoModel.getAllPests();
  final List<AdvisoryNoticeModel> _allNotices = AdvisoryNoticeModel.getAllNotices();

  String _searchQuery = '';
  String _selectedCategory = 'Todos';

  final List<String> _categories = [
    'Todos',
    'Roedores',
    'Arácnidos y Ponzoñosos',
    'Cucarachas',
    'Rastreros',
    'Voladores',
    'Estructurales',
  ];

  String _selectedNoticeCategory = 'Todos';

  final List<String> _noticeCategories = [
    'Todos',
    'Dinámica de Plagas',
    'Pólizas e Industria',
    'Comercios y Locales',
    'Casa Habitación y Residencial',
    'Restaurantes y Alimentos',
    'Oficinas y Corporativos',
    'Almacenes y Bodegas',
    'Servicio Técnico',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<PestInfoModel> get _filteredPests {
    return _allPests.where((p) {
      final matchesQuery = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.scientificName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.summary.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory = _selectedCategory == 'Todos' || p.category == _selectedCategory;

      return matchesQuery && matchesCategory;
    }).toList();
  }

  List<AdvisoryNoticeModel> get _filteredNotices {
    return _allNotices.where((n) {
      final matchesCategory = _selectedNoticeCategory == 'Todos' || n.category == _selectedNoticeCategory;
      return matchesCategory;
    }).toList();
  }

  Future<void> _quickSharePestPdf(PestInfoModel pest) async {
    try {
      final pdfBytes = await ResourcePdfService.generatePestInfoPdf(pest);
      final tempDir = await getTemporaryDirectory();
      final cleanName = pest.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${tempDir.path}/Ficha_Tecnica_$cleanName.pdf');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Ficha Técnica EJ Exterminadores: ${pest.name}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir PDF: $e')),
        );
      }
    }
  }

  Future<void> _quickShareNoticePdf(AdvisoryNoticeModel notice) async {
    try {
      final pdfBytes = await ResourcePdfService.generateAdvisoryPdf(notice);
      final tempDir = await getTemporaryDirectory();
      final cleanName = notice.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${tempDir.path}/Comunicado_$cleanName.pdf');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Comunicado Oficial EJ Exterminadores: ${notice.title}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca y Comunicados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: const Color(0xFF0F2B48),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.bug_report_outlined, size: 20),
              text: 'Guía de Plagas (${_allPests.length})',
            ),
            Tab(
              icon: const Icon(Icons.campaign_outlined, size: 20),
              text: 'Avisos y Buenas Prácticas (${_allNotices.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPestsTab(),
          _buildNoticesTab(),
        ],
      ),
    );
  }

  // --- TAB 1: GUÍA DE PLAGAS ---
  Widget _buildPestsTab() {
    final filtered = _filteredPests;

    return Column(
      children: [
        // Buscador
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar plaga (alacrán, rata, cucaracha...)',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
        ),

        // Filtros de categoría en chips horizontales
        SizedBox(
          height: 42,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final cat = _categories[idx];
              final isSelected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                selectedColor: const Color(0xFF0F2B48),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11.5,
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedCategory = cat);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 6),

        // Lista de plagas
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text('No se encontraron plagas con "$_searchQuery"', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final pest = filtered[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PestDetailScreen(pest: pest)),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F2B48).withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(pest.iconEmoji, style: const TextStyle(fontSize: 26)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pest.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F2B48)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      pest.scientificName,
                                      style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 4,
                                      children: [
                                        _badge(pest.category, const Color(0xFF1E6091)),
                                        _badge(
                                          pest.riskLevel.split(' / ').first,
                                          pest.riskLevel.contains('Crítico') ? Colors.red.shade700 : Colors.orange.shade800,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.share, size: 20, color: Color(0xFF0F2B48)),
                                tooltip: 'Compartir PDF',
                                onPressed: () => _quickSharePestPdf(pest),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- TAB 2: AVISOS Y BUENAS PRÁCTICAS ---
  Widget _buildNoticesTab() {
    final filtered = _filteredNotices;

    return Column(
      children: [
        // Selector horizontal de categorías
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _noticeCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final cat = _noticeCategories[idx];
              final isSelected = cat == _selectedNoticeCategory;
              return ChoiceChip(
                label: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : const Color(0xFF0F2B48),
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF0F2B48),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF0F2B48) : Colors.grey.shade300,
                  ),
                ),
                showCheckmark: false,
                onSelected: (val) {
                  if (val) {
                    setState(() => _selectedNoticeCategory = cat);
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(height: 4),

        // Lista de comunicados
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        'No hay comunicados en la categoría "$_selectedNoticeCategory"',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final notice = filtered[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1.5,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AdvisoryDetailScreen(notice: notice)),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F2B48).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(notice.iconEmoji, style: const TextStyle(fontSize: 22)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notice.title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F2B48)),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          notice.targetAudience,
                                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                notice.problemStatement,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.25),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _badge(notice.category, const Color(0xFF1E6091)),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          side: const BorderSide(color: Color(0xFF0F2B48)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        ),
                                        icon: const Icon(Icons.share, size: 15, color: Color(0xFF0F2B48)),
                                        label: const Text('Compartir PDF', style: TextStyle(fontSize: 11, color: Color(0xFF0F2B48))),
                                        onPressed: () => _quickShareNoticePdf(notice),
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0F2B48),
                                          foregroundColor: Colors.white,
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => AdvisoryDetailScreen(notice: notice)),
                                          );
                                        },
                                        child: const Text('Ver', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
