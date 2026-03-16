import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class Company {
  final String id;
  final String companyCode;
  final String name;
  final DateTime createdAt;
  final String ownerUid;

  const Company({
    required this.id,
    required this.companyCode,
    required this.name,
    required this.createdAt,
    required this.ownerUid,
  });

  Map<String, dynamic> toMap() {
    return {
      'companyCode': companyCode,
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
      'ownerUid': ownerUid,
    };
  }

  factory Company.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAtRaw = data['createdAt'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);

    return Company(
      id: doc.id,
      companyCode: (data['companyCode'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      createdAt: createdAt,
      ownerUid: (data['ownerUid'] as String?) ?? '',
    );
  }
}
