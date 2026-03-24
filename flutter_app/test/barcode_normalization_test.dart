import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/scanner/barcode_normalizer.dart';

void main() {
  test('normalizeBarcode pads UPC-A to EAN-13', () {
    expect(normalizeBarcode('123456789012'), '0123456789012');
  });

  test('normalizeBarcode strips non-digits', () {
    expect(normalizeBarcode('  86 926-4100\n3001 '), '8692641003001');
  });
}
