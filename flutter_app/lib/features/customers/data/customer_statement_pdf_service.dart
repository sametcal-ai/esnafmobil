import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/config/money_formatter.dart';
import '../../sales/data/sales_repository.dart';
import '../domain/customer.dart';
import '../domain/customer_ledger.dart';

class CustomerStatementPdfService {
  final SalesRepository _salesRepository;

  CustomerStatementPdfService({
    SalesRepository? salesRepository,
  }) : _salesRepository = salesRepository ?? SalesRepository();

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

  /// Müşteri ekstresi PDF içeriğini üretir.
  ///
  /// [customer]: Müşteri bilgileri.
  /// [previousBalance]: Seçilen tarih aralığından önceki bakiye.
  /// [entries]: Seçilen tarih aralığındaki hareketler (yeni -> eski sıralı).
  /// [start]: Tarih aralığı başlangıcı.
  /// [end]: Tarih aralığı bitişi.
  Future<Uint8List> generateStatementPdf({
    required String companyId,
    required Customer customer,
    required double previousBalance,
    required List<CustomerLedgerEntry> entries,
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

      final doc = pw.Document(
        theme: theme,
      );

      // Ekstredeki satış hareketlerine ait saleId'leri topla.
      final safeEntries = entries;
      final saleIds = safeEntries
          .where((e) => e.type == LedgerEntryType.sale && e.saleId != null)
          .map((e) => e.saleId!)
          .toList(growable: false);

      // Satış kayıtlarını tek seferde (veya en azından tek merkezden) yükle.
      // saleIds boşsa gereksiz repository çağrısı yapma.
      final salesById = saleIds.isEmpty
          ? <String, Sale>{}
          : await _salesRepository.getSalesByIds(companyId, saleIds);

      // Dönem özeti hesapları (NaN oluşmasını engellemek için güvenli toplama).
      double periodSalesTotal = 0;
      double periodPaymentsTotal = 0;

      for (final e in safeEntries) {
        final amount = e.amount.isFinite ? e.amount : 0;
        if (e.type == LedgerEntryType.sale) {
          periodSalesTotal += amount;
        } else {
          periodPaymentsTotal += amount;
        }
      }

      final safePreviousBalance =
          previousBalance.isFinite ? previousBalance : 0.0;
      final endBalance =
          safePreviousBalance + periodSalesTotal - periodPaymentsTotal;

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return [
              _buildHeader(customer),
              pw.SizedBox(height: 12),
              _buildDateRange(start, end),
              pw.SizedBox(height: 12),
              _buildPreviousBalance(safePreviousBalance),
              pw.SizedBox(height: 16),
              _buildMovementsSection(safeEntries, salesById),
              pw.SizedBox(height: 16),
              _buildPeriodSummary(
                periodSalesTotal: periodSalesTotal,
                periodPaymentsTotal: periodPaymentsTotal,
                previousBalance: safePreviousBalance,
                endBalance: endBalance,
              ),
            ];
          },
        ),
      );

      return doc.save();
    } catch (e, st) {
      debugPrint('PDF ERROR: $e');
      debugPrint('STACKTRACE: $st');
      rethrow;
    }
  }

  pw.Widget _buildHeader(Customer customer) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Müşteri Ekstresi',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          customer.name,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (customer.code != null && customer.code!.trim().isNotEmpty)
          pw.Text('Müşteri Kodu: ${customer.code}'),
        if (customer.phone != null && customer.phone!.trim().isNotEmpty)
          pw.Text('Telefon: ${customer.phone}'),
        if (customer.email != null && customer.email!.trim().isNotEmpty)
          pw.Text('E-posta: ${customer.email}'),
        if (customer.workplace != null &&
            customer.workplace!.trim().isNotEmpty)
          pw.Text('İşyeri: ${customer.workplace}'),
        if (customer.note != null && customer.note!.trim().isNotEmpty)
          pw.Text('Not: ${customer.note}'),
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
          style: pw.TextStyle(
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildMovementsSection(
    List<CustomerLedgerEntry> entries,
    Map<String, Sale> salesById,
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
            style: pw.TextStyle(fontSize: 12),
          )
        else
          ...entries.map(
            (entry) {
              if (entry.type == LedgerEntryType.sale) {
                return _buildSaleEntry(entry, salesById);
              } else {
                return _buildPaymentEntry(entry);
              }
            },
          ),
      ],
    );
  }

  pw.Widget _buildSaleEntry(
    CustomerLedgerEntry entry,
    Map<String, Sale> salesById,
  ) {
    final saleId = entry.saleId;
    final sale = saleId == null ? null : salesById[saleId];

    final widgets = <pw.Widget>[
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'Satış - ${_formatDate(entry.createdAt)}',
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
                formatMoney(entry.amount),
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

    if (sale != null) {
      widgets.add(
        pw.Text(
          'Fiş No: ${sale.id}',
          style: pw.TextStyle(fontSize: 10),
        ),
      );
    }

    if (sale == null || sale.items.isEmpty) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, top: 2, bottom: 6),
          child: pw.Text(
            'Ürün kalemi mevcut değil (eski kayıt)',
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
          child: _buildSaleItemsTable(sale),
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

  pw.Widget _buildSaleItemsTable(Sale sale) {
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
                _cellHeader('Birim Fiyat'),
                _cellHeader('Tutar'),
              ],
            ),
            ...sale.items.map(
              (item) => pw.TableRow(
                children: [
                  _cellText(item.productName),
                  _cellText(item.quantity.toString()),
                  _cellText(formatMoney(item.unitPrice)),
                  _cellText(formatMoney(item.lineTotal)),
                ],
              ),
            ),
          ],
        ),
      ],
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

  pw.Widget _buildPaymentEntry(CustomerLedgerEntry entry) {
    final children = <pw.Widget>[
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              'Tahsilat - ${_formatDate(entry.createdAt)}',
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
                // Tahsilatlar bakiyeyi azalttığı için - işareti ile gösterilebilir.
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
            style: const pw.TextStyle(
              fontSize: 10,
            ),
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
    required double periodSalesTotal,
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
        _summaryRow('Dönem Satış Toplamı', formatMoney(periodSalesTotal)),
        _summaryRow(
          'Dönem Tahsilat Toplamı',
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

  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }
}