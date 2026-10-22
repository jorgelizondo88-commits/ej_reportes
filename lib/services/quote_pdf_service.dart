import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quote_model.dart';

class QuotePdfService {
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

      final pngBytes = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      return pngBytes?.buffer.asUint8List() ?? rawBytes;
    } catch (_) {
      return rawBytes;
    }
  }

  /// Método principal que compila y retorna los bytes del PDF de Cotización
  static Future<Uint8List> generateQuotePdf(QuoteModel quote) async {
    final pdf = pw.Document();

    // 1. Carga y recorte del logotipo corporativo
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      final rawBytes = logoData.buffer.asUint8List();
      final trimmedBytes = await _autoTrimLogoBorders(rawBytes);
      logoImage = pw.MemoryImage(trimmedBytes);
    } catch (_) {
      logoImage = null;
    }

    // 2. Carga y procesamiento de la firma del prestador
    Uint8List? processedSignature;
    if (quote.includeSignature) {
      Uint8List? rawSigBytes;
      if (quote.signatureBase64 != null && quote.signatureBase64!.isNotEmpty) {
        try {
          rawSigBytes = base64Decode(quote.signatureBase64!);
        } catch (_) {}
      }
      // Si no viene embebida en el modelo, cargar automáticamente la firma fija registrada en reportes
      if (rawSigBytes == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final savedSignBase64 = prefs.getString('ej_saved_tech_sign');
          if (savedSignBase64 != null && savedSignBase64.isNotEmpty) {
            rawSigBytes = base64Decode(savedSignBase64);
          }
        } catch (_) {}
      }

      if (rawSigBytes != null) {
        processedSignature = await _processSignature(rawSigBytes);
      }
    }

    // 3. Tema de página con marca de agua centrada
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

    // 4. Estructura de contenido multipágina
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => _buildHeader(quote, logoImage),
        footer: (context) => _buildFooter(context, quote),
        build: (context) => [
          _buildCompanyAndClientInfo(quote),
          pw.SizedBox(height: 8),

          if (quote.targetedPests.isNotEmpty) ...[
            _buildScopeSection(quote),
            pw.SizedBox(height: 8),
          ],

          ..._buildItemsTable(context, quote),
          pw.SizedBox(height: 8),

          _buildTotalsSection(quote),
          pw.SizedBox(height: 10),

          _buildTermsAndConditions(quote),
          pw.SizedBox(height: 16),

          _buildSignaturesBlock(quote, processedSignature),
        ],
      ),
    );

    return pdf.save();
  }

  // --- ENCABEZADO SUPERIOR ---
  static pw.Widget _buildHeader(QuoteModel quote, pw.MemoryImage? logo) {
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
                    'Licencia Sanitaria y Certificación en cada Servicio',
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
                  'COTIZACIÓN: ${quote.quoteFolio}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.Text(
                  'Fecha: ${dateFormat.format(quote.quoteDate)}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                ),
                pw.Text(
                  'Vigencia: ${quote.validDays} días (${dateFormat.format(quote.validUntilDate)})',
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
  static pw.Widget _buildCompanyAndClientInfo(QuoteModel quote) {
    final repName = quote.elaboratedBy.isNotEmpty ? quote.elaboratedBy : 'Asesor Comercial';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Empresa
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
                    _infoItem('Atención:', repName),
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
                    _infoItem('Razón Social:', quote.clientBusinessName.isNotEmpty ? quote.clientBusinessName : quote.clientContactName),
                    _infoItem('Contacto:', quote.clientContactName.isNotEmpty ? quote.clientContactName : 'N/A'),
                    _infoItem('Dirección:', quote.clientAddress.isNotEmpty ? quote.clientAddress : 'N/A'),
                    _infoItem('Teléfono:', quote.clientPhone.isNotEmpty ? quote.clientPhone : 'N/A'),
                    _infoItem('Correo:', quote.clientEmail.isNotEmpty ? quote.clientEmail : 'N/A'),
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

  // --- ALCANCE Y PLAGAS ---
  static pw.Widget _buildScopeSection(QuoteModel quote) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Alcance y Plagas Cubiertas'),
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
              pw.RichText(
                softWrap: true,
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Plagas objetivo: ',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkText),
                    ),
                    pw.TextSpan(
                      text: quote.targetedPests.join(', '),
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey900),
                    ),
                  ],
                ),
              ),
              if (quote.facilityType.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.RichText(
                  softWrap: true,
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: 'Tipo de Instalación: ',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkText),
                      ),
                      pw.TextSpan(
                        text: quote.facilityType,
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
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

  // --- TABLA DE CONCEPTOS COTIZADOS ---
  static List<pw.Widget> _buildItemsTable(pw.Context context, QuoteModel quote) {
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return [
      _buildSectionHeader('Conceptos y Servicios Cotizados'),
      pw.SizedBox(height: 3),
      pw.TableHelper.fromTextArray(
        context: context,
        border: pw.TableBorder.all(color: borderColor, width: 0.5),
        headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: accentColor),
        cellStyle: const pw.TextStyle(fontSize: 7.5),
        cellHeight: 16,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        headerAlignments: {
          0: pw.Alignment.center,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.center,
          3: pw.Alignment.center,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
        },
        cellAlignments: {
          0: pw.Alignment.center,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.center,
          3: pw.Alignment.center,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
        },
        columnWidths: {
          0: const pw.FixedColumnWidth(24),  // #
          1: const pw.FlexColumnWidth(4.5),  // Concepto
          2: const pw.FlexColumnWidth(1.1),  // Cant
          3: const pw.FlexColumnWidth(1.4),  // Unidad
          4: const pw.FlexColumnWidth(1.8),  // P. Unit
          5: const pw.FlexColumnWidth(2.0),  // Importe
        },
        headers: ['#', 'Descripción del Servicio / Concepto', 'Cant.', 'Unidad', 'P. Unitario', 'Importe'],
        data: List.generate(quote.items.length, (index) {
          final item = quote.items[index];
          final descriptionDisplay = item.description.isNotEmpty
              ? '${item.concept}\n${item.description}'
              : item.concept;

          final qtyFormatted = item.quantity == item.quantity.roundToDouble()
              ? item.quantity.toInt().toString()
              : item.quantity.toStringAsFixed(1);

          return [
            (index + 1).toString(),
            descriptionDisplay,
            qtyFormatted,
            item.unit,
            currency.format(item.unitPrice),
            currency.format(item.totalPrice),
          ];
        }),
      ),
    ];
  }

  // --- DESGLOSE DE TOTALES ---
  static pw.Widget _buildTotalsSection(QuoteModel quote) {
    final currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 230,
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: borderColor, width: 0.5),
          borderRadius: pw.BorderRadius.circular(4),
          color: lightBg,
        ),
        child: pw.Column(
          children: [
            _totalRow('Subtotal:', currency.format(quote.subtotal)),
            if (quote.applyIva) ...[
              pw.SizedBox(height: 2),
              _totalRow('I.V.A. (16%):', currency.format(quote.ivaAmount)),
            ],
            pw.Divider(color: borderColor, height: 6, thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL:',
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.Text(
                  '${currency.format(quote.totalAmount)} MXN',
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: darkText)),
        pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkText)),
      ],
    );
  }

  // --- CONDICIONES COMERCIALES Y TÉRMINOS ---
  static pw.Widget _buildTermsAndConditions(QuoteModel quote) {
    final rawLines = quote.termsAndConditions
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Términos y Condiciones del Servicio'),
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
              ...rawLines.map((line) {
                final match = RegExp(r'^(\d+\.)\s*(.*)$').firstMatch(line);
                if (match != null) {
                  final number = match.group(1)!;
                  final content = match.group(2)!;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2.2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(
                          width: 13,
                          child: pw.Text(
                            number,
                            style: pw.TextStyle(
                              fontSize: 7.0,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            content,
                            style: const pw.TextStyle(fontSize: 7.0, color: darkText),
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2.2),
                  child: pw.Text(
                    line,
                    style: const pw.TextStyle(fontSize: 7.0, color: darkText),
                    softWrap: true,
                  ),
                );
              }),
              if (quote.notes.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.RichText(
                  softWrap: true,
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: 'Notas adicionales: ',
                        style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: darkText),
                      ),
                      pw.TextSpan(
                        text: quote.notes,
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

  // --- BLOQUE DE FIRMAS ---
  static pw.Widget _buildSignaturesBlock(QuoteModel quote, Uint8List? repSignature) {
    final repName = quote.elaboratedBy.isNotEmpty ? quote.elaboratedBy : 'EJ Exterminadores';
    final clientName = quote.clientContactName.isNotEmpty ? quote.clientContactName : quote.clientBusinessName;

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // Firma del Prestador (Asesor / Técnico)
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                height: 54,
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
                    : pw.SizedBox(height: 54),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                repName,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkText),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'EJ Exterminadores - Representante Comercial',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 40),
        // Firma de Conformidad / Aceptación del Cliente
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                height: 54,
                width: 200,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: darkText, width: 1.2)),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                clientName.isNotEmpty ? clientName : 'Nombre y Firma del Cliente',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkText),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Aceptación de Cotización y Condiciones',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context, QuoteModel quote) {
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
            'EJ Exterminadores - Whatsapp: 813-175-9342 - Cotización de Servicios',
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
