import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/cfdi_invoice_data.dart';
import '../models/client_model.dart';
import 'google_drive_sync_service.dart';
import 'invoice_pdf_service.dart';
import 'invoice_storage_service.dart';

class StampedInvoiceResult {
  final CfdiInvoiceData invoice;
  final Uint8List pdfBytes;
  final String xmlString;
  final File localPdfFile;
  final File localXmlFile;
  final bool driveUploaded;
  final String? drivePdfFileId;
  final String? driveXmlFileId;

  StampedInvoiceResult({
    required this.invoice,
    required this.pdfBytes,
    required this.xmlString,
    required this.localPdfFile,
    required this.localXmlFile,
    required this.driveUploaded,
    this.drivePdfFileId,
    this.driveXmlFileId,
  });
}

class CfdiStampingService {
  /// Genera un UUID estándar v4 para pruebas del SAT
  static String _generateUuid() {
    final rnd = Random();
    String hex(int len) {
      const chars = '0123456789ABCDEF';
      return List.generate(len, (_) => chars[rnd.nextInt(16)]).join();
    }
    return '${hex(8)}-${hex(4)}-4${hex(3)}-A${hex(3)}-${hex(12)}';
  }

  /// Genera una cadena aleatoria base64 realista para sellos del SAT
  static String _generateSelloBase64(int length) {
    final rnd = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+/';
    final s = List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
    return '$s==';
  }

  /// Construye el archivo XML oficial CFDI 4.0
  static String buildCfdiXml(CfdiInvoiceData invoice, CfdiTimbreDigital timbre) {
    final dateFmt = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
    final emissionStr = dateFmt.format(invoice.emissionDate);
    final certifStr = dateFmt.format(timbre.fechaCertificacion);

    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln('<cfdi:Comprobante xmlns:cfdi="http://www.sat.gob.mx/cfd/4" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.sat.gob.mx/cfd/4 http://www.sat.gob.mx/sitio_internet/cfd/4/cfdv40.xsd http://www.sat.gob.mx/TimbreFiscalDigital http://www.sat.gob.mx/sitio_internet/cfd/TimbreFiscalDigital/TimbreFiscalDigitalv11.xsd" xmlns:tfd="http://www.sat.gob.mx/TimbreFiscalDigital" Version="4.0" Serie="${invoice.series}" Folio="${invoice.folio}" Fecha="$emissionStr" Sello="${timbre.selloEmisor}" FormaPago="${invoice.paymentForm.split(' - ').first}" NoCertificado="${timbre.noCertificadoEmisor}" SubTotal="${invoice.subtotal.toStringAsFixed(2)}" Moneda="${invoice.currency}" TipoCambio="${invoice.exchangeRate.toStringAsFixed(4)}" Total="${invoice.total.toStringAsFixed(2)}" TipoDeComprobante="I" Exportacion="01" MetodoPago="${invoice.paymentMethod.split(' - ').first}" LugarExpedicion="${invoice.expeditionZip}">');

    // Emisor
    sb.writeln('  <cfdi:Emisor Rfc="${invoice.issuerRfc}" Nombre="${invoice.issuerName}" RegimenFiscal="${invoice.issuerRegime.split(' - ').first}"/>');

    // Receptor
    sb.writeln('  <cfdi:Receptor Rfc="${invoice.receiverRfc}" Nombre="${invoice.receiverBusinessName}" DomicilioFiscalReceptor="${invoice.receiverZip}" RegimenFiscalReceptor="${invoice.receiverRegime.split(' - ').first}" UsoCFDI="${invoice.receiverCfdiUse.split(' - ').first}"/>');

    // Conceptos
    sb.writeln('  <cfdi:Conceptos>');
    for (final it in invoice.items) {
      final qtyStr = it.quantity % 1 == 0 ? it.quantity.toInt().toString() : it.quantity.toString();
      sb.writeln('    <cfdi:Concepto ClaveProdServ="${it.satProductCode}" Cantidad="$qtyStr" ClaveUnidad="${it.satUnitCode}" Unidad="${it.satUnitDesc}" Descripcion="${it.description}" ValorUnitario="${it.unitPrice.toStringAsFixed(2)}" Importe="${it.subtotal.toStringAsFixed(2)}" ObjetoImp="${it.taxObject.split(' - ').first}">');
      if (it.taxObject.startsWith('02')) {
        sb.writeln('      <cfdi:Impuestos>');
        sb.writeln('        <cfdi:Traslados>');
        sb.writeln('          <cfdi:Traslado Base="${it.subtotal.toStringAsFixed(2)}" Impuesto="002" TipoFactor="Tasa" TasaOCuota="0.160000" Importe="${it.taxAmount.toStringAsFixed(2)}"/>');
        sb.writeln('        </cfdi:Traslados>');
        sb.writeln('      </cfdi:Impuestos>');
      }
      sb.writeln('    </cfdi:Concepto>');
    }
    sb.writeln('  </cfdi:Conceptos>');

    // Impuestos totales
    sb.writeln('  <cfdi:Impuestos TotalImpuestosTrasladados="${invoice.ivaAmount.toStringAsFixed(2)}">');
    sb.writeln('    <cfdi:Traslados>');
    sb.writeln('      <cfdi:Traslado Base="${invoice.subtotal.toStringAsFixed(2)}" Impuesto="002" TipoFactor="Tasa" TasaOCuota="0.160000" Importe="${invoice.ivaAmount.toStringAsFixed(2)}"/>');
    sb.writeln('    </cfdi:Traslados>');
    sb.writeln('  </cfdi:Impuestos>');

    // Complemento: Timbre Fiscal Digital
    sb.writeln('  <cfdi:Complemento>');
    sb.writeln('    <tfd:TimbreFiscalDigital Version="1.1" UUID="${timbre.uuid}" FechaTimbrado="$certifStr" RfcProvCertif="${timbre.rfcProvCertif}" SelloCFD="${timbre.selloEmisor}" NoCertificadoSAT="${timbre.noCertificadoSAT}" SelloSAT="${timbre.selloSAT}"/>');
    sb.writeln('  </cfdi:Complemento>');

    sb.writeln('</cfdi:Comprobante>');
    return sb.toString();
  }

  /// Timbra la factura (Modo Sandbox / Pruebas) y la archiva en Google Drive
  static Future<StampedInvoiceResult> stampAndSaveInvoice({
    required CfdiInvoiceData invoiceData,
    required ClientModel client,
    bool isSandbox = true,
  }) async {
    final now = DateTime.now();

    // 1. Generar metadatos fiscales del timbre
    final uuid = _generateUuid();
    final noCertificadoEmisor = '00001000000518855488';
    final noCertificadoSAT = '00001000000707568881';
    final selloEmisor = _generateSelloBase64(172);
    final selloSAT = _generateSelloBase64(172);
    final rfcProvCertif = 'FFM100507289';

    final cadenaOriginal = '||1.1|$uuid|${DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(now)}|$rfcProvCertif|$selloEmisor|$noCertificadoSAT||';
    final qrString = 'https://verificacfdi.facturaelectronica.sat.gob.mx/default.aspx?id=$uuid&re=${invoiceData.issuerRfc}&rr=${invoiceData.receiverRfc}&tt=${invoiceData.total.toStringAsFixed(2)}&fe=${selloEmisor.substring(selloEmisor.length - 8)}';

    final timbre = CfdiTimbreDigital(
      uuid: uuid,
      noCertificadoEmisor: noCertificadoEmisor,
      noCertificadoSAT: noCertificadoSAT,
      fechaCertificacion: now,
      cadenaOriginal: cadenaOriginal,
      selloEmisor: selloEmisor,
      selloSAT: selloSAT,
      rfcProvCertif: rfcProvCertif,
      qrString: qrString,
    );

    // Factura con timbre completo
    final stampedInvoice = CfdiInvoiceData(
      series: invoiceData.series,
      folio: invoiceData.folio,
      emissionDate: invoiceData.emissionDate,
      expeditionZip: invoiceData.expeditionZip,
      voucherType: invoiceData.voucherType,
      issuerName: invoiceData.issuerName,
      issuerCommercial: invoiceData.issuerCommercial,
      issuerRfc: invoiceData.issuerRfc,
      issuerStreet: invoiceData.issuerStreet,
      issuerColony: invoiceData.issuerColony,
      issuerZip: invoiceData.issuerZip,
      issuerCity: invoiceData.issuerCity,
      issuerState: invoiceData.issuerState,
      issuerPhone: invoiceData.issuerPhone,
      issuerEmail: invoiceData.issuerEmail,
      issuerRegime: invoiceData.issuerRegime,
      receiverBusinessName: invoiceData.receiverBusinessName,
      receiverCommercialName: invoiceData.receiverCommercialName,
      receiverRfc: invoiceData.receiverRfc,
      receiverAddress: invoiceData.receiverAddress,
      receiverZip: invoiceData.receiverZip,
      receiverCfdiUse: invoiceData.receiverCfdiUse,
      receiverRegime: invoiceData.receiverRegime,
      items: invoiceData.items,
      paymentForm: invoiceData.paymentForm,
      paymentMethod: invoiceData.paymentMethod,
      bankInstitution: invoiceData.bankInstitution,
      bankAccount: invoiceData.bankAccount,
      currency: invoiceData.currency,
      exchangeRate: invoiceData.exchangeRate,
      exportation: invoiceData.exportation,
      observations: invoiceData.observations,
      timbre: timbre,
    );

    // 2. Generar PDF idéntico y archivo XML
    final pdfBytes = await InvoicePdfService.generateInvoicePdf(stampedInvoice);
    final xmlString = buildCfdiXml(stampedInvoice, timbre);

    // 3. Guardar en disco local
    final appDir = await getApplicationDocumentsDirectory();
    final invoicesLocalDir = Directory('${appDir.path}/facturas_emitidas');
    if (!await invoicesLocalDir.exists()) {
      await invoicesLocalDir.create(recursive: true);
    }

    final fileBaseName = 'Factura_${stampedInvoice.fullFolio}';
    final localPdfFile = File('${invoicesLocalDir.path}/$fileBaseName.pdf');
    final localXmlFile = File('${invoicesLocalDir.path}/$fileBaseName.xml');

    await localPdfFile.writeAsBytes(pdfBytes);
    await localXmlFile.writeAsString(xmlString, encoding: utf8);

    // 4. Subir a Google Drive en la carpeta 5_Facturas/Pendientes_de_Pago del cliente
    bool driveOk = false;
    String? drivePdfId;
    String? driveXmlId;

    try {
      final driveSync = GoogleDriveSyncService();
      if (driveSync.isSignedIn) {
        final clientFolderTarget = client.businessName.isNotEmpty ? client.businessName : client.contactName;

        // Subir PDF a Pendientes_de_Pago
        drivePdfId = await driveSync.uploadInvoiceFile(
          clientName: clientFolderTarget,
          localFile: localPdfFile,
          targetFileName: '$fileBaseName.pdf',
          status: 'Pendientes_de_Pago',
        );

        // Subir XML a Pendientes_de_Pago
        driveXmlId = await driveSync.uploadInvoiceFile(
          clientName: clientFolderTarget,
          localFile: localXmlFile,
          targetFileName: '$fileBaseName.xml',
          status: 'Pendientes_de_Pago',
        );

        driveOk = (drivePdfId != null && drivePdfId.isNotEmpty);
      }
    } catch (_) {}

    // 5. Guardar en historial de conceptos y plantilla del cliente
    for (final it in stampedInvoice.items) {
      await InvoiceStorageService.saveRecentConcept(it);
    }
    await InvoiceStorageService.saveClientLastInvoice(client.id, stampedInvoice);

    final intFolio = int.tryParse(stampedInvoice.folio);
    if (intFolio != null) {
      await InvoiceStorageService.updateLastFolioNumber(intFolio);
    }

    return StampedInvoiceResult(
      invoice: stampedInvoice,
      pdfBytes: pdfBytes,
      xmlString: xmlString,
      localPdfFile: localPdfFile,
      localXmlFile: localXmlFile,
      driveUploaded: driveOk,
      drivePdfFileId: drivePdfId,
      driveXmlFileId: driveXmlId,
    );
  }
}
