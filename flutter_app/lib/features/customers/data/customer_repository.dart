import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/auditable.dart';
import '../domain/customer.dart';

class CustomerRepository {
  static const String customersBoxName = 'customers';
  static const _uuid = Uuid();

  Box get _customersBox => Hive.box(customersBoxName);

  Future<List<Customer>> getAllCustomers() async {
    return _customersBox.values
        .whereType<Map>()
        .where(isActiveRecordMap)
        .map((map) => Customer.fromMap(map))
        .toList(growable: false);
  }

  Future<Customer> createCustomer({
    String? code,
    required String name,
    String? phone,
    String? email,
    String? workplace,
    String? note,
  }) async {
    final id = _uuid.v4();
    final meta = AuditMeta.create(createdBy: 'system');
    final customer = Customer(
      id: id,
      code: code,
      name: name,
      phone: phone,
      email: email,
      workplace: workplace,
      note: note,
      meta: meta,
    );
    await _customersBox.put(id, customer.toMap());
    return customer;
  }

  Future<Customer?> getCustomerById(String id) async {
    final raw = _customersBox.get(id);
    if (raw is! Map) return null;
    return Customer.fromMap(raw);
  }

  Future<Customer?> updateCustomer(Customer customer) async {
    final raw = _customersBox.get(customer.id);
    if (raw is! Map) return null;
    final existing = Customer.fromMap(raw);

    if (existing.meta.isLocked) {
      return null;
    }

    final updatedMeta = existing.meta.touch(
      modifiedBy: 'system',
      bumpVersion: true,
    );

    final updated = customer.copyWith(meta: updatedMeta);
    await _customersBox.put(customer.id, updated.toMap());
    return updated;
  }

  /// Müşteriyi soft delete ile siler.
  /// Kayıt Hive'da kalır ancak listelemelerde görünmez.
  Future<void> deleteCustomer(
    String id, {
    String? currentUserId,
  }) async {
    final raw = _customersBox.get(id);
    if (raw is! Map) return;
    final existing = Customer.fromMap(raw);
    final deletedMeta = existing.meta.softDelete(modifiedBy: 'system');
    final deleted = existing.copyWith(meta: deletedMeta);
    await _customersBox.put(id, deleted.toMap());
  }
}