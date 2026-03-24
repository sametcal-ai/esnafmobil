String formatMoney(double value) {
  final safe = value.isFinite ? value : 0;
  final isNegative = safe < 0;
  final absValue = safe.abs();

  final fixed = absValue.toStringAsFixed(2);
  final parts = fixed.split('.');
  final integerPart = parts[0];
  final decimalPart = parts.length > 1 ? parts[1] : '00';

  final buf = StringBuffer();
  for (int i = 0; i < integerPart.length; i++) {
    final indexFromRight = integerPart.length - i;
    buf.write(integerPart[i]);
    if (indexFromRight > 1 && indexFromRight % 3 == 1) {
      buf.write('.');
    }
  }

  final formatted = '${buf.toString()},$decimalPart';
  final sign = isNegative ? '-' : '';
  return '$sign$formatted tl';
}