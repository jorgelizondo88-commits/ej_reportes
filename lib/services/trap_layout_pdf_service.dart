import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/trap_layout_model.dart';

class TrapLayoutPdfService {
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF0F2B48);
  static const PdfColor secondaryColor = PdfColor.fromInt(0xFF1E6091);
  static const PdfColor borderColor = PdfColor.fromInt(0xFFCBD5E1);
  static const PdfColor lightBg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor darkText = PdfColor.fromInt(0xFF1E293B);

  // Colores oficiales de auditoría para tipos de trampas
  static PdfColor getPinPdfColor(String type) {
    if (type.contains('Cebadero')) return const PdfColor.fromInt(0xFF15803D); // Verde
    if (type.contains('Mecánica') || type.contains('Golpe')) return const PdfColor.fromInt(0xFF1D4ED8); // Azul
    if (type.contains('Goma') || type.contains('Adhesiva')) return const PdfColor.fromInt(0xFFD97706); // Ámbar
    if (type.contains('Luz UV') || type.contains('Lámpara')) return const PdfColor.fromInt(0xFF7E22CE); // Morado
    return const PdfColor.fromInt(0xFFDC2626); // Rojo / Monitoreo
  }

  static Future<pw.ImageProvider?> _loadLogoImage() async {
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      return pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static pw.MemoryImage? _loadPlanImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    try {
      final file = File(imagePath);
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        return pw.MemoryImage(bytes);
      }
    } catch (_) {}
    return null;
  }

  /// Genera el Layout Oficial de Estaciones de Control en formato apaisado (Landscape)
  static Future<Uint8List> generateLayoutPdf(TrapLayoutModel layout) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final planImage = _loadPlanImage(layout.backgroundImagePath);

    final pageThemeLandscape = pw.PageTheme(
      pageFormat: PdfPageFormat.letter.landscape,
      margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      ),
    );

    final dateFormat = DateFormat('dd/MM/yyyy');
    final formattedDate = dateFormat.format(layout.updatedAt);

    // Dimensiones del lienzo del plano en el PDF (aprox 460 x 375 puntos)
    const double canvasW = 460.0;
    const double canvasH = 370.0;

    pdf.addPage(
      pw.Page(
        pageTheme: pageThemeLandscape,
        build: (context) {
          return pw.Column(
            children: [
              // ENCABEZADO SUPERIOR EJECUTIVO
              _buildHeader(logoImage, layout, formattedDate),
              pw.SizedBox(height: 8),

              // CUERPO PRINCIPAL: PLANO A LA IZQUIERDA Y PANEL AUDITORÍA A LA DERECHA
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // --- COLUMNA 1: PLANO VISUAL CON PINES INTERACTIVOS (ANCHO MAYOR) ---
                    pw.Expanded(
                      flex: 62,
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: primaryColor, width: 1.2),
                          borderRadius: pw.BorderRadius.circular(6),
                          color: PdfColors.white,
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 5,
                          verticalRadius: 5,
                          child: pw.Stack(
                            fit: pw.StackFit.expand,
                            children: [
                              // Fondo: Imagen cargada (o cuadrícula técnica si no hay foto)
                              if (planImage != null)
                                pw.Image(planImage, fit: pw.BoxFit.contain)
                              else
                                _buildTechnicalBlueprintGrid(layout.gridTitle, walls: layout.walls, canvasW: canvasW, canvasH: canvasH),

                              // Si hay imagen pero también muros trazados encima
                              if (planImage != null && layout.walls.isNotEmpty) ...[
                                ...layout.walls.map((wall) {
                                  if (wall.points.length >= 3 && wall.isClosed) {
                                    return pw.Polygon(
                                      points: wall.points.map((p) => PdfPoint(p.x * canvasW, p.y * canvasH)).toList(),
                                      fillColor: const PdfColor.fromInt(0x1E0F2B48),
                                      strokeColor: primaryColor,
                                      strokeWidth: 2.0,
                                      close: true,
                                    );
                                  } else if (wall.points.length >= 2) {
                                    return pw.InkList(
                                      points: [wall.points.map((p) => PdfPoint(p.x * canvasW, p.y * canvasH)).toList()],
                                      strokeColor: primaryColor,
                                      strokeWidth: 2.0,
                                    );
                                  }
                                  return pw.SizedBox();
                                }),
                              ],

                              // Rosa de los vientos / Indicador de Norte en esquina superior derecha
                              pw.Positioned(
                                top: 8,
                                right: 8,
                                child: _buildNorthIndicator(),
                              ),

                              // Título en marca de agua inferior izquierda
                              pw.Positioned(
                                bottom: 6,
                                left: 8,
                                child: pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.white,
                                    borderRadius: pw.BorderRadius.circular(3),
                                    border: pw.Border.all(color: borderColor, width: 0.5),
                                  ),
                                  child: pw.Text(
                                    '${layout.facilityName}   |   ${layout.pins.length} Dispositivos Georreferenciados',
                                    style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                                  ),
                                ),
                              ),

                              // PINES DE TRAMPAS DIBUJADOS EN COORDENADAS X / Y
                              ...layout.pins.map((pin) {
                                final pinColor = getPinPdfColor(pin.type);
                                // Coordenadas relativas
                                final left = (pin.x * canvasW).clamp(10.0, canvasW - 24.0);
                                final top = (pin.y * canvasH).clamp(10.0, canvasH - 24.0);

                                return pw.Positioned(
                                  left: left,
                                  top: top,
                                  child: pw.Container(
                                    width: 18,
                                    height: 18,
                                    decoration: pw.BoxDecoration(
                                      color: pinColor,
                                      shape: pw.BoxShape.circle,
                                      border: pw.Border.all(color: PdfColors.white, width: 1.2),
                                    ),
                                    alignment: pw.Alignment.center,
                                    child: pw.Text(
                                      pin.code,
                                      style: pw.TextStyle(
                                        fontSize: 5.8,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.white,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),

                    pw.SizedBox(width: 10),

                    // --- COLUMNA 2: SIMBOLOGÍA, RESUMEN Y TABLA DE CENSO ---
                    pw.Expanded(
                      flex: 38,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // 1. SIMBOLOGÍA OFICIAL (AUDITORÍA AIB / NOM-256)
                          _buildLegendBox(),
                          pw.SizedBox(height: 6),

                          // 2. RESUMEN DE DISPOSITIVOS INSTALADOS
                          _buildTotalsBar(layout),
                          pw.SizedBox(height: 6),

                          // 3. TABLA DE CENSO DE DISPOSITIVOS (PRIMEROS REGISTROS)
                          pw.Expanded(
                            child: _buildStationsTable(layout),
                          ),
                          pw.SizedBox(height: 6),

                          // 4. FIRMAS DE VALIDACIÓN TÉCNICA
                          _buildSignaturesBlock(layout),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 4),

              // PIE DE PÁGINA NORMATIVO
              _buildFooter(),
            ],
          );
        },
      ),
    );

    // Si hay más de 12 dispositivos, agregar Hoja 2 con el Censo Completo de Auditoría
    if (layout.pins.length > 12) {
      pdf.addPage(
        pw.Page(
          pageTheme: pageThemeLandscape,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(logoImage, layout, formattedDate, isAnnex: true),
                pw.SizedBox(height: 8),
                pw.Text(
                  'ANEXO TÉCNICO: CENSO COMPLETO Y CONTROL DE UBICACIONES DETALLADAS',
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
                pw.SizedBox(height: 6),
                pw.Expanded(
                  child: _buildFullInventoryTable(layout),
                ),
                pw.SizedBox(height: 6),
                _buildSignaturesBlock(layout),
                pw.SizedBox(height: 4),
                _buildFooter(),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  // --- WIDGETS DE COMPOSICIÓN DEL PDF ---

  static pw.Widget _buildHeader(pw.ImageProvider? logoImage, TrapLayoutModel layout, String formattedDate, {bool isAnnex = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: borderColor, width: 0.8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Logo e Identidad
          pw.Row(
            children: [
              if (logoImage != null) ...[
                pw.Container(
                  width: 38,
                  height: 38,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 8),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('EJ EXTERMINADORES', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.Text('CONTROL INTEGRAL DE PLAGAS Y BIOSEGURIDAD', style: const pw.TextStyle(fontSize: 6.5, color: secondaryColor)),
                  pw.Text(
                    isAnnex ? 'ANEXO: CENSO Y LISTADO DE AUDITORÍA' : 'PLANO OFICIAL DE UBICACIÓN DE ESTACIONES (LAYOUT)',
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F766E)),
                  ),
                ],
              ),
            ],
          ),

          // Datos del Cliente y Folio
          pw.Row(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('CLIENTE: ${layout.clientBusinessName}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.Text('INSTALACIÓN: ${layout.facilityName}', style: const pw.TextStyle(fontSize: 7.2, color: darkText)),
                  pw.Text('DIRECCIÓN: ${layout.clientAddress}', style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(width: 14),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('FOLIO PLANO', style: const pw.TextStyle(fontSize: 6.0, color: PdfColors.white)),
                    pw.Text(layout.folio, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text(formattedDate, style: const pw.TextStyle(fontSize: 6.2, color: PdfColors.amber)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildLegendBox() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: borderColor, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('SIMBOLOGÍA OFICIAL DE MONITOREO', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _legendItem(const PdfColor.fromInt(0xFF15803D), 'C', 'Cebadero Exterior (Roedoricida)'),
              _legendItem(const PdfColor.fromInt(0xFF1D4ED8), 'TM', 'Trampa Mecánica (Impacto)'),
            ],
          ),
          pw.SizedBox(height: 2.5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _legendItem(const PdfColor.fromInt(0xFFD97706), 'TG', 'Trampa de Goma (Adhesiva)'),
              _legendItem(const PdfColor.fromInt(0xFF7E22CE), 'LU', 'Lámpara Luz UV (Voladores)'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _legendItem(PdfColor color, String badge, String label) {
    return pw.Row(
      children: [
        pw.Container(
          width: 12,
          height: 12,
          decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
          alignment: pw.Alignment.center,
          child: pw.Text(badge, style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        ),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 6.5, color: darkText)),
      ],
    );
  }

  static pw.Widget _buildTotalsBar(TrapLayoutModel layout) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFEEF2FF),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFA5B4FC), width: 0.6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Text('Cebaderos: ${layout.totalExteriorBaitStations}', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF15803D))),
          pw.Text('Mecánicas: ${layout.totalMechanicalTraps}', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1D4ED8))),
          pw.Text('Gomas: ${layout.totalGlueTraps}', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFD97706))),
          pw.Text('Luz UV: ${layout.totalUvLamps}', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF7E22CE))),
          pw.Text('TOTAL: ${layout.totalPins}', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
        ],
      ),
    );
  }

  static pw.Widget _buildStationsTable(TrapLayoutModel layout) {
    final displayPins = layout.pins.take(10).toList();

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor, width: 0.6),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          // Header de la tabla
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            color: primaryColor,
            child: pw.Row(
              children: [
                pw.Container(width: 32, child: pw.Text('CÓD.', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                pw.Container(width: 80, child: pw.Text('TIPO DISPOSITIVO', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                pw.Expanded(child: pw.Text('UBICACIÓN / ÁREA ESPECÍFICA', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
              ],
            ),
          ),
          // Registros
          if (displayPins.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Aún no se han marcado estaciones en el plano.', style: const pw.TextStyle(fontSize: 7.0, color: PdfColors.grey600)),
            )
          else
            pw.Expanded(
              child: pw.ListView.builder(
                itemCount: displayPins.length,
                itemBuilder: (context, i) {
                  final pin = displayPins[i];
                  final pinColor = getPinPdfColor(pin.type);
                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.2),
                    decoration: pw.BoxDecoration(
                      color: i % 2 == 0 ? lightBg : PdfColors.white,
                      border: const pw.Border(bottom: pw.BorderSide(color: borderColor, width: 0.4)),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: 32,
                          child: pw.Row(
                            children: [
                              pw.Container(width: 6, height: 6, decoration: pw.BoxDecoration(color: pinColor, shape: pw.BoxShape.circle)),
                              pw.SizedBox(width: 3),
                              pw.Text(pin.code, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                            ],
                          ),
                        ),
                        pw.Container(
                          width: 80,
                          child: pw.Text(pin.type, style: const pw.TextStyle(fontSize: 6.2, color: darkText), overflow: pw.TextOverflow.clip),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            pin.area.isNotEmpty ? pin.area : 'Ubicación señalada en plano',
                            style: pw.TextStyle(fontSize: 6.2, color: darkText, fontWeight: pin.area.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal),
                            overflow: pw.TextOverflow.clip,
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
  }

  static pw.Widget _buildFullInventoryTable(TrapLayoutModel layout) {
    final pins = layout.pins;
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(3.0),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(5.0),
        4: pw.FlexColumnWidth(3.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: primaryColor),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('CÓDIGO', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
            pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('TIPO DE ESTACIÓN', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
            pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('ZONA', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
            pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('UBICACIÓN DETALLADA EN PLANTA', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
            pw.Padding(padding: const pw.EdgeInsets.all(3.5), child: pw.Text('MECANISMO / INSUMO', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
          ],
        ),
        ...pins.map((p) {
          final color = getPinPdfColor(p.type);
          String insumo = 'Bloque Parafinado Anticoagulante';
          if (p.type.contains('Mecánica')) insumo = 'Impacto de resorte / Sin químico';
          if (p.type.contains('Goma')) insumo = 'Bandeja de goma aromática';
          if (p.type.contains('Luz UV')) insumo = 'Atracción UV + Placa pegajosa';

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: pins.indexOf(p) % 2 == 0 ? lightBg : PdfColors.white),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(3.0),
                child: pw.Row(
                  children: [
                    pw.Container(width: 6, height: 6, decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle)),
                    pw.SizedBox(width: 3),
                    pw.Text(p.code, style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  ],
                ),
              ),
              pw.Padding(padding: const pw.EdgeInsets.all(3.0), child: pw.Text(p.type, style: const pw.TextStyle(fontSize: 6.5, color: darkText))),
              pw.Padding(padding: const pw.EdgeInsets.all(3.0), child: pw.Text(p.zone, style: const pw.TextStyle(fontSize: 6.5, color: darkText))),
              pw.Padding(padding: const pw.EdgeInsets.all(3.0), child: pw.Text(p.area.isNotEmpty ? p.area : 'Conforme a plano referencial', style: const pw.TextStyle(fontSize: 6.5, color: darkText))),
              pw.Padding(padding: const pw.EdgeInsets.all(3.0), child: pw.Text(insumo, style: const pw.TextStyle(fontSize: 6.2, color: PdfColors.grey800))),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildSignaturesBlock(TrapLayoutModel layout) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: borderColor, width: 0.6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('LEVANTÓ Y CERTIFICÓ (EJ EXTERMINADORES):', style: pw.TextStyle(fontSize: 5.8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 1),
              pw.Text(layout.technicianName, style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: darkText)),
              pw.Text('Resp. de Operaciones  |  Tel. 813-175-9342', style: const pw.TextStyle(fontSize: 6.0, color: PdfColors.grey700)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('VALIDACIÓN Y APROBACIÓN POR EL CLIENTE:', style: pw.TextStyle(fontSize: 5.8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 1),
              pw.Text(layout.clientContactName.isNotEmpty ? layout.clientContactName : 'Nombre y Firma del Responsable', style: const pw.TextStyle(fontSize: 6.8, color: darkText)),
              pw.Text('Firma de conformidad del layout en sitio', style: const pw.TextStyle(fontSize: 6.0, color: PdfColors.grey700)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTechnicalBlueprintGrid(
    String title, {
    List<TrapWallPath> walls = const [],
    double canvasW = 470,
    double canvasH = 340,
  }) {
    if (walls.isNotEmpty) {
      return pw.Container(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        child: pw.Stack(
          fit: pw.StackFit.expand,
          children: [
            // Cuadrícula técnica sutil de fondo
            _buildPdfGridLines(canvasW, canvasH),

            // Muros y perímetros
            ...walls.map((wall) {
              if (wall.points.length >= 3 && wall.isClosed) {
                return pw.Polygon(
                  points: wall.points.map((p) => PdfPoint(p.x * canvasW, p.y * canvasH)).toList(),
                  fillColor: const PdfColor.fromInt(0x180F2B48),
                  strokeColor: primaryColor,
                  strokeWidth: 2.0,
                  close: true,
                );
              } else if (wall.points.length >= 2) {
                return pw.InkList(
                  points: [wall.points.map((p) => PdfPoint(p.x * canvasW, p.y * canvasH)).toList()],
                  strokeColor: primaryColor,
                  strokeWidth: 2.0,
                );
              }
              return pw.SizedBox();
            }),

            // Etiquetas de áreas/naves trazadas
            ...walls.where((w) => w.label.isNotEmpty && w.points.isNotEmpty).map((wall) {
              final cx = wall.points.map((p) => p.x).reduce((a, b) => a + b) / wall.points.length;
              final cy = wall.points.map((p) => p.y).reduce((a, b) => a + b) / wall.points.length;
              return pw.Positioned(
                left: (cx * canvasW) - 30,
                top: (cy * canvasH) - 7,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(3),
                    border: pw.Border.all(color: primaryColor, width: 0.6),
                  ),
                  child: pw.Text(
                    wall.label,
                    style: pw.TextStyle(fontSize: 6.2, fontWeight: pw.FontWeight.bold, color: primaryColor),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    }

    return pw.Container(
      color: const PdfColor.fromInt(0xFFF1F5F9),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Container(
            width: 36,
            height: 36,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: primaryColor, width: 1.5),
              borderRadius: pw.BorderRadius.circular(4),
              color: PdfColors.white,
            ),
            alignment: pw.Alignment.center,
            child: pw.Text('PLANO', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            title.isNotEmpty ? title : 'CROQUIS ESQUEMÁTICO DE INSTALACIÓN',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Lienzo de distribución técnica para ubicación perimetral e interior de dispositivos.',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfGridLines(double width, double height) {
    final List<List<PdfPoint>> gridPoints = [];
    const double step = 25.0;
    for (double x = step; x < width; x += step) {
      gridPoints.add([PdfPoint(x, 0), PdfPoint(x, height)]);
    }
    for (double y = step; y < height; y += step) {
      gridPoints.add([PdfPoint(0, y), PdfPoint(width, y)]);
    }
    return pw.InkList(
      points: gridPoints,
      strokeColor: const PdfColor.fromInt(0xFFE2E8F0),
      strokeWidth: 0.5,
    );
  }

  static pw.Widget _buildNorthIndicator() {
    return pw.Container(
      width: 24,
      height: 24,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: primaryColor, width: 1.0),
      ),
      alignment: pw.Alignment.center,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Container(
            width: 4,
            height: 4,
            decoration: const pw.BoxDecoration(
              color: PdfColors.red800,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Text('N', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: primaryColor)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 3),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Documento emitido conforme a la NOM-256-SSA1-2012 y lineamientos de auditoría industrial (AIB, BRC, Distintivo H).',
            style: const pw.TextStyle(fontSize: 5.8, color: PdfColors.grey600),
          ),
          pw.Text(
            'EJ Exterminadores   |   www.ejexterminadores.com   |   Monterrey, N.L.',
            style: pw.TextStyle(fontSize: 5.8, fontWeight: pw.FontWeight.bold, color: primaryColor),
          ),
        ],
      ),
    );
  }
}
