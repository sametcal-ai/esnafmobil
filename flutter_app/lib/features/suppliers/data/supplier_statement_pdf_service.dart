import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/config/money_formatter.dart';
import '../../products/data/product_repository.dart';
import '../data/stock_entry_repository.dart';
import '../domain/stock_entry.dart';
import '../domain/supplier.dart';
import '../domain/supplier_ledger.dart';

class SupplierStatementPdfService {
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
    required String companyId,
    required Supplier supplier,
    required double previousBalance,
    required List<SupplierLedgerEntry> entries,
    required DateTime start,
    required DateTime end,
  }) async {
    final baseFont = await _loadTtfFont('assets/fonts/NotoSans-Regular.ttf');
    final boldFont = await _loadTtfFont('assets/fonts/NotoSans-Bold.ttf');

    final theme = pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
    );

    final doc = pw.Document(theme: theme);

    // Satın alma hareketlerine ait stok kayıtlarını ve ürünleri yükle.
    final stockRepo = StockEntryRepository(ProductRepository());
    final productRepo = ProductRepository();

    final stockEntries = await stockRepo.getAllEntries(companyId);
    final supplierStocks = stockEntries.where(
      (e) =>
          e.type == StockMovementType.incoming &&
          e.supplierId == supplier.id,
    );

    final products = await productRepo.getAllProducts(companyId);
    final productsById = {
      for (final p in products) p.id: p,
    };

    final purchaseDetailsByLedgerId = <String, _SupplierPurchasePdfData>{};
    final usedStockIds = <String>{};

    for (final entry in entries
        .where((e) => e.type == SupplierLedgerEntryType.purchase)) {
      final match = _findMatchingStockEntryForLedger(
        entry,
        supplierStocks,
        usedStockIds,
      );
      if (match == null) continue;
      usedStockIds.add(match.id);

      final product = productsById[match.productId];
      purchaseDetailsByLedgerId[entry.id] = _SupplierPurchasePdfData(
        productName: product?.name ?? 'Ürün: ${match.productId}',
        quantity: match.quantity,
        unitCost: match.unitCost,
      );
    }

    double periodPurchasesTotal = 0;
    double periodPaymentsTotal = 0;

    for (final e in entries) {
      final amount = e.amount.isFinite ? e.amount : 0;
      if (e.type == SupplierLedgerEntryType.purchase) {
        periodPurchasesTotal += amount;
      } else {
        periodPaymentsTotal += amount;
      }
    }

    final safePreviousBalance =
        previousBalance.isFinite ? previousBalance : 0.0;
    final endBalance =
        safePreviousBalance + periodPurchasesTotal - periodPaymentsTotal;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            _buildHeader(supplier),
            pw.SizedBox(height: 12),
            _buildDateRange(start, end),
            pw.SizedBox(height: 12),
            _buildPreviousBalance(safePreviousBalance),
            pw.SizedBox(height: 16),
            _buildMovementsSection(entries, purchaseDetailsByLedgerId),
            pw.SizedBox(height: 16),
            _buildPeriodSummary(
              periodPurchasesTotal: periodPurchasesTotal,
              periodPaymentsTotal: periodPaymentsTotal,
              previousBalance: safePreviousBalance,
              endBalance: endBalance,
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _buildHeader(Supplier supplier) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Tedarikçi Ekstresi',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          supplier.name,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (supplier.phone != null && supplier.phone!.trim().isNotEmpty)
          pw.Text('Telefon: ${supplier.phone}'),
        if (supplier.address != null && supplier.address!.trim().isNotEmpty)
          pw.Text('Adres: ${supplier.address}'),
        if (supplier.note != null && supplier.note!.trim().isNotEmpty)
          pw.Text('Not: ${supplier.note}'),
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

  pw.Widget _buildPreviousBalance(double previousBalance) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Önceki Bakiye',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          formatMoney(previousBalance),
          style: const pw.TextStyle(
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildMovementsSection(
    List<SupplierLedgerEntry> entries,
    Map<String, _SupplierPurchasePdfData> purchaseDetailsByLedgerId,
  ) {
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
            style: const pw.TextStyle(fontSize: 12),
          )
        else
          ...entries.map((entry) {
            if (entry.type == SupplierLedgerEntryType.purchase) {
              final detail = purchaseDetailsByLedgerId[entry.id];
              return _buildPurchaseEntry(entry, detail);
            } else {
              return _buildPaymentEntry(entry);
            }
          }),
      ],
    );
  }

  pw.Widget _buildPurchaseEntry(
    SupplierLedgerEntry entry,
    _SupplierPurchasePdfData? detail,
  ) {
    final widgets = <pw.Widget>[
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'Alış - ${_formatDate(entry.createdAt)}',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            flex: 2,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '+ ${formatMoney(entry.amount)}',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    ];

    if (entry.note != null && entry.note!.trim().isNotEmpty) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, top: 2, bottom: 4),
          child: pw.Text(
            'Not: ${entry.note}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      );
    }

    if (detail == null) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, top: 2, bottom: 6),
          child: pw.Text(
            'Bu alış için stok girişi detayı bulunamadı.',
            style: pw.TextStyle(
              fontSize: 10,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
      );
    } else {
      widgets.add(
        pw.SizedBox(height: 2),
      );
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, bottom: 6),
          child: _buildPurchaseItemsTable(detail),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        ...widgets,
        pw.Divider(height: 8),
      ],
    );
  }

  pw.Widget _buildPurchaseItemsTable(_SupplierPurchasePdfData detail) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Ürünler',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Table(
          border: pw.TableBorder.all(
            color: PdfColors.grey400,
            width: 0.3,
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(1.3),
          },
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              children: [
                _cellHeader('Ürün'),
                _cellHeader('Adet'),
                _cellHeader('Birim Alış'),
                _cellHeader('Tutar'),
              ],
            ),
            pw.TableRow(
              children: [
                _cellText(detail.productName),
                _cellText(detail.quantity.toString()),
                _cellText(formatMoney(detail.unitCost)),
                _cellText(formatMoney(detail.lineTotal)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _cellHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
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
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          fontSize: 9,
        ),
      ),
    );
  }

  pw.Widget _buildPaymentEntry(SupplierLedgerEntry entry) {
    final children = <pw.Widget>[
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'Ödeme - ${_formatDate(entry.createdAt)}',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            flex: 2,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '- ${formatMoney(entry.amount)}',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    ];

    if (entry.note != null && entry.note!.trim().isNotEmpty) {
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, top: 2, bottom: 6),
          child: pw.Text(
            'Not: ${entry.note}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      );
    } else {
      children.add(
        pw.SizedBox(height: 6),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        ...children,
        pw.Divider(height: 8),
      ],
    );
  }

  pw.Widget _buildPeriodSummary({
    required double periodPurchasesTotal,
    required double periodPaymentsTotal,
    required double previousBalance,
    required double endBalance,
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
        _summaryRow('Dönem Alış Toplamı', formatMoney(periodPurchasesTotal)),
        _summaryRow(
          'Dönem Ödeme Toplamı',
          '- ${formatMoney(periodPaymentsTotal)}',
        ),
        _summaryRow('Önceki Bakiye', formatMoney(previousBalance)),
        pw.Divider(height: 8),
        _summaryRow(
          'Dönem Sonu Bakiye',
          formatMoney(endBalance),
          bold: true,
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

  StockEntry? _findMatchingStockEntryForLedger(
    SupplierLedgerEntry ledgerEntry,
    Iterable<StockEntry> stockEntries,
    Set<String> usedStockIds,
  ) {
    StockEntry? bestMatch;
    int? bestDiff;

    for (final entry in stockEntries) {
      if (usedStockIds.contains(entry.id)) continue;

      final amount = entry.quantity * entry.unitCost;
      if ((amount - ledgerEntry.amount).abs() > 0.01) continue;

      final diff = (entry.createdAt.millisecondsSinceEpoch -
              ledgerEntry.createdAt.millisecondsSinceEpoch)
          .abs();
      if (diff > const Duration(minutes: 1).inMilliseconds) continue;

      if (bestMatch == null || diff < bestDiff!) {
        bestMatch = entry;
        bestDiff = diff;
      }
    }

    return bestMatch;
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

class _SupplierPurchasePdfData {
  final String productName;
  final int quantity;
  final double unitCost;

  double get lineTotal => quantity * unitCost;

  _SupplierPurchasePdfData({
    required this.productName,
    required this.quantity,
    required this.unitCost,
  });
}
