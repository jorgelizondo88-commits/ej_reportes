import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trap_layout_model.dart';

class TrapLayoutService {
  static const String _layoutsKey = 'ej_client_trap_layouts_list';
  static const String _folioCounterKey = 'ej_layout_folio_counter';

  static final TrapLayoutService _instance = TrapLayoutService._internal();
  factory TrapLayoutService() => _instance;
  TrapLayoutService._internal();

  /// Obtiene todos los planos guardados ordenados del más reciente al más antiguo
  Future<List<TrapLayoutModel>> getAllLayouts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_layoutsKey) ?? [];
      final layouts = listJson
          .map((str) {
            try {
              return TrapLayoutModel.fromJson(str);
            } catch (e) {
              debugPrint('Error parseando layout individual: $e');
              return null;
            }
          })
          .whereType<TrapLayoutModel>()
          .toList();

      layouts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return layouts;
    } catch (e) {
      debugPrint('Error leyendo lista de layouts: $e');
      return [];
    }
  }

  /// Guarda o actualiza un plano en la base de datos local
  Future<bool> saveLayout(TrapLayoutModel layout) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = await getAllLayouts();

      final existingIndex = currentList.indexWhere((item) => item.id == layout.id);
      layout.updatedAt = DateTime.now();

      if (existingIndex >= 0) {
        currentList[existingIndex] = layout;
      } else {
        currentList.insert(0, layout);
      }

      final jsonList = currentList.map((item) => item.toJson()).toList();
      return await prefs.setStringList(_layoutsKey, jsonList);
    } catch (e) {
      debugPrint('Error guardando layout: $e');
      return false;
    }
  }

  /// Elimina un plano específico por su ID
  Future<bool> deleteLayout(String layoutId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = await getAllLayouts();
      currentList.removeWhere((item) => item.id == layoutId);

      final jsonList = currentList.map((item) => item.toJson()).toList();
      return await prefs.setStringList(_layoutsKey, jsonList);
    } catch (e) {
      debugPrint('Error eliminando layout: $e');
      return false;
    }
  }

  /// Genera el siguiente folio consecutivo para planos (#EJ-LAY-001, #EJ-LAY-002...)
  Future<String> generateNextFolio() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_layoutsKey);
      int maxNumber = 0;
      if (raw != null && raw.isNotEmpty) {
        try {
          final List<dynamic> list = jsonDecode(raw);
          for (final item in list) {
            final folioStr = (item['folio'] ?? '').toString();
            final match = RegExp(r'(\d+)$').firstMatch(folioStr);
            if (match != null) {
              final num = int.tryParse(match.group(1)!);
              if (num != null && num > maxNumber) {
                maxNumber = num;
              }
            }
          }
        } catch (_) {}
      }

      int currentCounter = prefs.getInt(_folioCounterKey) ?? 0;
      final nextCounter = (maxNumber > currentCounter ? maxNumber : currentCounter) + 1;
      await prefs.setInt(_folioCounterKey, nextCounter);
      return '#EJ-LAY-${nextCounter.toString().padLeft(3, '0')}';
    } catch (_) {
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      return '#EJ-LAY-${ts.substring(ts.length - 4)}';
    }
  }
}
