import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LauncherService {
  /// Abre WhatsApp con un mensaje predeterminado
  static Future<bool> openWhatsApp({
    required String phone,
    required String message,
  }) async {
    try {
      // Limpiar el teléfono de espacios, guiones y caracteres no numéricos
      String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

      // Formato para México si tiene 10 dígitos
      if (cleanPhone.length == 10) {
        cleanPhone = '52$cleanPhone';
      }

      final encodedMsg = Uri.encodeComponent(message);
      final url = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMsg');

      if (await canLaunchUrl(url)) {
        return await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error al abrir WhatsApp: $e');
    }
    return false;
  }

  /// Realiza llamada telefónica
  static Future<bool> makePhoneCall(String phone) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      final url = Uri.parse('tel:$cleanPhone');
      if (await canLaunchUrl(url)) {
        return await launchUrl(url);
      }
    } catch (e) {
      debugPrint('Error al llamar: $e');
    }
    return false;
  }

  /// Abre la dirección en Google Maps
  static Future<bool> openMap(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
      if (await canLaunchUrl(url)) {
        return await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error al abrir mapa: $e');
    }
    return false;
  }
}
