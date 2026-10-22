import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/pest_info_model.dart';
import '../models/advisory_notice_model.dart';

class ResourcePdfService {
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF0F2B48);   // Azul Marino Institucional
  static const PdfColor secondaryColor = PdfColor.fromInt(0xFF1E6091); // Azul Medio
  static const PdfColor lightBg = PdfColor.fromInt(0xFFF4F6F9);        // Gris fondo suave
  static const PdfColor borderColor = PdfColor.fromInt(0xFFD1D5DB);    // Gris borde
  static const PdfColor darkText = PdfColor.fromInt(0xFF1F2937);
  static const PdfColor alertRed = PdfColor.fromInt(0xFFC53030);
  static const PdfColor alertBg = PdfColor.fromInt(0xFFFFF5F5);

  /// Algoritmo para recortar márgenes blancos del logo
  static Future<Uint8List> _autoTrimLogoBorders(Uint8List rawBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(rawBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return rawBytes;

      final buffer = byteData.buffer.asUint32List();
      final width = image.width;
      final height = image.height;

      int minX = width;
      int maxX = 0;
      int minY = height;
      int maxY = 0;

      for (int y = 0; y < height; y++) {
        final rowOffset = y * width;
        for (int x = 0; x < width; x++) {
          final pixel = buffer[rowOffset + x];
          final r = pixel & 0xFF;
          final g = (pixel >> 8) & 0xFF;
          final b = (pixel >> 16) & 0xFF;
          final a = (pixel >> 24) & 0xFF;

          final isTransparent = a < 25;
          final isWhite = r > 242 && g > 242 && b > 242;

          if (!isTransparent && !isWhite) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }

      if (minX >= maxX || minY >= maxY) return rawBytes;

      const padding = 2;
      final cropX = (minX - padding).clamp(0, width);
      final cropY = (minY - padding).clamp(0, height);
      final cropWidth = (maxX - minX + 1 + (padding * 2)).clamp(1, width - cropX);
      final cropHeight = (maxY - minY + 1 + (padding * 2)).clamp(1, height - cropY);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(cropX.toDouble(), cropY.toDouble(), cropWidth.toDouble(), cropHeight.toDouble()),
        ui.Rect.fromLTWH(0, 0, cropWidth.toDouble(), cropHeight.toDouble()),
        ui.Paint(),
      );

      final croppedImage = await recorder.endRecording().toImage(cropWidth, cropHeight);
      final croppedByteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);

      return croppedByteData?.buffer.asUint8List() ?? rawBytes;
    } catch (_) {
      return rawBytes;
    }
  }

  static Future<pw.ImageProvider?> _loadLogoImage() async {
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      final trimmedLogoBytes = await _autoTrimLogoBorders(logoBytes.buffer.asUint8List());
      return pw.MemoryImage(trimmedLogoBytes);
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // 1. GENERADOR DE FICHA TÉCNICA DE PLAGA
  // ==========================================
  static Future<Uint8List> generatePestInfoPdf(PestInfoModel pest) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      ),
    );

    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado
              _buildHeader(
                logoImage: logoImage,
                documentType: 'FICHA TÉCNICA DE IDENTIFICACIÓN Y CONTROL',
                title: pest.name,
                subtitle: pest.scientificName,
                badge1: pest.category,
                badge2: pest.riskLevel,
              ),
              pw.SizedBox(height: 8),

              // Resumen general
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor, width: 0.5),
                ),
                child: pw.Text(
                  pest.summary,
                  style: const pw.TextStyle(fontSize: 8.2, color: darkText, lineSpacing: 1.2),
                ),
              ),
              pw.SizedBox(height: 8),

              // Sección 1: Hábitats y Hábitos (2 Columnas)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildSectionBox(
                      title: 'Zonas de Anidación y Refugio',
                      items: pest.habitats,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _buildSectionBox(
                      title: 'Comportamiento y Hábitos Biológicos',
                      items: pest.habits,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // Sección 2: Riesgos a la Salud y Señales (2 Columnas)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildAlertBox(
                      title: 'Riesgos a la Salud y Daños Materiales',
                      items: pest.healthRisks,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _buildSectionBox(
                      title: 'Señales de Presencia e Infestación',
                      items: pest.signs,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // Sección 3: Medidas Preventivas para el Cliente
              _buildSectionBox(
                title: 'Medidas Preventivas y Buenas Prácticas para el Cliente',
                items: pest.preventionTips,
                headerColor: secondaryColor,
              ),
              pw.SizedBox(height: 8),

              // Sección 4: Tratamiento Profesional EJ Exterminadores
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF0FDF4),
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFF86EFAC), width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TRATAMIENTO Y CONTROL PROFESIONAL POR EJ EXTERMINADORES',
                      style: pw.TextStyle(
                        fontSize: 8.2,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF166534),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      pest.professionalTreatment,
                      style: const pw.TextStyle(fontSize: 8.0, color: PdfColors.grey900, lineSpacing: 1.2),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Pie de página institucional
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ==========================================
  // 2. GENERADOR DE AVISO / COMUNICADO OFICIAL
  // ==========================================
  static Future<Uint8List> generateAdvisoryPdf(AdvisoryNoticeModel notice) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      ),
    );

    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado
              _buildHeader(
                logoImage: logoImage,
                documentType: 'COMUNICADO OFICIAL DE MANEJO INTEGRADO DE PLAGAS',
                title: notice.title,
                subtitle: 'Dirigido a: ${notice.targetAudience}',
                badge1: notice.category,
                badge2: 'Protocolo de Higiene y Exclusión',
              ),
              pw.SizedBox(height: 8),

              // Objetivo y Problemática
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: pw.BoxDecoration(
                  color: alertBg,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFFEB2B2), width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DIAGNÓSTICO Y PROBLEMÁTICA OBSERVADA:',
                      style: pw.TextStyle(
                        fontSize: 8.2,
                        fontWeight: pw.FontWeight.bold,
                        color: alertRed,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      notice.problemStatement,
                      style: const pw.TextStyle(fontSize: 8.0, color: darkText, lineSpacing: 1.2),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Reglas Obligatorias para el Personal
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: const pw.BoxDecoration(color: primaryColor),
                      child: pw.Text(
                        'REGLAS DE HIGIENE INDISPENSABLES PARA EL PERSONAL',
                        style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    ...notice.mandatoryRules.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final text = entry.value;
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 3.5),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              width: 14,
                              height: 14,
                              alignment: pw.Alignment.center,
                              decoration: const pw.BoxDecoration(
                                color: primaryColor,
                                shape: pw.BoxShape.circle,
                              ),
                              child: pw.Text(
                                '$idx',
                                style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                              ),
                            ),
                            pw.SizedBox(width: 6),
                            pw.Expanded(
                              child: pw.Text(
                                text,
                                style: pw.TextStyle(
                                  fontSize: 8.0,
                                  fontWeight: text.startsWith('PROHIBIDO') || text.startsWith('REGLA')
                                      ? pw.FontWeight.bold
                                      : pw.FontWeight.normal,
                                  color: text.startsWith('PROHIBIDO') ? alertRed : darkText,
                                  lineSpacing: 1.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Medidas de Instalaciones y Limpieza
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: const pw.BoxDecoration(color: secondaryColor),
                      child: pw.Text(
                        'RECOMENDACIONES PARA EL INMUEBLE Y LIMPIEZA',
                        style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    ...notice.facilityRecommendations.map((tip) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 3.0),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('  *  ', style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                            pw.Expanded(
                              child: pw.Text(tip, style: const pw.TextStyle(fontSize: 8.0, color: darkText, lineSpacing: 1.15)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Cuadro de Responsabilidad Compartida y Deslinde
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFFEF3C7), // Ámbar suave
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFFCD34D), width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PRINCIPIO TÉCNICO: RESPONSABILIDAD COMPARTIDA',
                      style: pw.TextStyle(
                        fontSize: 8.2,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF92400E),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      notice.technicalDisclaimer,
                      style: const pw.TextStyle(fontSize: 8.0, color: PdfColors.grey900, lineSpacing: 1.2),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Pie de página institucional
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ==========================================
  // WIDGETS AUXILIARES
  // ==========================================
  static pw.Widget _buildHeader({
    required pw.ImageProvider? logoImage,
    required String documentType,
    required String title,
    required String subtitle,
    required String badge1,
    required String badge2,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: primaryColor, width: 2.0)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logoImage != null) ...[
            pw.Container(
              width: 55,
              height: 55,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 10),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'EJ EXTERMINADORES   |   CONTROL INTEGRAL DE PLAGAS',
                  style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: secondaryColor, letterSpacing: 0.5),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  documentType,
                  style: const pw.TextStyle(fontSize: 7.2, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  title,
                  style: pw.TextStyle(fontSize: 13.0, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
                if (subtitle.isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    subtitle,
                    style: pw.TextStyle(fontSize: 8.2, fontStyle: pw.FontStyle.italic, color: PdfColors.grey800),
                  ),
                ],
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _badge(badge1, primaryColor),
              pw.SizedBox(height: 4),
              _badge(badge2, secondaryColor),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _badge(String text, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _buildSectionBox({
    required String title,
    required List<String> items,
    PdfColor headerColor = primaryColor,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: borderColor, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: pw.BoxDecoration(color: headerColor),
            child: pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            ),
          ),
          pw.SizedBox(height: 4),
          ...items.map((item) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2.5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(' - ', style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: headerColor)),
                  pw.Expanded(
                    child: pw.Text(item, style: const pw.TextStyle(fontSize: 7.8, color: darkText, lineSpacing: 1.15)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildAlertBox({
    required String title,
    required List<String> items,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: alertBg,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFFEB2B2), width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: const pw.BoxDecoration(color: alertRed),
            child: pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            ),
          ),
          pw.SizedBox(height: 4),
          ...items.map((item) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2.5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(' ! ', style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: alertRed)),
                  pw.Expanded(
                    child: pw.Text(item, style: const pw.TextStyle(fontSize: 7.8, color: darkText, lineSpacing: 1.15)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'EJ Exterminadores   |   Tel. 813-175-9342   |   Licencia Sanitaria S.S.A.',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
          pw.Text(
            'Documento Técnico Informativo',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }
}
