import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/auditable.dart';
import '../../products/data/product_repository.dart';
import '../domain/stock_entry.dart';
import 'supplier_repository.dart';
import 'supplier_ledger_repository.dart';

class StockEntryRepository {
  static const String stockEntriesBoxName = 'stock_entries';
  static const _uuid = Uuid();

  Box get _stockBox => Hive.box(stockEntriesBoxName);

  final ProductRepository _productRepository;

  StockEntryRepository(this._productRepository);

  Future<StockEntry> createStockEntry({
    required String supplierId,
    required String productId,
    required int quantity,
    required double unitCost,
    double? marginPercent,
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final actor = currentUserId ?? 'system';
    final meta = AuditMeta.create(
      createdBy: actor,
      now: now,
    );
    final entry = StockEntry(
      id: id,
      supplierId: supplierId,
      productId: productId,
      quantity: quantity,
      unitCost: unitCost,
      createdAt: now,
      type: StockMovementType.incoming,
      meta: meta,
    );
    await _stockBox.put(id, entry.toMap());

    await _productRepository.increaseStock(
      productId: productId,
      quantity: quantity,
      purchasePrice: unitCost,
      marginPercent: marginPercent,
    );

    // Tedarikçi ekstresi için alış hareketi oluştur
    if (supplierId.isNotEmpty) {
      final supplierRepo = SupplierRepository();
      final supplier = await supplierRepo.getSupplierById(supplierId);
      if (supplier != null) {
        final ledgerRepo = SupplierLedgerRepository(supplierRepo);
        final totalAmount = quantity * unitCost;
        await ledgerRepo.addPurchaseEntry(
          supplier: supplier,
          amount: totalAmount,
          note: 'Stok girişi',
        );
      }
    }

    return entry;
  }

  Future<StockEntry> createSaleEntry({
    required String productId,
    required int quantity,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final meta = AuditMeta.create(
      createdBy: 'system',
      now: now,
    );
    final entry = StockEntry(
      id: id,
      supplierId: null,
      productId: productId,
      quantity: quantity,
      unitCost: 0,
      createdAt: now,
      type: StockMovementType.outgoing,
      meta: meta,
    );
    await _stockBox.put(id, entry.toMap());
    return entry;
  }

  Future<List<StockEntry>> getAllEntries() async {
    final entries = _stockBox.values
        .whereType<Map>()
        .where(isActiveRecordMap)
        .map((map) => StockEntry.fromMap(map))
        .toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }
}