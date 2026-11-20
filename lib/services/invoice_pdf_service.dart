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
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 22),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          italic: pw.Font.helveticaOblique(),
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- 1. CABECERA: LOGO + EMISOR + FOLIO ---
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Logo EJ
                  if (logoImage != null)
                    pw.Container(
                      width: 85,
                      height: 85,
                      margin: const pw.EdgeInsets.only(right: 12),
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),

                  // Datos del Emisor
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

                  // Caja lateral de Folio y Tipo
                  pw.Container(
                    width: 175,
                    child: pw.Column(
                      children: [
                        // Tipo de Comprobante
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

                        // Factura No.
                        _boxRow('Factura No.', invoice.fullFolio, isBig: true),
                        _boxRow('Lugar y Fecha de Expedición', 'C.P.${invoice.expeditionZip} ${dateFmt.format(invoice.emissionDate)}'),
                        _boxRow('Fecha y Hora de Emisión', dateIsoFmt.format(invoice.emissionDate)),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              // --- 2. DATOS DEL CLIENTE / RECEPTOR ---
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

              pw.SizedBox(height: 6),

              // --- 3. METADATOS DEL TIMBRE / CSD ---
              pw.Table(
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
              ),

              pw.SizedBox(height: 6),

              // --- 4. TABLA DE CONCEPTOS ---
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.6),
                columnWidths: const {
                  0: pw.FixedColumnWidth(48),
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
              ),

              pw.SizedBox(height: 6),

              // --- 5. INFORMACIÓN DEL COMPROBANTE Y TOTALES ---
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
                      flex: 6,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Text('Forma de Pago: ', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: textDark)),
                              pw.Text(invoice.paymentForm, style: const pw.TextStyle(fontSize: 7.2, color: textDark)),
                              pw.SizedBox(width: 12),
                              pw.Text('Método de Pago: ', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: textDark)),
                              pw.Text(invoice.paymentMethod, style: const pw.TextStyle(fontSize: 7.2, color: textDark)),
                            ],
                          ),
                          pw.SizedBox(height: 3),
                          pw.Row(
                            children: [
                              pw.Text('Condiciones de pago: ', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: textDark)),
                              pw.Text(
                                'Institución Bancaria del Emisor: ${invoice.bankInstitution}     No. de Cuenta: ${invoice.bankAccount}',
                                style: const pw.TextStyle(fontSize: 7.0, color: textDark),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 3),
                          pw.Row(
                            children: [
                              pw.Text('Moneda: ', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: textDark)),
                              pw.Text(invoice.currency, style: const pw.TextStyle(fontSize: 7.0, color: textDark)),
                              pw.SizedBox(width: 14),
                              pw.Text('Tipo de cambio: ', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: textDark)),
                              pw.Text('\$ ${invoice.exchangeRate.toStringAsFixed(4)}', style: const pw.TextStyle(fontSize: 7.0, color: textDark)),
                            ],
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text('Exportación: ${invoice.exportation}', style: const pw.TextStyle(fontSize: 7.0, color: textDark)),
                          pw.SizedBox(height: 4),
                          pw.Text('Importe con letra:', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: textDark)),
                          pw.Text(
                            invoice.totalInWords,
                            style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: primaryBlue),
                          ),
                          if (invoice.observations.isNotEmpty) ...[
                            pw.SizedBox(height: 3),
                            pw.Text('Observaciones: ${invoice.observations}', style: const pw.TextStyle(fontSize: 6.8, color: textDark)),
                          ],
                        ],
                      ),
                    ),

                    // Columna Derecha: Subtotal, IVA y TOTAL
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        children: [
                          _totalRow('Subtotal', currencyFmt.format(invoice.subtotal)),
                          _totalRow('I.V.A. 16%', currencyFmt.format(invoice.ivaAmount)),
                          pw.Divider(color: borderColor, height: 6, thickness: 0.6),
                          _totalRow('TOTAL', currencyFmt.format(invoice.total), isTotal: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // --- 6. PIE FISCAL: SELLOS, CADENA ORIGINAL Y QR ---
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

                  pw.SizedBox(width: 8),

                  // QR a la derecha
                  pw.Column(
                    children: [
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
                      pw.SizedBox(height: 2),
                      pw.Text('Página 1 de 1', style: const pw.TextStyle(fontSize: 6.5, color: textDark)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 4),
              pw.Divider(color: borderColor, height: 4, thickness: 0.6),

              // --- 7. LEYENDA LEGAL INFERIOR ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('RFC del Proveedor de Certificación: ${invoice.timbre?.rfcProvCertif ?? 'FFM100507289'}', style: const pw.TextStyle(fontSize: 5.8, color: textDark)),
                  pw.Text('ESTE DOCUMENTO ES UNA REPRESENTACIÓN IMPRESA DE UN CFDI.', style: pw.TextStyle(fontSize: 5.8, fontWeight: pw.FontWeight.bold, color: textDark)),
                  pw.Text('Versión del CFDI: 4.0', style: pw.TextStyle(fontSize: 5.8, fontWeight: pw.FontWeight.bold, color: textDark)),
                ],
              ),
              pw.SizedBox(height: 1),
              pw.Center(
                child: pw.Text(
                  'CFDI Certificado por Factura Fácilmente de México, S.A. de C.V. y generado desde EJ Exterminadores       Proveedor Autorizado de Certificación No. 57553',
                  style: const pw.TextStyle(fontSize: 5.4, color: PdfColors.grey700),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
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
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isTotal ? 9.5 : 7.8,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isTotal ? primaryBlue : textDark,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isTotal ? 10.5 : 7.8,
              fontWeight: pw.FontWeight.bold,
              color: isTotal ? primaryBlue : textDark,
            ),
          ),
        ],
      ),
    );
  }
}
