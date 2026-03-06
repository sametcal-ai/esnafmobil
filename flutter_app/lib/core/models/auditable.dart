import 'package:flutter/foundation.dart';

/// Ortak denetim (audit) ve soft-state alanlarını temsil eder.
///
/// Tüm kalıcı entity'ler bu meta bilgiyi Map'e düz alanlar (createdDate, ...)
/// olarak yazar. Tarihler epoch millis (int) şeklinde saklanır.
@immutable
class AuditMeta {
  final DateTime createdDate;
  final String createdBy;
  final DateTime modifiedDate;
  final String modifiedBy;
  final int versionNo;
  final DateTime versionDate;
  final bool isLocked;
  final bool isVisible;
  final bool isActived;
  final bool isDeleted;

  const AuditMeta({
    required this.createdDate,
    required this.createdBy,
    required this.modifiedDate,
    required this.modifiedBy,
    required this.versionNo,
    required this.versionDate,
    required this.isLocked,
    required this.isVisible,
    required this.isActived,
    required this.isDeleted,
  });

  /// Yeni bir kayıt için başlangıç meta bilgisi üretir.
  factory AuditMeta.create({
    required String createdBy,
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    return AuditMeta(
      createdDate: ts,
      createdBy: createdBy,
      modifiedDate: ts,
      modifiedBy: createdBy,
      versionNo: 1,
      versionDate: ts,
      isLocked: false,
      isVisible: true,
      isActived: true,
      isDeleted: false,
    );
  }

  /// Mevcut meta üzerinde güncelleme uygular.
  AuditMeta touch({
    required String modifiedBy,
    bool bumpVersion = false,
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    return AuditMeta(
      createdDate: createdDate,
      createdBy: createdBy,
      modifiedDate: ts,
      modifiedBy: modifiedBy,
      versionNo: bumpVersion ? (versionNo + 1) : versionNo,
      versionDate: bumpVersion ? ts : versionDate,
      isLocked: isLocked,
      isVisible: isVisible,
      isActived: isActived,
      isDeleted: isDeleted,
    );
  }

  /// Soft delete uygular.
  AuditMeta softDelete({
    required String modifiedBy,
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    return AuditMeta(
      createdDate: createdDate,
      createdBy: createdBy,
      modifiedDate: ts,
      modifiedBy: modifiedBy,
      versionNo: versionNo + 1,
      versionDate: ts,
      isLocked: isLocked,
      isVisible: false,
      isActived: false,
      isDeleted: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'createdDate': createdDate.millisecondsSinceEpoch,
      'createdBy': createdBy,
      'modifiedDate': modifiedDate.millisecondsSinceEpoch,
      'modifiedBy': modifiedBy,
      'versionNo': versionNo,
      'versionDate': versionDate.millisecondsSinceEpoch,
      'isLocked': isLocked,
      'isVisible': isVisible,
      'isActived': isActived,
      'isDeleted': isDeleted,
    };
  }

  /// Eski kayıtlardan meta alanlarını okur.
  /// Eksik alanlar için güvenli varsayılanlar kullanır.
  factory AuditMeta.fromMap(
    Map<dynamic, dynamic> dynamicMap, {
    DateTime? fallbackCreatedAt,
    String defaultUser = 'migration',
  }) {
    final map = Map<String, dynamic>.from(dynamicMap as Map);

    DateTime createdDate;
    final createdDateRaw = map['createdDate'];
    if (createdDateRaw is int) {
      createdDate =
          DateTime.fromMillisecondsSinceEpoch(createdDateRaw);
    } else {
      // Eski şemalarda createdAt varsa onu kullan.
      final createdAtRaw = map['createdAt'];
      if (createdAtRaw is int) {
        createdDate =
            DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
      } else if (fallbackCreatedAt != null) {
        createdDate = fallbackCreatedAt;
      } else {
        createdDate =
            DateTime.fromMillisecondsSinceEpoch(0); // epoch
      }
    }

    DateTime modifiedDate;
    final modifiedDateRaw = map['modifiedDate'];
    if (modifiedDateRaw is int) {
      modifiedDate =
          DateTime.fromMillisecondsSinceEpoch(modifiedDateRaw);
    } else {
      modifiedDate = createdDate;
    }

    DateTime versionDate;
    final versionDateRaw = map['versionDate'];
    if (versionDateRaw is int) {
      versionDate =
          DateTime.fromMillisecondsSinceEpoch(versionDateRaw);
    } else {
      versionDate = modifiedDate;
    }

    final createdBy = (map['createdBy'] as String?) ?? defaultUser;
    final modifiedBy = (map['modifiedBy'] as String?) ?? createdBy;
    final versionNo = (map['versionNo'] as int?) ?? 1;

    final isLocked = (map['isLocked'] as bool?) ?? false;
    final isVisible = (map['isVisible'] as bool?) ?? true;
    final isActived = (map['isActived'] as bool?) ?? true;
    final isDeleted = (map['isDeleted'] as bool?) ?? false;

    return AuditMeta(
      createdDate: createdDate,
      createdBy: createdBy,
      modifiedDate: modifiedDate,
      modifiedBy: modifiedBy,
      versionNo: versionNo,
      versionDate: versionDate,
      isLocked: isLocked,
      isVisible: isVisible,
      isActived: isActived,
      isDeleted: isDeleted,
    );
  }
}

/// Bir kaydın aktif (listelemeye uygun) sayılıp sayılmayacağını kontrol eder.
/// Map verilmesi beklenir.
bool isActiveRecordMap(Map<dynamic, dynamic> dynamicMap) {
  final map = Map<String, dynamic>.from(dynamicMap as Map);
  final isDeleted = (map['isDeleted'] as bool?) ?? false;
  final isVisible = (map['isVisible'] as bool?) ?? true;
  final isActived = (map['isActived'] as bool?) ?? true;
  return !isDeleted && isVisible && isActived;
}
