import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/auditable.dart';

enum PriceListType {
  cash,
  card,
  credit,
  general,
}

class PriceList {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final PriceListType type;
  final bool isActive;

  /// Pasife düşme sebebi gibi UI'de gösterilecek kısa not.
  /// Örn: "Süresi doldu".
  final String? inactiveReason;

  final AuditMeta meta;

  const PriceList({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.isActive,
    this.inactiveReason,
    required this.meta,
  });

  bool isValidAt(DateTime now) {
    return !now.isBefore(startDate) && !now.isAfter(endDate);
  }

  PriceList copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    PriceListType? type,
    bool? isActive,
    String? inactiveReason,
    AuditMeta? meta,
  }) {
    return PriceList(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      inactiveReason: inactiveReason ?? this.inactiveReason,
      meta: meta ?? this.meta,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'name': name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'type': type.name,
      'isActive': isActive,
      'inactiveReason': inactiveReason,
      ...meta.toFirestoreMap(),
    };
  }

  factory PriceList.fromMap(Map<String, dynamic> map) {
    final startRaw = map['startDate'];
    final endRaw = map['endDate'];

    DateTime startDate;
    if (startRaw is Timestamp) {
      startDate = startRaw.toDate();
    } else if (startRaw is int) {
      startDate = DateTime.fromMillisecondsSinceEpoch(startRaw);
    } else if (startRaw is String) {
      startDate = DateTime.tryParse(startRaw) ?? DateTime.now();
    } else {
      startDate = DateTime.now();
    }

    DateTime endDate;
    if (endRaw is Timestamp) {
      endDate = endRaw.toDate();
    } else if (endRaw is int) {
      endDate = DateTime.fromMillisecondsSinceEpoch(endRaw);
    } else if (endRaw is String) {
      endDate = DateTime.tryParse(endRaw) ?? startDate;
    } else {
      endDate = startDate;
    }

    final typeRaw = (map['type'] as String?) ?? PriceListType.general.name;
    final type = PriceListType.values.firstWhere(
      (e) => e.name == typeRaw,
      orElse: () => PriceListType.general,
    );

    final meta = AuditMeta.fromMap(map);

    return PriceList(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      startDate: startDate,
      endDate: endDate,
      type: type,
      isActive: (map['isActive'] as bool?) ?? false,
      inactiveReason: map['inactiveReason'] as String?,
      meta: meta,
    );
  }

  factory PriceList.fromDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) {
      final now = DateTime.now();
      final fallback = AuditMeta.create(createdBy: 'system', now: now);
      return PriceList(
        id: snap.id,
        name: '',
        startDate: now,
        endDate: now,
        type: PriceListType.general,
        isActive: false,
        meta: fallback,
      );
    }

    final map = <String, dynamic>{...data};
    map['id'] ??= snap.id;
    return PriceList.fromMap(map);
  }
}
