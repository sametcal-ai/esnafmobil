import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/config/money_formatter.dart';
import '../../sales/data/sales_repository.dart';
import '../domain/product.dart';
import '../presentation/product_movements_page.dart' show ProductMovementForPdf;

class ProductStatementPdfService {
  final SalesRepository _salesRepository;

  ProductStatementPdfService({SalesRepository? salesRepository})
      : _salesRepository = salesRepository ?? SalesRepository();

  Future<pw.Font> _loadTtfFont(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();

    if (bytes.lengthInBytes < 1024) {
      throw Exception(
        'Font asset too small/invalid: $assetPath (${bytes.lengthInBytes} bytes)',
      );
    }

    return pw.Font.ttf(bytes.buffer.asByteData());
  }

  Future<Uint8List> generateStatementPdf({
    required Product product,
    required int openingStock,
    required int totalIncoming,
    required int totalOutgoing,
    required List<ProductMovementForPdf> entries,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final baseFont = await _loadTtfFont('assets/fonts/NotoSans-Regular.ttf');
      final boldFont = await _loadTtfFont('assets/fonts/NotoSans-Bold.ttf');

      final theme = pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
      );

      final doc = pw.Document(theme: theme);

      final endStock = openingStock + totalIncoming - totalOutgoing;

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return [
              _buildHeader(product),
              pw.SizedBox(height: 12),
              _buildDateRange(start, end),
              pw.SizedBox(height: 12),
              _buildSummary(
                openingStock: openingStock,
                totalIncoming: totalIncoming,
                totalOutgoing: totalOutgoing,
                endStock: endStock,
              ),
              pw.SizedBox(height: 16),
              _buildMovementsSection(entries),
            ];
          },
        ),
      );

      return doc.save();
    } catch (e, st) {
      debugPrint('PRODUCT PDF ERROR: $e');
      debugPrint('STACKTRACE: $st');
      rethrow;
    }
  }

  pw.Widget _buildHeader(Product product) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Ürün Ekstresi',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          product.name,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (product.barcode.isNotEmpty)
          pw.Text('Barkod: ${product.barcode}'),
        if (product.brand.isNotEmpty)
          pw.Text('Marka: ${product.brand}'),
      ],
    );
  }

  pw.Widget _buildDateRange(DateTime start, DateTime end) {
    return pw.Text(
      'Tarih Aralığı: ${_formatDate(start)} - ${_formatDate(end)}',
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  pw.Widget _buildSummary({
    required int openingStock,
    required int totalIncoming,
    required int totalOutgoing,
    required int endStock,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Dönem Özeti',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        _summaryRow('Açılış Stok', openingStock.toString()),
        _summaryRow('Toplam Giriş', totalIncoming.toString()),
        _summaryRow('Toplam Çıkış', totalOutgoing.toString()),
        pw.Divider(height: 8),
        _summaryRow('Dönem Sonu Stok', endStock.toString(), bold: true),
      ],
    );
  }

  pw.Widget _buildMovementsSection(List<ProductMovementForPdf> entries) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Hareketler',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        if (entries.isEmpty)
          pw.Text(
            'Seçilen aralıkta hareket yok',
            style: pw.TextStyle(fontSize: 12),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColors.grey400,
              width: 0.3,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(2), // Tarih
              1: const pw.FlexColumnWidth(2), // Tür
              2: const pw.FlexColumnWidth(2), // Miktar
              3: const pw.FlexColumnWidth(2), // Tutar
              4: const pw.FlexColumnWidth(3), // Açıklama
            },
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                children: [
                  _cellHeader('Tarih'),
                  _cellHeader('Tür'),
                  _cellHeader('Miktar'),
                  _cellHeader('Tutar'),
                  _cellHeader('Açıklama'),
                ],
              ),
              ...entries.map(
                (m) => pw.TableRow(
                  children: [
                    _cellText(_formatDate(m.occurredAt)),
                    _cellText(m.type),
                    _cellText(m.quantitySigned.toString()),
                    _cellText(
                      m.amount != null ? formatMoney(m.amount!) : '-',
                    ),
                    _cellText(m.subtitle),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _summaryRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 11,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(label, style: style),
          ),
          pw.SizedBox(width: 8),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  pw.Widget _cellHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _cellText(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          fontSize: 9,
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }
}
