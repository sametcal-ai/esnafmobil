String normalizeBarcode(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '';

  final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) return '';

  // UPC-A (12) is commonly represented as EAN-13 by prefixing a leading 0.
  if (digitsOnly.length == 12) return '0$digitsOnly';

  return digitsOnly;
}
