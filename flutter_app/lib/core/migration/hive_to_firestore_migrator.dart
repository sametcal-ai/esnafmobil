import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../firestore/firestore_refs.dart';

@immutable
class MigrationProgress {
  final String phase;
  final int migrated;
  final int total;

  const MigrationProgress({
    required this.phase,
    required this.migrated,
    required this.total,
  });

  double get ratio => total == 0 ? 1.0 : (migrated / total).clamp(0.0, 1.0);
}

@immutable
class MigrationReport {
  final int migrated;
  final int skipped;

  const MigrationReport({
    required this.migrated,
    required this.skipped,
  });
}

typedef MigrationProgressCallback = void Function(MigrationProgress progress);

List<List<T>> chunkList<T>(List<T> items, int chunkSize) {
  if (chunkSize <= 0) {
    throw ArgumentError.value(chunkSize, 'chunkSize', 'must be > 0');
  }

  final chunks = <List<T>>[];
  for (var i = 0; i < items.length; i += chunkSize) {
    chunks.add(items.sublist(i, (i + chunkSize).clamp(0, items.length)));
  }
  return chunks;
}

abstract class MigrationRunner {
  Future<MigrationReport> run({
    required String companyId,
    required bool dryRun,
    MigrationProgressCallback? onProgress,
  });
}

class HiveToFirestoreMigrator implements MigrationRunner {
  HiveToFirestoreMigrator(this._firestore);

  final FirebaseFirestore _firestore;

  static const int defaultChunkSize = 450;

  @override
  Future<MigrationReport> run({
    required String companyId,
    required bool dryRun,
    MigrationProgressCallback? onProgress,
  }) async {
    final refs = FirestoreRefs.instance();

    var migrated = 0;
    var skipped = 0;

    Future<void> migrateBoxToCollection({
      required String boxName,
      required CollectionReference<Map<String, dynamic>> collection,
      required String phase,
    }) async {
      final box = Hive.box(boxName);
      final entries = box.toMap().entries.toList(growable: false);

      final total = entries.length;
      var phaseMigrated = 0;

      for (final chunk in chunkList(entries, defaultChunkSize)) {
        if (!dryRun) {
          final batch = _firestore.batch();
          for (final entry in chunk) {
            final docId = _resolveDocId(entry.key, entry.value);
            if (docId == null) {
              skipped += 1;
              debugPrint('[migration:$phase] skip: missing id. key=${entry.key}');
              continue;
            }

            final data = _coerceToMap(entry.value);
            if (data == null) {
              skipped += 1;
              debugPrint('[migration:$phase] skip: value not map. id=$docId');
              continue;
            }

            batch.set(collection.doc(docId), data);
            migrated += 1;
            phaseMigrated += 1;
          }

          await batch.commit();
        } else {
          for (final entry in chunk) {
            final docId = _resolveDocId(entry.key, entry.value);
            if (docId == null) {
              skipped += 1;
              continue;
            }

            final data = _coerceToMap(entry.value);
            if (data == null) {
              skipped += 1;
              continue;
            }

            migrated += 1;
            phaseMigrated += 1;
          }
        }

        onProgress?.call(
          MigrationProgress(
            phase: phase,
            migrated: phaseMigrated,
            total: total,
          ),
        );
      }
    }

    Future<void> migrateLedgerBox({
      required String boxName,
      required String phase,
      required DocumentReference<Map<String, dynamic>> Function(String ownerId)
          ownerDoc,
    }) async {
      final box = Hive.box(boxName);
      final entries = box.toMap().entries.toList(growable: false);

      final total = entries.length;
      var phaseMigrated = 0;

      for (final chunk in chunkList(entries, defaultChunkSize)) {
        if (!dryRun) {
          final batch = _firestore.batch();

          for (final entry in chunk) {
            final docId = _resolveDocId(entry.key, entry.value);
            if (docId == null) {
              skipped += 1;
              debugPrint('[migration:$phase] skip: missing id. key=${entry.key}');
              continue;
            }

            final data = _coerceToMap(entry.value);
            if (data == null) {
              skipped += 1;
              debugPrint('[migration:$phase] skip: value not map. id=$docId');
              continue;
            }

            final ownerId = data['customerId'] as String? ??
                data['supplierId'] as String?;
            if (ownerId == null || ownerId.isEmpty) {
              skipped += 1;
              debugPrint('[migration:$phase] skip: missing ownerId. id=$docId');
              continue;
            }

            final ledgerRef = ownerDoc(ownerId).collection('ledger').doc(docId);
            batch.set(ledgerRef, data);
            migrated += 1;
            phaseMigrated += 1;
          }

          await batch.commit();
        } else {
          for (final entry in chunk) {
            final docId = _resolveDocId(entry.key, entry.value);
            if (docId == null) {
              skipped += 1;
              continue;
            }

            final data = _coerceToMap(entry.value);
            if (data == null) {
              skipped += 1;
              continue;
            }

            final ownerId = data['customerId'] as String? ??
                data['supplierId'] as String?;
            if (ownerId == null || ownerId.isEmpty) {
              skipped += 1;
              continue;
            }

            migrated += 1;
            phaseMigrated += 1;
          }
        }

        onProgress?.call(
          MigrationProgress(
            phase: phase,
            migrated: phaseMigrated,
            total: total,
          ),
        );
      }
    }

    await migrateBoxToCollection(
      boxName: 'products',
      collection: refs.products(companyId),
      phase: 'products',
    );

    await migrateBoxToCollection(
      boxName: 'customers',
      collection: refs.customers(companyId),
      phase: 'customers',
    );

    await migrateBoxToCollection(
      boxName: 'suppliers',
      collection: refs.suppliers(companyId),
      phase: 'suppliers',
    );

    await migrateBoxToCollection(
      boxName: 'sales',
      collection: refs.sales(companyId),
      phase: 'sales',
    );

    await migrateBoxToCollection(
      boxName: 'stock_entries',
      collection: refs.stockEntries(companyId),
      phase: 'stockEntries',
    );

    await migrateLedgerBox(
      boxName: 'customer_ledger',
      phase: 'customerLedger',
      ownerDoc: (customerId) =>
          refs.company(companyId).collection('customers').doc(customerId),
    );

    await migrateLedgerBox(
      boxName: 'supplier_ledger',
      phase: 'supplierLedger',
      ownerDoc: (supplierId) =>
          refs.company(companyId).collection('suppliers').doc(supplierId),
    );

    return MigrationReport(migrated: migrated, skipped: skipped);
  }

  String? _resolveDocId(dynamic hiveKey, dynamic value) {
    if (value is Map) {
      final id = value['id'];
      if (id is String && id.isNotEmpty) {
        return id;
      }
    }

    if (hiveKey is String && hiveKey.isNotEmpty) {
      return hiveKey;
    }

    if (hiveKey is int) {
      return hiveKey.toString();
    }

    return null;
  }

  Map<String, dynamic>? _coerceToMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }
}
