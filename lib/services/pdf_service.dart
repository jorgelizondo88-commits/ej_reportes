import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/report_model.dart';
import '../models/trap_monitoring_model.dart';

class PdfService {
  // Paleta de colores corporativos
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF0F2B48); // Azul marino oscuro
  static const PdfColor accentColor = PdfColor.fromInt(0xFF1E6091);  // Azul medio
  static const PdfColor lightBg = PdfColor.fromInt(0xFFF4F6F9);      // Gris fondo suave
  static const PdfColor borderColor = PdfColor.fromInt(0xFFD1D5DB);  // Gris borde
  static const PdfColor darkText = PdfColor.fromInt(0xFF1F2937);

  /// Algoritmo para eliminar márgenes blancos o transparentes alrededor del logo
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

      minX = (minX - 3).clamp(0, width - 1);
      minY = (minY - 3).clamp(0, height - 1);
      maxX = (maxX + 3).clamp(0, width - 1);
      maxY = (maxY + 3).clamp(0, height - 1);

      final cropWidth = (maxX - minX + 1).toDouble();
      final cropHeight = (maxY - minY + 1).toDouble();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final srcRect = ui.Rect.fromLTWH(minX.toDouble(), minY.toDouble(), cropWidth, cropHeight);
      final dstRect = ui.Rect.fromLTWH(0, 0, cropWidth, cropHeight);

      canvas.drawImageRect(image, srcRect, dstRect, ui.Paint());
      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(cropWidth.toInt(), cropHeight.toInt());
      final pngData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);

      return pngData?.buffer.asUint8List() ?? rawBytes;
    } catch (_) {
      return rawBytes;
    }
  }

  /// Elimina el fondo blanco de la firma (la hace transparente) y recorta
  /// el espacio vacío para que el trazo llene el área en el PDF sin deformarse.
  static Future<Uint8List> _processSignature(Uint8List rawBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(rawBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width;
      final height = image.height;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return rawBytes;

      final Uint8List pixels = Uint8List.fromList(byteData.buffer.asUint8List());

      int minX = width;
      int maxX = 0;
      int minY = height;
      int maxY = 0;
      bool hasInk = false;

      for (int y = 0; y < height; y++) {
        final rowOffset = y * width * 4;
        for (int x = 0; x < width; x++) {
          final idx = rowOffset + (x * 4);
          final r = pixels[idx];
          final g = pixels[idx + 1];
          final b = pixels[idx + 2];
          final a = pixels[idx + 3];

          // Blanco, gris claro o semitransparente = Fondo
          final isWhiteOrLight = r > 195 && g > 195 && b > 195;
          final isTransparent = a < 30;

          if (isWhiteOrLight || isTransparent) {
            pixels[idx + 3] = 0; // 100% transparente
          } else {
            // Tinta de la firma detectada
            hasInk = true;
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }

      if (!hasInk || minX >= maxX || minY >= maxY) {
        return rawBytes;
      }

      // Margen de seguridad de 8 píxeles alrededor de la firma
      minX = (minX - 8).clamp(0, width - 1);
      minY = (minY - 8).clamp(0, height - 1);
      maxX = (maxX + 8).clamp(0, width - 1);
      maxY = (maxY + 8).clamp(0, height - 1);

      final cropWidth = maxX - minX + 1;
      final cropHeight = maxY - minY + 1;

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        width,
        height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final transparentImage = await completer.future;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final srcRect = ui.Rect.fromLTWH(minX.toDouble(), minY.toDouble(), cropWidth.toDouble(), cropHeight.toDouble());
      final dstRect = ui.Rect.fromLTWH(0, 0, cropWidth.toDouble(), cropHeight.toDouble());

      canvas.drawImageRect(transparentImage, srcRect, dstRect, ui.Paint());
      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(cropWidth, cropHeight);
      final pngData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);

      return pngData?.buffer.asUint8List() ?? rawBytes;
    } catch (_) {
      return rawBytes;
    }
  }

  /// Método principal que compila y retorna los bytes del PDF
  static Future<Uint8List> generateServiceReportPdf(ServiceReport report) async {
    final pdf = pw.Document();

    // 1. Carga y recorte del logotipo
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      final rawBytes = logoData.buffer.asUint8List();
      final trimmedBytes = await _autoTrimLogoBorders(rawBytes);
      logoImage = pw.MemoryImage(trimmedBytes);
    } catch (_) {
      logoImage = null;
    }

    // 2. Pre-cargar fotos de evidencia
    List<_PreparedEvidence> loadedEvidences = [];
    for (var photo in report.photoEvidences) {
      final file = File(photo.path);
      if (await file.exists()) {
        try {
          final bytes = await file.readAsBytes();
          loadedEvidences.add(_PreparedEvidence(pw.MemoryImage(bytes), photo.description));
        } catch (_) {}
      }
    }

    // 3. Procesar firmas: Quitar fondo blanco y recortar al trazo exacto
    Uint8List? processedTechSignature;
    if (report.technicianSignature != null) {
      processedTechSignature = await _processSignature(report.technicianSignature!);
    }

    Uint8List? processedClientSignature;
    if (report.clientSignature != null) {
      processedClientSignature = await _processSignature(report.clientSignature!);
    }

    // 4. Marca de agua completamente derecha, centrada y sin rotación
    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      buildBackground: (context) {
        return pw.FullPage(
          ignoreMargins: true,
          child: pw.Center(
            child: pw.Opacity(
              opacity: 0.10,
              child: logoImage != null
                  ? pw.Image(logoImage, width: 440)
                  : pw.Text(
                'EJ EXTERMINADORES',
                style: pw.TextStyle(
                  fontSize: 48,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ),
          ),
        );
      },
    );

    // 5. Estructura de contenido multipágina
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => _buildHeader(report, logoImage),
        footer: (context) => _buildFooter(context, report),
        build: (context) => [
          _buildCompanyAndClientInfo(report),
          pw.SizedBox(height: 6),
          _buildFindingsAndPests(report),
          pw.SizedBox(height: 6),
          _buildChemicalsTable(report.chemicals),
          pw.SizedBox(height: 6),

          // Sección de Trampas condicional
          if (report.hasTraps && report.traps.isNotEmpty) ...[
            ..._buildTrapsMonitoringTable(context, report.traps),
            pw.SizedBox(height: 6),
          ],

          // Galería calibrada para 8 fotos por hoja (2 x 4)
          if (loadedEvidences.isNotEmpty) ...[
            _buildEvidenceGallery(loadedEvidences),
            pw.SizedBox(height: 6),
          ],

          // Bloque unificado de recomendaciones y firmas transparentes
          pw.Container(
            child: pw.Column(
              children: [
                _buildRecommendations(report),
                pw.SizedBox(height: 12),
                _buildSignaturesBlock(report, processedTechSignature, processedClientSignature),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // --- ENCABEZADO SUPERIOR ---
  static pw.Widget _buildHeader(ServiceReport report, pw.MemoryImage? logo) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: primaryColor, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null)
                pw.Container(
                  width: 58,
                  height: 48,
                  margin: const pw.EdgeInsets.only(right: 10),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                )
              else
                pw.Container(
                  width: 44,
                  height: 44,
                  margin: const pw.EdgeInsets.only(right: 10),
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'EJ',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'EJ EXTERMINADORES',
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  pw.Text(
                    'Control y Manejo Integral de Plagas Urbanas e Industriales',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Licencia Sanitaria y Certificacion en cada Servicio',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: pw.BorderRadius.circular(5),
              border: pw.Border.all(color: borderColor),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'FOLIO: ${report.reportFolio}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.Text(
                  'Fecha: ${dateFormat.format(report.serviceDate)}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                ),
                pw.Text(
                  'Horario: ${report.serviceTimeStart} - ${report.serviceTimeEnd}',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: primaryColor,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  // --- SECCIÓN EN DOS COLUMNAS: EMPRESA (IZQ) Y CLIENTE (DER) ---
  static pw.Widget _buildCompanyAndClientInfo(ServiceReport report) {
    final techDisplayName = report.technicianName.isNotEmpty
        ? report.technicianName
        : 'Técnico Especialista';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Datos de la Empresa'),
              pw.SizedBox(height: 3),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(4),
                  color: PdfColors.white,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoItem('Empresa:', 'EJ Exterminadores'),
                    _infoItem('Teléfono:', '813-175-9342'),
                    _infoItem('Correo:', 'ventas@ejexterminadores.com'),
                    _infoItem('Elaborado por:', techDisplayName),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Datos del Cliente'),
              pw.SizedBox(height: 3),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(4),
                  color: PdfColors.white,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoItem('Razón Social:', report.businessName.isNotEmpty ? report.businessName : report.clientName),
                    _infoItem('Contacto:', report.clientName.isNotEmpty ? report.clientName : 'N/A'),
                    _infoItem('Dirección:', report.clientAddress.isNotEmpty ? report.clientAddress : 'N/A'),
                    _infoItem('Teléfono:', report.clientPhone.isNotEmpty ? report.clientPhone : 'N/A'),
                    _infoItem('Correo:', report.clientEmail.isNotEmpty ? report.clientEmail : 'N/A'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _infoItem(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2.5),
      child: pw.RichText(
        softWrap: true,
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label ',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: darkText,
              ),
            ),
            pw.TextSpan(
              text: value.isNotEmpty ? value : 'N/A',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildFindingsAndPests(ServiceReport report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Diagnóstico y Plagas Objetivo'),
        pw.SizedBox(height: 4),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderColor, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.RichText(
                softWrap: true,
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Plagas tratadas: ',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkText),
                    ),
                    pw.TextSpan(
                      text: report.targetedPests.isNotEmpty ? report.targetedPests.join(', ') : 'Servicio Preventivo General',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey900),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 2.5),
              pw.Text(
                'Hallazgos e inspección inicial:',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkText),
              ),
              pw.Text(
                report.inspectionFindings.isNotEmpty ? report.inspectionFindings : 'Sin novedades críticas observadas durante el recorrido inicial.',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildChemicalsTable(List<ChemicalProduct> chemicals) {
    return pw.Column(
      children: [
        _buildSectionHeader('Control Químico Aplicado'),
        pw.SizedBox(height: 4),
        chemicals.isEmpty
            ? pw.Container(
          padding: const pw.EdgeInsets.all(5),
          alignment: pw.Alignment.centerLeft,
          child: pw.Text('No se requirió aplicación química en este servicio.',
              style: const pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic)),
        )
            : pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(color: borderColor, width: 0.5),
          headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: accentColor),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellHeight: 15,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.0),
            1: const pw.FlexColumnWidth(2.2),
            2: const pw.FlexColumnWidth(1.4),
            3: const pw.FlexColumnWidth(2.0),
            4: const pw.FlexColumnWidth(1.6),
            5: const pw.FlexColumnWidth(2.5),
          },
          headers: ['Producto', 'Ingrediente Activo', 'Dosis', 'Reg. Sanitario', 'Método', 'Áreas Tratadas'],
          data: chemicals.map((c) => [
            c.name,
            c.activeIngredient,
            c.dosage,
            c.registrationNumber,
            c.applicationMethod,
            c.targetArea,
          ]).toList(),
        ),
      ],
    );
  }

  static List<pw.Widget> _buildTrapsMonitoringTable(pw.Context context, List<TrapMonitoring> traps) {
    return [
      _buildSectionHeader('Inspección de Roedores: Cebaderos y Trampas Mecánicas'),
      pw.SizedBox(height: 3),
      pw.TableHelper.fromTextArray(
        context: context,
        border: pw.TableBorder.all(color: borderColor, width: 0.5),
        headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: accentColor),
        cellStyle: const pw.TextStyle(fontSize: 7),
        cellHeight: 14,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.0),
          1: const pw.FlexColumnWidth(2.3),
          2: const pw.FlexColumnWidth(2.1),
          3: const pw.FlexColumnWidth(2.3),
          4: const pw.FlexColumnWidth(1.1),
          5: const pw.FlexColumnWidth(2.6),
        },
        headers: ['ID', 'Ubicación', 'Dispositivo', 'Consumo / Estado', 'Capturas', 'Observaciones'],
        data: traps.map((t) {
          final isBait = t.trapType.toLowerCase().contains('cebado');
          final statusDisplay = isBait
              ? '${t.consumptionPercentage}% Cebo (${t.status})'
              : t.status;

          return [
            t.id,
            t.location,
            t.trapType,
            statusDisplay,
            t.captureCount > 0 ? t.captureCount.toString() : '-',
            t.observations.isNotEmpty ? t.observations : 'Sin novedades',
          ];
        }).toList(),
      ),
    ];
  }

  static pw.Widget _buildEvidenceGallery(List<_PreparedEvidence> evidences) {
    List<pw.Widget> rows = [];
    for (int i = 0; i < evidences.length; i += 2) {
      final left = evidences[i];
      final right = (i + 1 < evidences.length) ? evidences[i + 1] : null;

      rows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _buildPhotoCard(left)),
              pw.SizedBox(width: 10),
              pw.Expanded(child: right != null ? _buildPhotoCard(right) : pw.Container()),
            ],
          ),
        ),
      );
    }

    if (rows.isEmpty) return pw.Container();

    final firstRow = rows.first;
    final otherRows = rows.skip(1).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Evidencia Fotográfica del Servicio'),
              pw.SizedBox(height: 6),
              firstRow,
            ],
          ),
        ),
        ...otherRows,
      ],
    );
  }

  static pw.Widget _buildPhotoCard(_PreparedEvidence item) {
    return pw.Container(
      height: 148,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Expanded(
            child: pw.ClipRRect(
              horizontalRadius: 3.5,
              verticalRadius: 3.5,
              child: pw.Image(item.image, fit: pw.BoxFit.cover),
            ),
          ),
          pw.Container(
            height: 22,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
            decoration: const pw.BoxDecoration(
              color: lightBg,
              border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5)),
            ),
            child: pw.Text(
              item.description.isNotEmpty ? item.description : 'Evidencia de inspección / aplicación',
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildRecommendations(ServiceReport report) {
    return pw.Column(
      children: [
        _buildSectionHeader('Recomendaciones del Servicio'),
        pw.SizedBox(height: 4),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderColor, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Recomendaciones físicas, higiénicas y de exclusión:',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkText),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                report.recommendations.isNotEmpty
                    ? report.recommendations
                    : 'Mantener limpieza periódica en drenajes, sellar grietas perimetrales y evitar acumulación de residuos orgánicos.',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- BLOQUE DE FIRMAS: TRAZO TRANSPARENTE, SIN FONDO BLANCO Y APROVECHANDO EL ESPACIO ---
  static pw.Widget _buildSignaturesBlock(
      ServiceReport report,
      Uint8List? techSignature,
      Uint8List? clientSignature,
      ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // Firma del Técnico Aplicador
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                height: 68,
                width: 210,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: darkText, width: 1.2)),
                ),
                child: techSignature != null
                    ? pw.Image(pw.MemoryImage(techSignature), fit: pw.BoxFit.contain)
                    : pw.Container(),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                report.technicianName.isNotEmpty ? report.technicianName : 'Técnico Especialista',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: darkText,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 1.5),
              pw.Text(
                'Firma del Técnico Aplicador',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.grey800,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),

        pw.SizedBox(width: 32),

        // Firma de Conformidad / Encargado
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                height: 68,
                width: 210,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: darkText, width: 1.2)),
                ),
                child: clientSignature != null
                    ? pw.Image(pw.MemoryImage(clientSignature), fit: pw.BoxFit.contain)
                    : pw.Container(),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                report.receivedByName.isNotEmpty ? report.receivedByName : 'Nombre y Firma',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: darkText,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 1.5),
              pw.Text(
                'Nombre y Firma de Conformidad',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.grey800,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context, ServiceReport report) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 5),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'EJ Exterminadores - Whatsapp: 813-175-9342 - Control de Plagas',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: primaryColor),
          ),
        ],
      ),
    );
  }
}

class _PreparedEvidence {
  final pw.MemoryImage image;
  final String description;
  _PreparedEvidence(this.image, this.description);
}