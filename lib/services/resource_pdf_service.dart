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
  // 2. GENERADOR DE AVISO / COMUNICADO OFICIAL (DOSSIER EJECUTIVO DE 2 PÁGINAS)
  // ==========================================
  static Future<Uint8List> generateAdvisoryPdf(AdvisoryNoticeModel notice) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 18),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      ),
    );

    // ------------------------------------------
    // PÁGINA 1: DIAGNÓSTICO, MATRIZ Y REGLAS
    // ------------------------------------------
    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado Página 1
              _buildHeader(
                logoImage: logoImage,
                documentType: 'COMUNICADO OFICIAL DE MANEJO INTEGRADO DE PLAGAS',
                title: notice.title,
                subtitle: 'Dirigido a: ${notice.targetAudience}',
                badge1: notice.category,
                badge2: 'Bioseguridad y Exclusión',
              ),
              pw.SizedBox(height: 5),

              // Marco Normativo Oficial
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFEEF2FF),
                  borderRadius: pw.BorderRadius.circular(3),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFA5B4FC), width: 0.6),
                ),
                child: pw.Row(
                  children: [
                    pw.Text(
                      'MARCO NORMATIVO Y SANITARIO: ',
                      style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF3730A3)),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        notice.regulatoryFramework,
                        style: const pw.TextStyle(fontSize: 7.2, color: darkText),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 5),

              // Diagnóstico y Problemática
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                decoration: pw.BoxDecoration(
                  color: alertBg,
                  borderRadius: pw.BorderRadius.circular(3),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFFEB2B2), width: 0.6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DIAGNÓSTICO SANITARIO Y PROBLEMÁTICA OBSERVADA:',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: alertRed,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      notice.problemStatement,
                      style: const pw.TextStyle(fontSize: 7.3, color: darkText, lineSpacing: 1.14),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 5),

              // Matriz de Buenas Prácticas (Incorrecto vs Correcto)
              pw.Container(
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor, width: 0.6),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                      color: primaryColor,
                      child: pw.Text(
                        'MATRIZ OPERATIVA: ACCIÓN INCORRECTA HABITUAL vs. PROTOCOLO CORRECTO',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 7.3, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      ),
                    ),
                    pw.Table(
                      columnWidths: const {
                        0: pw.FlexColumnWidth(1),
                        1: pw.FlexColumnWidth(1),
                      },
                      border: pw.TableBorder.symmetric(inside: const pw.BorderSide(color: borderColor, width: 0.5)),
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: lightBg),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              child: pw.Text('ACCIÓN INCORRECTA HABITUAL [X]', style: pw.TextStyle(fontSize: 7.1, fontWeight: pw.FontWeight.bold, color: alertRed)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              child: pw.Text('PROTOCOLO CORRECTO DE LA EMPRESA [OK]', style: pw.TextStyle(fontSize: 7.1, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF166534))),
                            ),
                          ],
                        ),
                        ...notice.dosAndDonts.map((item) {
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                child: pw.RichText(
                                  text: pw.TextSpan(
                                    children: [
                                      pw.TextSpan(
                                        text: 'x  ',
                                        style: pw.TextStyle(fontSize: 7.1, fontWeight: pw.FontWeight.bold, color: alertRed),
                                      ),
                                      pw.TextSpan(
                                        text: item.badPractice,
                                        style: const pw.TextStyle(fontSize: 7.1, color: darkText, lineSpacing: 1.12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                child: pw.RichText(
                                  text: pw.TextSpan(
                                    children: [
                                      pw.TextSpan(
                                        text: '+  ',
                                        style: pw.TextStyle(fontSize: 7.1, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF166534)),
                                      ),
                                      pw.TextSpan(
                                        text: item.goodPractice,
                                        style: pw.TextStyle(fontSize: 7.1, fontWeight: pw.FontWeight.bold, color: darkText, lineSpacing: 1.12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 5),

              // Reglas Obligatorias para el Personal
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: const pw.BoxDecoration(color: primaryColor),
                      child: pw.Text(
                        'REGLAS DE HIGIENE Y EXCLUSIÓN OBLIGATORIAS PARA EL PERSONAL',
                        style: pw.TextStyle(fontSize: 7.3, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    ...notice.mandatoryRules.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final text = entry.value;
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              width: 12,
                              height: 12,
                              alignment: pw.Alignment.center,
                              decoration: const pw.BoxDecoration(
                                color: primaryColor,
                                shape: pw.BoxShape.circle,
                              ),
                              child: pw.Text(
                                '$idx',
                                style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                              ),
                            ),
                            pw.SizedBox(width: 5),
                            pw.Expanded(
                              child: pw.Text(
                                text,
                                style: pw.TextStyle(
                                  fontSize: 7.15,
                                  fontWeight: text.startsWith('PROHIBIDO') || text.startsWith('REGLA') || text.startsWith('ALIMENTO') || text.startsWith('COMEDORES') || text.startsWith('DESEMPAQUE')
                                      ? pw.FontWeight.bold
                                      : pw.FontWeight.normal,
                                  color: text.startsWith('PROHIBIDO') ? alertRed : darkText,
                                  lineSpacing: 1.12,
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
              pw.SizedBox(height: 5),

              // Medidas de Instalación, Exclusión Física y Mantenimiento
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: const pw.BoxDecoration(color: primaryColor),
                      child: pw.Text(
                        'MEDIDAS DE INSTALACIÓN, EXCLUSIÓN FÍSICA Y MANTENIMIENTO',
                        style: pw.TextStyle(fontSize: 7.3, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    ...notice.facilityRecommendations.map((tip) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('* ', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                            pw.Expanded(
                              child: pw.Text(tip, style: const pw.TextStyle(fontSize: 7.1, color: darkText, lineSpacing: 1.12)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              pw.Spacer(),

              // Pie de página 1
              _buildFooterWithPage(1, 2),
            ],
          );
        },
      ),
    );

    // ------------------------------------------
    // PÁGINA 2: BIOLOGÍA, FAQ Y CERTIFICACIÓN
    // ------------------------------------------
    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado compacto Página 2
              _buildPageTwoHeader(logoImage, notice),
              pw.SizedBox(height: 6),

              // Cronograma y Fases Biológicas
              pw.Container(
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor, width: 0.6),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                      color: secondaryColor,
                      child: pw.Text(
                        'CRONOGRAMA Y FASES DE EVOLUCIÓN BIOLÓGICA DEL TRATAMIENTO',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 7.4, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      ),
                    ),
                    pw.Table(
                      border: pw.TableBorder.symmetric(inside: const pw.BorderSide(color: borderColor, width: 0.5)),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(2.2),
                        1: pw.FlexColumnWidth(1.4),
                        2: pw.FlexColumnWidth(4.4),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: lightBg),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              child: pw.Text('FASE / ETAPA', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              child: pw.Text('TIEMPO', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              child: pw.Text('COMPORTAMIENTO Y EFECTIVIDAD TÉCNICA', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                            ),
                          ],
                        ),
                        ...notice.biologicalPhases.map((phase) {
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                child: pw.Text(phase.phaseName, style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                child: pw.Text(phase.timeFrame, style: const pw.TextStyle(fontSize: 7.0, color: darkText)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                child: pw.Text(phase.description, style: const pw.TextStyle(fontSize: 7.0, color: darkText, lineSpacing: 1.1)),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              // Preguntas Frecuentes Técnicas (FAQ de Campo)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF8FAFC),
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor, width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: const pw.BoxDecoration(color: secondaryColor),
                      child: pw.Text(
                        'PREGUNTAS FRECUENTES TÉCNICAS (FAQ DE CAMPO)',
                        style: pw.TextStyle(fontSize: 7.4, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      ),
                    ),
                    pw.SizedBox(height: 3.5),
                    ...notice.faqs.map((faq) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 3.5),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('P: ${faq.question}', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                            pw.SizedBox(height: 1),
                            pw.Text('R: ${faq.answer}', style: const pw.TextStyle(fontSize: 7.0, color: darkText, lineSpacing: 1.12)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              // Principio Técnico de Corresponsabilidad
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFFEF3C7),
                  borderRadius: pw.BorderRadius.circular(3),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFFCD34D), width: 0.6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PRINCIPIO TÉCNICO: RESPONSABILIDAD COMPARTIDA Y TRABAJO EN EQUIPO',
                      style: pw.TextStyle(
                        fontSize: 7.3,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF92400E),
                      ),
                    ),
                    pw.SizedBox(height: 1.5),
                    pw.Text(
                      notice.technicalDisclaimer,
                      style: const pw.TextStyle(fontSize: 7.0, color: PdfColors.grey900, lineSpacing: 1.12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              // Dictamen de Certificación y Firma Técnica
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor, width: 0.6),
                  borderRadius: pw.BorderRadius.circular(4),
                  color: lightBg,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'DICTAMEN Y PROTOCOLO CERTIFICADO POR:',
                          style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'ING. JORGE ELIZONDO / REP. TÉCNICO',
                          style: pw.TextStyle(fontSize: 8.2, fontWeight: pw.FontWeight.bold, color: darkText),
                        ),
                        pw.Text(
                          'Responsable de Operaciones y Bioseguridad  |  EJ Exterminadores',
                          style: const pw.TextStyle(fontSize: 7.0, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'ATENCIÓN Y ASESORÍA TÉCNICA:',
                          style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: secondaryColor),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Tel. 813-175-9342',
                          style: pw.TextStyle(fontSize: 8.2, fontWeight: pw.FontWeight.bold, color: primaryColor),
                        ),
                        pw.Text(
                          'www.ejexterminadores.com  |  Monterrey, N.L.',
                          style: const pw.TextStyle(fontSize: 7.0, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Pie de página 2
              _buildFooterWithPage(2, 2),
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
  static pw.Widget _buildPageTwoHeader(pw.ImageProvider? logoImage, AdvisoryNoticeModel notice) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: primaryColor, width: 1.5)),
      ),
      child: pw.Row(
        children: [
          if (logoImage != null) ...[
            pw.Container(
              width: 30,
              height: 30,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 8),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'EJ EXTERMINADORES   |   PROTOCOLO TÉCNICO COMPLEMENTARIO',
                  style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: secondaryColor),
                ),
                pw.Text(
                  notice.title,
                  style: pw.TextStyle(fontSize: 9.0, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              color: secondaryColor,
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              'Página 2: Biología y Validación',
              style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooterWithPage(int currentPage, int totalPages) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'EJ Exterminadores   |   Tel. 813-175-9342   |   www.ejexterminadores.com',
            style: const pw.TextStyle(fontSize: 7.2, color: PdfColors.grey700),
          ),
          pw.Text(
            'Página $currentPage de $totalPages',
            style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: primaryColor),
          ),
        ],
      ),
    );
  }
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
            'EJ Exterminadores   |   Tel. 813-175-9342   |   www.ejexterminadores.com',
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
