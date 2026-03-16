import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class CompanyMember {
  final String uid;
  final String role;
  final String status;
  final List<String> permissions;
  final List<String> storeIds;

  const CompanyMember({
    required this.uid,
    required this.role,
    required this.status,
    required this.permissions,
    required this.storeIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role,
      'status': status,
      'permissions': permissions,
      'storeIds': storeIds,
    };
  }

  static List<String> _asStringList(dynamic raw) {
    if (raw is Iterable) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const <String>[];
  }

  factory CompanyMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    return CompanyMember(
      uid: doc.id,
      role: (data['role'] as String?) ?? 'member',
      status: (data['status'] as String?) ?? 'active',
      permissions: _asStringList(data['permissions']),
      storeIds: _asStringList(data['storeIds']),
    );
  }

  factory CompanyMember.fromMap({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    return CompanyMember(
      uid: uid,
      role: (data['role'] as String?) ?? 'member',
      status: (data['status'] as String?) ?? 'active',
      permissions: _asStringList(data['permissions']),
      storeIds: _asStringList(data['storeIds']),
    );
  }
}
