import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/cfdi_invoice_data.dart';

class InvoicePdfService {
  static const PdfColor primaryBlue = PdfColor.fromInt(0xFF2C6B9E); // Azul encabezados factura
  static const PdfColor darkBlue = PdfColor.fromInt(0xFF0F2B48);
  static const PdfColor lightGray = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor borderColor = PdfColor.fromInt(0xFFCBD5E1);
  static const PdfColor textDark = PdfColor.fromInt(0xFF1E293B);

  static Future<Uint8List> generateInvoicePdf(CfdiInvoiceData invoice) async {
    final pdf = pw.Document();

    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    final currencyFmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm:ss');
    final dateIsoFmt = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 20),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          italic: pw.Font.helveticaOblique(),
        ),
        header: (context) {
          if (context.pageNumber == 1) {
            return pw.SizedBox.shrink();
          }
          // En páginas subsiguientes (2 en adelante), barra de continuación elegante
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const pw.BoxDecoration(color: primaryBlue),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'EJ EXTERMINADORES - Factura ${invoice.fullFolio}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
                pw.Text(
                  'Cliente: ${invoice.receiverBusinessName}',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.white),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 4),
            child: pw.Column(
              children: [
                pw.Divider(color: borderColor, height: 4, thickness: 0.6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'RFC Proveedor Certificación: ${invoice.timbre?.rfcProvCertif ?? "PAC AUTORIZADO SAT"}',
                      style: const pw.TextStyle(fontSize: 5.8, color: textDark),
                    ),
                    pw.Text(
                      'ESTE DOCUMENTO ES UNA REPRESENTACIÓN IMPRESA DE UN CFDI (CFDI 4.0)',
                      style: pw.TextStyle(fontSize: 5.8, fontWeight: pw.FontWeight.bold, color: textDark),
                    ),
                    pw.Text(
                      'Página ${context.pageNumber} de ${context.pagesCount}',
                      style: pw.TextStyle(fontSize: 6.2, fontWeight: pw.FontWeight.bold, color: textDark),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        build: (context) => [
          // 1. CABECERA: LOGO + EMISOR + FOLIO
          _buildEmisorHeader(invoice, logoImage, dateFmt, dateIsoFmt),
          pw.SizedBox(height: 6),

          // 2. DATOS DEL CLIENTE / RECEPTOR
          _buildReceptorBox(invoice),
          pw.SizedBox(height: 6),

          // 3. METADATOS DEL TIMBRE / CSD
          _buildTimbreMetadataTable(invoice, dateIsoFmt),
          pw.SizedBox(height: 6),

          // 4. TABLA DE CONCEPTOS (Multilínea fluida)
          _buildConceptosTable(invoice, currencyFmt),
          pw.SizedBox(height: 6),

          // 5. BLOQUE DE TOTALES Y FISCALIDAD (En columna indivisible)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildTotalsBox(invoice, currencyFmt),
              pw.SizedBox(height: 6),
              _buildSellosAndQrBox(invoice),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Comprobante Fiscal Digital por Internet (CFDI 4.0) emitido por EJ Exterminadores - Manejo Integrado de Plagas',
                  style: const pw.TextStyle(fontSize: 5.6, color: PdfColors.grey700),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // --- 1. CABECERA EMISOR ---
  static pw.Widget _buildEmisorHeader(
    CfdiInvoiceData invoice,
    pw.ImageProvider? logoImage,
    DateFormat dateFmt,
    DateFormat dateIsoFmt,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logoImage != null)
          pw.Container(
            width: 82,
            height: 82,
            margin: const pw.EdgeInsets.only(right: 12),
            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
          ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                invoice.issuerCommercial,
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryBlue),
              ),
              pw.Text(
                invoice.issuerName,
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: textDark),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                'R.F.C.: ${invoice.issuerRfc}',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: textDark),
              ),
              pw.Text(invoice.issuerStreet, style: const pw.TextStyle(fontSize: 7.2, color: textDark)),
              pw.Text(invoice.issuerColony, style: const pw.TextStyle(fontSize: 7.2, color: textDark)),
              pw.Text(invoice.issuerCity, style: const pw.TextStyle(fontSize: 7.2, color: textDark)),
              pw.Text(invoice.issuerState, style: const pw.TextStyle(fontSize: 7.2, color: textDark)),
              pw.Text('Teléfonos: ${invoice.issuerPhone}', style: const pw.TextStyle(fontSize: 7.2, color: textDark)),
              pw.Text('Correo electrónico: ${invoice.issuerEmail}', style: const pw.TextStyle(fontSize: 7.2, color: textDark)),
              pw.SizedBox(height: 2),
              pw.Text(
                'Régimen Fiscal: ${invoice.issuerRegime}',
                style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: textDark),
              ),
            ],
          ),
        ),
        pw.Container(
          width: 175,
          child: pw.Column(
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: const pw.BoxDecoration(color: primaryBlue),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tipo de Comprobante', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.Text(invoice.voucherType, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ],
                ),
              ),
              _boxRow('Factura No.', invoice.fullFolio, isBig: true),
              _boxRow('Lugar y Fecha de Expedición', 'C.P.${invoice.expeditionZip} ${dateFmt.format(invoice.emissionDate)}'),
              _boxRow('Fecha y Hora de Emisión', dateIsoFmt.format(invoice.emissionDate)),
            ],
          ),
        ),
      ],
    );
  }

  // --- 2. CAJA RECEPTOR ---
  static pw.Widget _buildReceptorBox(CfdiInvoiceData invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: const pw.BoxDecoration(color: primaryBlue),
          child: pw.Text(
            'Datos del Cliente / Receptor:',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          ),
        ),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderColor, width: 0.6),
            color: lightGray,
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                invoice.receiverBusinessName,
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: textDark),
              ),
              if (invoice.receiverCommercialName.isNotEmpty &&
                  invoice.receiverCommercialName != invoice.receiverBusinessName)
                pw.Text(
                  invoice.receiverCommercialName,
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryBlue),
                ),
              pw.Text(
                'R.F.C.: ${invoice.receiverRfc}',
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: textDark),
              ),
              if (invoice.receiverAddress.isNotEmpty)
                pw.Text(
                  '${invoice.receiverAddress}, C.P. ${invoice.receiverZip}',
                  style: const pw.TextStyle(fontSize: 7.0, color: textDark),
                )
              else
                pw.Text('C.P. ${invoice.receiverZip}', style: const pw.TextStyle(fontSize: 7.0, color: textDark)),
              pw.Text(
                'Uso de CFDI: ${invoice.receiverCfdiUse}',
                style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: textDark),
              ),
              pw.Text(
                'Régimen Fiscal: ${invoice.receiverRegime}',
                style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: textDark),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 3. METADATOS TIMBRE CSD ---
  static pw.Widget _buildTimbreMetadataTable(CfdiInvoiceData invoice, DateFormat dateIsoFmt) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.6),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: primaryBlue),
          children: [
            _cellHeader('No. de Serie del CSD del Emisor'),
            _cellHeader('Folio Fiscal / UUID'),
            _cellHeader('Numero de Serie del CSD del SAT'),
            _cellHeader('Fecha y Hora de Certificación'),
          ],
        ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.white),
          children: [
            _cellBody(invoice.timbre?.noCertificadoEmisor ?? '00001000000518855488'),
            _cellBody(invoice.timbre?.uuid ?? 'PENDIENTE DE TIMBRADO', isBold: true),
            _cellBody(invoice.timbre?.noCertificadoSAT ?? '00001000000707568881'),
            _cellBody(invoice.timbre != null
                ? dateIsoFmt.format(invoice.timbre!.fechaCertificacion)
                : dateIsoFmt.format(invoice.emissionDate)),
          ],
        ),
      ],
    );
  }

  // --- 4. TABLA DE CONCEPTOS ---
  static pw.Widget _buildConceptosTable(CfdiInvoiceData invoice, NumberFormat currencyFmt) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(46),
        1: pw.FlexColumnWidth(4),
        2: pw.FixedColumnWidth(80),
        3: pw.FixedColumnWidth(80),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: primaryBlue),
          children: [
            _cellHeader('Cantidad', align: pw.TextAlign.center),
            _cellHeader('Descripción', align: pw.TextAlign.left),
            _cellHeader('Valor Unitario', align: pw.TextAlign.right),
            _cellHeader('Importe', align: pw.TextAlign.right),
          ],
        ),
        ...invoice.items.map((it) {
          return pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.white),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  it.quantity % 1 == 0 ? it.quantity.toInt().toString() : it.quantity.toString(),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textDark),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      it.description.toUpperCase(),
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textDark),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Clave de Producto o Servicio: ${it.satProductCode} ${it.satProductDesc}',
                      style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey800),
                    ),
                    pw.Text(
                      'Clave Unidad: ${it.satUnitCode} ${it.satUnitDesc}',
                      style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey800),
                    ),
                    pw.Text(
                      'Objeto Impuestos: ${it.taxObject}',
                      style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey800),
                    ),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  currencyFmt.format(it.unitPrice),
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 8, color: textDark),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  currencyFmt.format(it.subtotal),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textDark),
                ),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  // --- 5. INFORMACIÓN DEL COMPROBANTE Y TOTALES (ESPACIADO PERFECTO) ---
  static pw.Widget _buildTotalsBox(CfdiInvoiceData invoice, NumberFormat currencyFmt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: const pw.BoxDecoration(color: primaryBlue),
          child: pw.Text(
            'Información del Comprobante',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderColor, width: 0.6),
            color: PdfColors.white,
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Columna Izquierda: Condiciones de Pago, Letra y Datos Bancarios
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text('Forma de Pago: ', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: textDark)),
                        pw.Expanded(
                          child: pw.Text(invoice.paymentForm, style: const pw.TextStyle(fontSize: 7.2, color: textDark)),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2.5),
                    pw.Row(
                      children: [
                        pw.Text('Método de Pago: ', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: textDark)),
                        pw.Expanded(
                          child: pw.Text(invoice.paymentMethod, style: const pw.TextStyle(fontSize: 7.2, color: textDark)),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2.5),
                    pw.Row(
                      children: [
                        pw.Text('Condiciones de pago: ', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: textDark)),
                        pw.Expanded(
                          child: pw.Text(
                            'Institución Bancaria: ${invoice.bankInstitution}    No. de Cuenta: ${invoice.bankAccount}',
                            style: const pw.TextStyle(fontSize: 7.0, color: textDark),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2.5),
                    pw.Row(
                      children: [
                        pw.Text('Moneda: ', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: textDark)),
                        pw.Text(invoice.currency, style: const pw.TextStyle(fontSize: 7.0, color: textDark)),
                        pw.SizedBox(width: 12),
                        pw.Text('Tipo de cambio: ', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: textDark)),
                        pw.Text('\$ ${invoice.exchangeRate.toStringAsFixed(4)}', style: const pw.TextStyle(fontSize: 7.0, color: textDark)),
                        pw.SizedBox(width: 12),
                        pw.Text('Exportación: ', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: textDark)),
                        pw.Text(invoice.exportation, style: const pw.TextStyle(fontSize: 7.0, color: textDark)),
                      ],
                    ),
                    pw.SizedBox(height: 3.5),
                    pw.Text('Importe con letra:', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: textDark)),
                    pw.Text(
                      invoice.totalInWords,
                      style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: primaryBlue),
                    ),
                    if (invoice.observations.isNotEmpty) ...[
                      pw.SizedBox(height: 2.5),
                      pw.Text('Observaciones: ${invoice.observations}', style: const pw.TextStyle(fontSize: 6.8, color: textDark)),
                    ],
                  ],
                ),
              ),

              // Divisor vertical sutil para separar el método de pago de los importes
              pw.Container(
                width: 0.6,
                height: 72,
                color: borderColor,
                margin: const pw.EdgeInsets.symmetric(horizontal: 10),
              ),

              // Columna Derecha: Subtotal, IVA y TOTAL (Alineados a la derecha, cerca de las cantidades)
              pw.Container(
                width: 170,
                child: pw.Column(
                  children: [
                    _totalRow('Subtotal:', currencyFmt.format(invoice.subtotal)),
                    _totalRow('I.V.A. 16%:', currencyFmt.format(invoice.ivaAmount)),
                    pw.Divider(color: borderColor, height: 6, thickness: 0.6),
                    _totalRow('TOTAL:', currencyFmt.format(invoice.total), isTotal: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 6. PIE FISCAL: SELLOS, CADENA ORIGINAL Y QR ---
  static pw.Widget _buildSellosAndQrBox(CfdiInvoiceData invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: const pw.BoxDecoration(color: primaryBlue),
          child: pw.Text(
            'Cadena Original del complemento de certificación digital del SAT:',
            style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          ),
        ),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(
            invoice.timbre?.cadenaOriginal ?? '||1.1|PENDIENTE|...||',
            style: const pw.TextStyle(fontSize: 4.8, color: textDark, lineSpacing: 1.05),
          ),
        ),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Sellos a la izquierda
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: const pw.BoxDecoration(color: primaryBlue),
                    child: pw.Text(
                      'Sello Digital del Emisor:',
                      style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text(
                      invoice.timbre?.selloEmisor ?? 'PENDIENTE',
                      style: const pw.TextStyle(fontSize: 4.8, color: textDark, lineSpacing: 1.05),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: const pw.BoxDecoration(color: primaryBlue),
                    child: pw.Text(
                      'Sello Digital del SAT:',
                      style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text(
                      invoice.timbre?.selloSAT ?? 'PENDIENTE',
                      style: const pw.TextStyle(fontSize: 4.8, color: textDark, lineSpacing: 1.05),
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(width: 10),

            // QR a la derecha
            pw.Container(
              width: 78,
              height: 78,
              child: invoice.timbre != null && invoice.timbre!.qrString.isNotEmpty
                  ? pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: invoice.timbre!.qrString,
                    )
                  : pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: 'https://verificacfdi.facturaelectronica.sat.gob.mx/default.aspx',
                    ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _boxRow(String label, String value, {bool isBig = false}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor, width: 0.6),
        color: lightGray,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 6.2, color: PdfColors.grey700)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isBig ? 10.5 : 6.8,
              fontWeight: pw.FontWeight.bold,
              color: isBig ? primaryBlue : textDark,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _cellHeader(String text, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _cellBody(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 6.8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textDark,
        ),
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value, {bool isTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isTotal ? 9.5 : 7.8,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isTotal ? primaryBlue : textDark,
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Container(
            width: 78,
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: isTotal ? 10.5 : 7.8,
                fontWeight: pw.FontWeight.bold,
                color: isTotal ? primaryBlue : textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
