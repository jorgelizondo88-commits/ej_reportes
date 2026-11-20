class SpanishNumberToWords {
  static const List<String> _unidades = [
    '',
    'UN',
    'DOS',
    'TRES',
    'CUATRO',
    'CINCO',
    'SEIS',
    'SIETE',
    'OCHO',
    'NUEVE',
    'DIEZ',
    'ONCE',
    'DOCE',
    'TRECE',
    'CATORCE',
    'QUINCE',
    'DIECISÉIS',
    'DIECISIETE',
    'DIECIOCHO',
    'DIECINUEVE',
    'VEINTE',
    'VEINTIÚN',
    'VEINTIDÓS',
    'VEINTITRÉS',
    'VEINTICUATRO',
    'VEINTICINCO',
    'VEINTISÉIS',
    'VEINTISIETE',
    'VEINTIOCHO',
    'VEINTINUEVE',
  ];

  static const List<String> _decenas = [
    '',
    'DIEZ',
    'VEINTE',
    'TREINTA',
    'CUARENTA',
    'CINCUENTA',
    'SESENTA',
    'SETENTA',
    'OCHENTA',
    'NOVENTA',
  ];

  static const List<String> _centenas = [
    '',
    'CIENTO',
    'DOSCIENTOS',
    'TRESCIENTOS',
    'CUATROCIENTOS',
    'QUINIENTOS',
    'SEISCIENTOS',
    'SETECIENTOS',
    'OCHOCIENTOS',
    'NOVECIENTOS',
  ];

  static String convert(double amount, {String currency = 'PESOS', String suffix = 'M.N.'}) {
    if (amount < 0) {
      return 'MENOS ${convert(-amount, currency: currency, suffix: suffix)}';
    }

    final int integerPart = amount.floor();
    final int cents = ((amount - integerPart) * 100).round();
    final String centsStr = cents.toString().padLeft(2, '0');

    String text;
    if (integerPart == 0) {
      text = 'CERO $currency';
    } else if (integerPart == 1) {
      text = 'UN ${currency == 'PESOS' ? 'PESO' : currency}';
    } else {
      text = '${_convertInteger(integerPart)} $currency';
    }

    return '$text $centsStr/100 $suffix'.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _convertInteger(int n) {
    if (n == 0) return '';
    if (n < 30) return _unidades[n];

    if (n < 100) {
      final d = n ~/ 10;
      final u = n % 10;
      if (u == 0) return _decenas[d];
      return '${_decenas[d]} Y ${_unidades[u]}';
    }

    if (n < 1000) {
      if (n == 100) return 'CIEN';
      final c = n ~/ 100;
      final resto = n % 100;
      if (resto == 0) return _centenas[c];
      return '${_centenas[c]} ${_convertInteger(resto)}';
    }

    if (n < 1000000) {
      final miles = n ~/ 1000;
      final resto = n % 1000;
      String milesText;
      if (miles == 1) {
        milesText = 'MIL';
      } else {
        milesText = '${_convertInteger(miles)} MIL';
      }
      if (resto == 0) return milesText;
      return '$milesText ${_convertInteger(resto)}';
    }

    if (n < 1000000000000) {
      final millones = n ~/ 1000000;
      final resto = n % 1000000;
      String millonesText;
      if (millones == 1) {
        millonesText = 'UN MILLÓN';
      } else {
        millonesText = '${_convertInteger(millones)} MILLONES';
      }
      if (resto == 0) return millonesText;
      return '$millonesText ${_convertInteger(resto)}';
    }

    return n.toString();
  }
}
