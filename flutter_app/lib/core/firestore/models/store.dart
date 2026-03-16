import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class Store {
  final String id;
  final String name;
  final DateTime createdAt;
  final bool isActive;

  const Store({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  factory Store.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAtRaw = data['createdAt'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);

    return Store(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      createdAt: createdAt,
      isActive: (data['isActive'] as bool?) ?? true,
    );
  }
}
