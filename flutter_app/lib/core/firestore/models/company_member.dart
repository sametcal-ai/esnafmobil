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

  factory CompanyMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    List<String> asStringList(dynamic raw) {
      if (raw is Iterable) {
        return raw.whereType<String>().toList(growable: false);
      }
      return const <String>[];
    }

    return CompanyMember(
      uid: doc.id,
      role: (data['role'] as String?) ?? 'member',
      status: (data['status'] as String?) ?? 'active',
      permissions: asStringList(data['permissions']),
      storeIds: asStringList(data['storeIds']),
    );
  }
}
