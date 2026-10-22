import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule_model.dart';

class SchedulePdfService {
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF0F2B48); // Azul marino corporativo
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

  /// Procesa la firma para volverla transparente y recortar espacio en blanco
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

          final isWhiteOrLight = r > 195 && g > 195 && b > 195;
          final isTransparent = a < 30;

          if (isWhiteOrLight || isTransparent) {
            pixels[idx + 3] = 0;
          } else {
            hasInk = true;
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }

      if (!hasInk || minX >= maxX || minY >= maxY) return rawBytes;

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
      final pngBytes = await croppedImage.toByteData(format: ui.ImageByteFormat.png);

      return pngBytes?.buffer.asUint8List() ?? rawBytes;
    } catch (_) {
      return rawBytes;
    }
  }

  /// Generador principal de PDF del Calendario de Servicios
  static Future<Uint8List> generateSchedulePdf(ScheduleModel schedule) async {
    final pdf = pw.Document();

    // 1. Cargar logotipo corporativo
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      final rawBytes = logoData.buffer.asUint8List();
      final trimmedBytes = await _autoTrimLogoBorders(rawBytes);
      logoImage = pw.MemoryImage(trimmedBytes);
    } catch (_) {
      logoImage = null;
    }

    // 2. Cargar firma registrada de reportes si existe
    Uint8List? processedSignature;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSignBase64 = prefs.getString('ej_saved_tech_sign');
      if (savedSignBase64 != null && savedSignBase64.isNotEmpty) {
        final rawSig = base64Decode(savedSignBase64);
        processedSignature = await _processSignature(rawSig);
      }
    } catch (_) {}

    // 3. Tema con marca de agua
    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      buildBackground: (context) {
        return pw.FullPage(
          ignoreMargins: true,
          child: pw.Center(
            child: pw.Opacity(
              opacity: 0.08,
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

    // 4. MultiPage
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => _buildHeader(schedule, logoImage),
        footer: (context) => _buildFooter(context, schedule),
        build: (context) => [
          _buildCompanyAndClientInfo(schedule),
          pw.SizedBox(height: 8),

          _buildProgramOverview(schedule),
          pw.SizedBox(height: 8),

          _buildVisitsTable(schedule),
          pw.SizedBox(height: 10),

          _buildConditionsAndNotes(schedule),
          pw.SizedBox(height: 16),

          _buildSignaturesBlock(schedule, processedSignature),
        ],
      ),
    );

    return pdf.save();
  }

  // --- ENCABEZADO SUPERIOR ---
  static pw.Widget _buildHeader(ScheduleModel schedule, pw.MemoryImage? logo) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final firstVisit = schedule.visits.isNotEmpty ? schedule.visits.first.date : schedule.startDate;
    final lastVisit = schedule.visits.isNotEmpty ? schedule.visits.last.date : schedule.startDate;
    final monthFormat = DateFormat('MMM yyyy', 'es_MX');

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
                    'Programa Oficial de Mantenimiento Periódico',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: pw.BorderRadius.circular(5),
              border: pw.Border.all(color: borderColor),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'CRONOGRAMA: ${schedule.folio}',
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.Text(
                  'Emisión: ${dateFormat.format(schedule.createdAt)}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                ),
                pw.Text(
                  'Período: ${monthFormat.format(firstVisit).toUpperCase()} - ${monthFormat.format(lastVisit).toUpperCase()}',
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

  // --- SECCIÓN PRESTADOR Y CLIENTE ---
  static pw.Widget _buildCompanyAndClientInfo(ScheduleModel schedule) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Prestador
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Datos del Prestador'),
              pw.SizedBox(height: 3),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
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
                    _infoItem('Responsable:', schedule.elaboratedBy.isNotEmpty ? schedule.elaboratedBy : 'EJ Exterminadores'),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        // Cliente
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Datos del Cliente'),
              pw.SizedBox(height: 3),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(4),
                  color: PdfColors.white,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoItem('Razón Social:', schedule.clientBusinessName.isNotEmpty ? schedule.clientBusinessName : schedule.clientContactName),
                    _infoItem('Contacto:', schedule.clientContactName.isNotEmpty ? schedule.clientContactName : 'N/A'),
                    _infoItem('Dirección:', schedule.clientAddress.isNotEmpty ? schedule.clientAddress : 'N/A'),
                    _infoItem('Teléfono:', schedule.clientPhone.isNotEmpty ? schedule.clientPhone : 'N/A'),
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
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkText),
            ),
            pw.TextSpan(
              text: value,
              style: const pw.TextStyle(fontSize: 7.5, color: darkText),
            ),
          ],
        ),
      ),
    );
  }

  // --- RESUMEN DEL PROGRAMA ---
  static pw.Widget _buildProgramOverview(ScheduleModel schedule) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: borderColor, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                schedule.title.toUpperCase(),
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Frecuencia: ${schedule.recurrenceDescription} • Horario Base: ${schedule.defaultTime}',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              '${schedule.totalVisits} SERVICIOS PROGRAMADOS',
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- TABLA DE VISITAS ---
  static pw.Widget _buildVisitsTable(ScheduleModel schedule) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final monthFormat = DateFormat('MMMM yyyy', 'es_MX');
    final dayNameFormat = DateFormat('EEEE', 'es_MX');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Cronograma de Visitas e Inspecciones'),
        pw.SizedBox(height: 3),
        pw.Table(
          border: pw.TableBorder.all(color: borderColor, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(28), // #
            1: pw.FlexColumnWidth(2.2), // Mes
            2: pw.FlexColumnWidth(2.5), // Fecha
            3: pw.FlexColumnWidth(2.2), // Día
            4: pw.FlexColumnWidth(1.8), // Horario
            5: pw.FlexColumnWidth(4.0), // Servicio
            6: pw.FlexColumnWidth(3.0), // Conformidad
          },
          children: [
            // Encabezados
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: lightBg),
              children: [
                _th('#'),
                _th('Mes / Año'),
                _th('Fecha Programada'),
                _th('Día'),
                _th('Horario'),
                _th('Tipo de Servicio'),
                _th('Firma / Sello Recibido'),
              ],
            ),
            // Filas
            ...schedule.visits.map((visit) {
              final isEven = visit.visitNumber % 2 == 0;
              final bgColor = isEven ? PdfColors.white : PdfColor.fromInt(0xFFFAFAFA);
              final dayName = dayNameFormat.format(visit.date);
              final capitalizedDay = dayName[0].toUpperCase() + dayName.substring(1);
              final monthName = monthFormat.format(visit.date);
              final capitalizedMonth = monthName[0].toUpperCase() + monthName.substring(1);

              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bgColor),
                children: [
                  _td('${visit.visitNumber}', bold: true, align: pw.TextAlign.center),
                  _td(capitalizedMonth, bold: true),
                  _td(dateFormat.format(visit.date), bold: true),
                  _td(capitalizedDay),
                  _td(visit.time),
                  _td(visit.serviceType),
                  pw.Container(
                    height: 22,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    alignment: pw.Alignment.center,
                    child: visit.status == 'Realizada'
                        ? pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFFE8F5E9),
                              borderRadius: pw.BorderRadius.circular(2),
                              border: pw.Border.all(color: PdfColor.fromInt(0xFF81C784), width: 0.5),
                            ),
                            child: pw.Text(
                              'REALIZADO',
                              style: pw.TextStyle(
                                fontSize: 6.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromInt(0xFF2E7D32),
                              ),
                            ),
                          )
                        : pw.Text(
                            '____________________',
                            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey400),
                          ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _th(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _td(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      alignment: align == pw.TextAlign.center ? pw.Alignment.center : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.0,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: darkText,
        ),
        textAlign: align,
      ),
    );
  }

  // --- CONDICIONES Y NOTAS ---
  static pw.Widget _buildConditionsAndNotes(ScheduleModel schedule) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Condiciones del Cronograma y Recomendaciones'),
        pw.SizedBox(height: 3),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderColor, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
            color: PdfColors.white,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _bullet('1. Las fechas aquí programadas han sido acordadas de común acuerdo con el cliente.'),
              _bullet('2. En caso de requerir reprogramación de una visita, favor de avisar con un mínimo de 24 horas de anticipación.'),
              _bullet('3. El cliente se compromete a brindar las facilidades de acceso, agua y energía requeridas para el servicio.'),
              _bullet('4. Al concluir cada visita se extenderá la Orden de Trabajo y el Certificado Sanitario avalado ante la SSA.'),
              if (schedule.notes.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: 'Indicaciones especiales: ',
                        style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: darkText),
                      ),
                      pw.TextSpan(
                        text: schedule.notes,
                        style: const pw.TextStyle(fontSize: 7.0, color: PdfColors.grey800),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _bullet(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 7.0, color: darkText)),
    );
  }

  // --- FIRMAS ---
  static pw.Widget _buildSignaturesBlock(ScheduleModel schedule, Uint8List? repSignature) {
    final repName = schedule.elaboratedBy.isNotEmpty ? schedule.elaboratedBy : 'EJ Exterminadores';
    final clientName = schedule.clientContactName.isNotEmpty ? schedule.clientContactName : schedule.clientBusinessName;

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // Prestador
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                height: 52,
                width: 200,
                alignment: pw.Alignment.bottomCenter,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: darkText, width: 1.2)),
                ),
                child: repSignature != null
                    ? pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Image(pw.MemoryImage(repSignature), fit: pw.BoxFit.contain),
                      )
                    : pw.SizedBox(height: 52),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                repName,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkText),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'EJ Exterminadores - Coordinación de Servicios',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 40),
        // Cliente
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                height: 52,
                width: 200,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: darkText, width: 1.2)),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                clientName.isNotEmpty ? clientName : 'Firma de Conformidad del Cliente',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkText),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Aceptación de Calendario y Fechas Acordadas',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context, ScheduleModel schedule) {
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
            'EJ Exterminadores • Tel. 813-175-9342 • Licencia Sanitaria S.S.A.',
            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }
}
