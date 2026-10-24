import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/contract_model.dart';

class ContractPdfService {
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF0F2B48);   // Azul Marino Institucional
  static const PdfColor secondaryColor = PdfColor.fromInt(0xFF1E6091); // Azul Medio
  static const PdfColor lightBg = PdfColor.fromInt(0xFFF4F6F9);        // Fondo gris suave
  static const PdfColor borderColor = PdfColor.fromInt(0xFFD1D5DB);    // Borde
  static const PdfColor darkText = PdfColor.fromInt(0xFF1F2937);       // Texto oscuro
  static const PdfColor accentGold = PdfColor.fromInt(0xFFB45309);     // Dorado / Ámbar formal

  /// Recorte automático de bordes blancos del logotipo institucional
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

  static Future<pw.ImageProvider?> _loadImageFromFile(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return pw.MemoryImage(bytes);
      }
    } catch (_) {}
    return null;
  }

  /// Generador del Contrato / Póliza Legal en PDF
  static Future<Uint8List> generateContractPdf(ContractModel contract) async {
    try {
      await initializeDateFormatting('es_MX', null);
    } catch (_) {}

    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final ineFrontImage = await _loadImageFromFile(contract.ineFrontPath);
    final ineBackImage = await _loadImageFromFile(contract.ineBackPath);

    final dateFormat = DateFormat('dd \'de\' MMMM \'de\' yyyy', 'es_MX');
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 26),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      ),
    );

    // Documento MultiPage para paginación legal impecable
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => _buildPageHeader(contract, logoImage, context),
        footer: (context) => _buildPageFooter(contract, context),
        build: (context) {
          return [
            pw.SizedBox(height: 10),

            // Título Formal del Contrato
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'CONTRATO DE PRESTACIÓN DE SERVICIOS DE MANEJO INTEGRADO DE PLAGAS Y PÓLIZA DE MANTENIMIENTO',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'FOLIO OFICIAL: ${contract.folio}   |   CELEBRADO EL ${dateFormat.format(contract.creationDate).toUpperCase()}',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Proemio / Introducción Legal
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: borderColor, width: 0.6),
              ),
              child: pw.Text(
                'CONTRATO DE PRESTACIÓN DE SERVICIOS QUE CELEBRAN, POR UNA PARTE, "EJ EXTERMINADORES" (EN LO SUCESIVO "EL PRESTADOR"), Y POR LA OTRA PARTE, LA PERSONA FÍSICA O MORAL CUYOS DATOS SE IDENTIFICAN EN EL PRESENTE INSTRUMENTO (EN LO SUCESIVO "EL CLIENTE"), REPRESENTADA POR LA PERSONA CUYA IDENTIDAD Y FACULTADES CONSTAN EN EL PRESENTE DOCUMENTO, SUJETÁNDOSE AMBAS PARTES AL TENOR DE LAS SIGUIENTES DECLARACIONES Y CLÁUSULAS:',
                textAlign: pw.TextAlign.justify,
                style: const pw.TextStyle(fontSize: 7.8, color: darkText, lineSpacing: 1.15),
              ),
            ),
            pw.SizedBox(height: 10),

            // SECCIÓN DECLARACIONES
            _buildSectionHeader('I. DECLARACIONES DE LAS PARTES'),
            pw.SizedBox(height: 4),

            _buildDeclarationItem(
              'I. Declara "EL PRESTADOR":',
              'a) Ser una empresa formalmente establecida y dedicada profesionalmente al Control y Manejo Integrado de Plagas Urbanas, Comerciales e Industriales.\n'
              'b) Contar con personal capacitado, equipo técnico adecuado y emplear exclusivamente insumos químicos y plaguicidas autorizados por la Secretaría de Salud (SSA) y la COFEPRIS.\n'
              'c) Tener su domicilio operativo en Monterrey, Nuevo León, con línea de atención telefónica 813-175-9342 y sitio web oficial www.ejexterminadores.com.',
            ),
            pw.SizedBox(height: 4),

            _buildDeclarationItem(
              'II. Declara "EL CLIENTE":',
              'a) Llamarse o estar legalmente constituido como "${contract.businessName.isNotEmpty ? contract.businessName : contract.clientName}", con Registro Federal de Contribuyentes (RFC) ${contract.rfc.isNotEmpty ? contract.rfc : 'NO PROPORCIONADO'}.\n'
              'b) Tener su domicilio o inmueble objeto del servicio en: ${contract.address.isNotEmpty ? contract.address : 'Domicilio de la empresa'}.\n'
              'c) Que su Representante Legal o Encargado autorizado es ${contract.representativeName.isNotEmpty ? contract.representativeName : contract.clientName}, con el cargo de "${contract.representativeRole.isNotEmpty ? contract.representativeRole : 'Representante / Encargado'}", quien acredita su identidad mediante Identificación Oficial (INE) cuyo cotejo fotográfico se incorpora formalmente al Anexo A del presente contrato.',
            ),
            pw.SizedBox(height: 10),

            // RESUMEN EJECUTIVO DE LA PÓLIZA
            _buildSectionHeader('II. TÉRMINOS Y CONDICIONES PARTICULARES DE LA PÓLIZA'),
            pw.SizedBox(height: 6),

            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              children: [
                _buildTableRow('Tipo de Póliza:', contract.serviceType, 'Vigencia:', '${contract.durationMonths} Meses (${dateFormat.format(contract.startDate)} al ${dateFormat.format(contract.endDate)})'),
                _buildTableRow('Frecuencia de Visitas:', contract.visitFrequency, 'Total de Servicios:', '${contract.totalVisits} visitas programadas'),
                _buildTableRow('Áreas Comprendidas:', contract.coveredAreas.isNotEmpty ? contract.coveredAreas : 'Todas las instalaciones del inmueble', 'Plagas a Controlar:', contract.targetPests.isNotEmpty ? contract.targetPests.join(', ') : 'Rastreros, cucarachas y roedores'),
                _buildTableRow('Costo por Servicio:', '${currencyFormat.format(contract.costPerVisit)} MXN', 'Costo Mensual:', '${currencyFormat.format(contract.monthlyCost)} MXN'),
                _buildTableRow('Monto Total Póliza:', '${currencyFormat.format(contract.totalContractCost)} MXN', 'Forma y Plazo de Pago:', '${contract.paymentMethod} - ${contract.paymentTerms}'),
              ],
            ),
            pw.SizedBox(height: 12),

            // CLÁUSULAS LEGALES
            _buildSectionHeader('III. CLÁUSULAS LEGALES'),
            pw.SizedBox(height: 6),

            _buildClause(
              'PRIMERA. OBJETO DEL CONTRATO.-',
              '"EL PRESTADOR" se obliga a prestar a favor de "EL CLIENTE" el servicio profesional de Manejo Integrado de Plagas (MIP), el cual comprende la inspección periódica, diagnóstico, aplicación de productos insecticidas de choque y residuales, instalación y revisión de cebaderos, trampas mecánicas o engomadas, y monitoreo preventivo en las áreas pactadas.',
            ),

            _buildClause(
              'SEGUNDA. VIGENCIA Y CALENDARIO DE SERVICIOS.-',
              'El presente contrato tendrá una vigencia obligatoria de ${contract.durationMonths} meses, iniciando el día ${dateFormat.format(contract.startDate)} y concluyendo el día ${dateFormat.format(contract.endDate)}. Las partes coordinarán el calendario de fechas para la ejecución de los ${contract.totalVisits} servicios convenidos bajo la frecuencia de ${contract.visitFrequency.toLowerCase()}.',
            ),

            _buildClause(
              'TERCERA. CONTRAPRESTACIÓN, MONEDA Y PLAZOS DE PAGO / CRÉDITO.-',
              '"EL CLIENTE" se compromete a pagar a "EL PRESTADOR" las contraprestaciones estipuladas en Pesos Mexicanos (Moneda Nacional - M.N. / MXN) a razón de ${currencyFormat.format(contract.monthlyCost)} M.N. mensual (o ${currencyFormat.format(contract.costPerVisit)} M.N. por servicio realizado), sumando un valor total contratado de ${currencyFormat.format(contract.totalContractCost)} M.N. El pago se efectuará mediante ${contract.paymentMethod.toLowerCase()} bajo el esquema y plazos convenidos de: "${contract.paymentTerms}". Las partes acuerdan expresamente que en caso de haberse estipulado crédito comercial (15, 30 días naturales o el plazo pactado entre ambas partes), "EL CLIENTE" se obliga a liquidar la factura correspondiente dentro del periodo concedido a partir de la entrega del reporte de servicio o comprobante fiscal.',
            ),

            _buildClause(
              'CUARTA. OBLIGACIONES DE "EL PRESTADOR".-',
              'a) Ejecutar los servicios con personal debidamente capacitado, uniformado y con equipo de protección personal.\n'
              'b) Emplear exclusivamente productos químicos con registro sanitario vigente ante COFEPRIS para uso en salud pública e industrial.\n'
              'c) Entregar al término de cada visita una Orden / Reporte de Servicio Técnico en formato digital (PDF) con firma de conformidad, detallando plaguicidas, dosificación y zonas tratadas.\n'
              'd) Atender contingencias extraordinarias de plaga en un lapso no mayor a 48 horas hábiles como parte de la garantía de la póliza activa.',
            ),

            _buildClause(
              'QUINTA. CORRESPONSABILIDAD Y OBLIGACIONES DE "EL CLIENTE".-',
              'Ambas partes reconocen que el control de plagas es un proceso biológico que exige trabajo mutuo. "EL CLIENTE" se obliga expresamente a:\n'
              'a) Mantener el orden y la higiene estricta en comedores, cafeterías, almacenes y áreas de producción, evitando acumulación de basura o restos de comida expuestos.\n'
              'b) No lavar, trapear con cloro ni desengrasar las orillas perimetrales y zócalos tratados durante un periodo mínimo de 5 días posteriores a cada aplicación para preservar la barrera química residual.\n'
              'c) Prohibir estrictamente el uso de insecticidas caseros en aerosol por parte de su personal, ya que repelen la plaga y neutralizan los cebos profesionales.\n'
              'd) Garantizar el libre acceso al personal técnico a cuartos de máquinas, registros, azoteas y bodegas en las fechas calendarizadas.',
            ),

            _buildClause(
              'SEXTA. GARANTÍA DE SERVICIO Y REFUERZOS.-',
              '"EL PRESTADOR" garantiza una reducción progresiva y el mantenimiento de niveles óptimos de bioseguridad en el inmueble. En caso de detectarse brotes o actividad imprevista de plaga dentro del periodo contractual, "EL PRESTADOR" realizará los refuerzos técnicos necesarios sin costo adicional, siempre que "EL CLIENTE" haya cumplido con las recomendaciones higiénicas y los días de exclusión señalados en los reportes.',
            ),

            if (contract.specialClauses.isNotEmpty) ...[
              _buildClause(
                'SÉPTIMA. ACUERDOS Y CONDICIONES ESPECIALES.-',
                contract.specialClauses,
              ),
            ],

            _buildClause(
              'OCTAVA. VALIDEZ DE FIRMA ELECTRÓNICA Y NO REPUDIO.-',
              'Las partes acuerdan y reconocen expresamente que el presente contrato, celebrado mediante dispositivos electrónicos y perfeccionado mediante la firma autógrafa digitalizada en pantalla y la captura de identificación oficial del representante, goza de plena validez jurídica, eficacia probatoria y obligatoriedad en términos de los Artículos 89, 89 bis, 90, 91 y 93 del Código de Comercio, así como del Artículo 1803 del Código Civil Federal.',
            ),

            _buildClause(
              'NOVENA. JURISDICCIÓN Y COMPETENCIA.-',
              'Para la interpretación y cumplimiento del presente contrato, ambas partes se someten voluntariamente a las leyes aplicables y a la jurisdicción de los Tribunales Competentes de la ciudad de ${contract.jurisdiction}, renunciando a cualquier otro fuero que por razón de sus domicilios presentes o futuros pudiera corresponderles.',
            ),
            pw.SizedBox(height: 16),

            // SECCIÓN DE FIRMAS DIGITALES
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderColor, width: 0.8),
                borderRadius: pw.BorderRadius.circular(6),
                color: lightBg,
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'EN CONSTANCIA DE CONFORMIDAD Y ACEPTACIÓN DE TODAS SUS CLÁUSULAS, LAS PARTES FIRMAN DIGITALMENTE EL PRESENTE INSTRUMENTO:',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      // Firma Cliente
                      pw.Expanded(
                        child: pw.Column(
                          children: [
                            pw.Container(
                              height: 65,
                              alignment: pw.Alignment.center,
                              decoration: pw.BoxDecoration(
                                border: pw.Border(bottom: pw.BorderSide(color: primaryColor, width: 1.2)),
                              ),
                              child: contract.clientSignatureBytes != null
                                  ? pw.Image(pw.MemoryImage(contract.clientSignatureBytes!), fit: pw.BoxFit.contain)
                                  : pw.Text('Firma Digital Registrada', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              contract.representativeName.isNotEmpty ? contract.representativeName : contract.clientName,
                              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkText),
                              textAlign: pw.TextAlign.center,
                            ),
                            pw.Text(
                              contract.representativeRole.isNotEmpty ? contract.representativeRole : 'Representante Legal / Encargado',
                              style: const pw.TextStyle(fontSize: 7.2, color: PdfColors.grey700),
                              textAlign: pw.TextAlign.center,
                            ),
                            pw.Text(
                              'POR: ${contract.businessName.isNotEmpty ? contract.businessName : contract.clientName}',
                              style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: secondaryColor),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 24),

                      // Firma Prestador
                      pw.Expanded(
                        child: pw.Column(
                          children: [
                            pw.Container(
                              height: 65,
                              alignment: pw.Alignment.center,
                              decoration: pw.BoxDecoration(
                                border: pw.Border(bottom: pw.BorderSide(color: primaryColor, width: 1.2)),
                              ),
                              child: contract.contractorSignatureBytes != null
                                  ? pw.Image(pw.MemoryImage(contract.contractorSignatureBytes!), fit: pw.BoxFit.contain)
                                  : pw.Text('Firma Autorizada', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'ING. JORGE LIZONDO / REP. TÉCNICO',
                              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkText),
                              textAlign: pw.TextAlign.center,
                            ),
                            pw.Text(
                              'Responsable de Operaciones y Servicios',
                              style: const pw.TextStyle(fontSize: 7.2, color: PdfColors.grey700),
                              textAlign: pw.TextAlign.center,
                            ),
                            pw.Text(
                              'POR: EJ EXTERMINADORES',
                              style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: secondaryColor),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ANEXO FOTOGRÁFICO DE LA IDENTIFICACIÓN (INE)
            if (ineFrontImage != null || ineBackImage != null) ...[
              pw.SizedBox(height: 18),
              pw.NewPage(), // Salto de página para que el anexo de la credencial quede en su propia hoja ejecutiva limpia
              pw.SizedBox(height: 10),

              _buildSectionHeader('ANEXO A: COTEJO DE IDENTIFICACIÓN OFICIAL (INE / IFE)'),
              pw.SizedBox(height: 6),
              pw.Text(
                'DOCUMENTO OFICIAL DIGITALIZADO DEL REPRESENTANTE LEGAL VINCULADO AL PRESENTE CONTRATO PARA EFECTOS DE IDENTIFICACIÓN Y NO REPUDIO:',
                style: const pw.TextStyle(fontSize: 7.5, color: darkText),
              ),
              pw.SizedBox(height: 10),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  if (ineFrontImage != null)
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderColor, width: 0.8),
                          borderRadius: pw.BorderRadius.circular(6),
                          color: lightBg,
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text('FRENTE DE LA CREDENCIAL (INE)', style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                            pw.SizedBox(height: 6),
                            pw.Container(
                              height: 155,
                              child: pw.Image(ineFrontImage, fit: pw.BoxFit.contain),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text('Cotejado al momento de la firma', style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey600)),
                          ],
                        ),
                      ),
                    ),
                  if (ineFrontImage != null && ineBackImage != null) pw.SizedBox(width: 14),
                  if (ineBackImage != null)
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderColor, width: 0.8),
                          borderRadius: pw.BorderRadius.circular(6),
                          color: lightBg,
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text('REVERSO DE LA CREDENCIAL (INE)', style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                            pw.SizedBox(height: 6),
                            pw.Container(
                              height: 155,
                              child: pw.Image(ineBackImage, fit: pw.BoxFit.contain),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text('Cotejado al momento de la firma', style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFFEF3C7),
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFFCD34D), width: 0.8),
                ),
                child: pw.Row(
                  children: [
                    pw.Text('*  ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accentGold)),
                    pw.Expanded(
                      child: pw.Text(
                        'CERTIFICACIÓN DE IDENTIDAD: La presente identificación oficial fue cotejada en presencia física del firmante y asociada unívocamente al folio contractual ${contract.folio}.',
                        style: const pw.TextStyle(fontSize: 7.2, color: PdfColors.grey900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  // --- WIDGETS AUXILIARES ---

  static pw.Widget _buildPageHeader(ContractModel contract, pw.ImageProvider? logoImage, pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: primaryColor, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            children: [
              if (logoImage != null) ...[
                pw.Container(
                  width: 44,
                  height: 44,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 8),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('EJ EXTERMINADORES', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.Text('CONTROL INTEGRAL DE PLAGAS', style: const pw.TextStyle(fontSize: 7.2, color: secondaryColor)),
                  pw.Text('Tel: 813-175-9342   |   www.ejexterminadores.com', style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.circular(3)),
                child: pw.Text('PÓLIZA DE SERVICIO', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ),
              pw.SizedBox(height: 2),
              pw.Text('Folio: ${contract.folio}', style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPageFooter(ContractModel contract, pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'EJ Exterminadores   |   Contrato de Póliza #${contract.folio}   |   www.ejexterminadores.com',
            style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey700),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: const pw.BoxDecoration(
        color: primaryColor,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 8.2, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _buildDeclarationItem(String title, String content) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(3),
        border: pw.Border.all(color: borderColor, width: 0.4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 2),
          pw.Text(content, style: const pw.TextStyle(fontSize: 7.2, color: darkText, lineSpacing: 1.15)),
        ],
      ),
    );
  }

  static pw.TableRow _buildTableRow(String label1, String value1, String label2, String value2) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(3.5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label1, style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.Text(value1, style: const pw.TextStyle(fontSize: 7.2, color: darkText)),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(3.5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label2, style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.Text(value2, style: const pw.TextStyle(fontSize: 7.2, color: darkText)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildClause(String title, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5.5),
      child: pw.RichText(
        textAlign: pw.TextAlign.justify,
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$title ',
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
            pw.TextSpan(
              text: text,
              style: const pw.TextStyle(fontSize: 7.2, color: darkText, lineSpacing: 1.15),
            ),
          ],
        ),
      ),
    );
  }
}
