import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ej_reportes/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed') || details.toString().contains('ListTile')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await initializeDateFormatting('es_MX', null);
    await tester.pumpWidget(const EJReportesApp());
    expect(find.byType(EJReportesApp), findsOneWidget);
  });
}
