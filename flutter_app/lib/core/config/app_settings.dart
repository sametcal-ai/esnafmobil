import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/current_user_provider.dart';
import '../../features/auth/domain/user.dart';
import '../../features/company/domain/active_company_provider.dart';
import '../../features/company/domain/company_memberships_provider.dart';
import '../firestore/firestore_refs.dart';

@immutable
class AppSettings {
  final double barcodeScanDelaySeconds;
  final double defaultMarginPercent;
  /// Ürün bazlı varsayılan kâr marjı (%).
  final double productDefaultMarginPercent;
  /// Aramanın devreye girmesi için gereken minimum karakter sayısı.
  final int searchFilterMinChars;
  /// Müşteri/ürün hareket listelerinde sayfa başına kayıt sayısı.
  final int movementsPageSize;

  const AppSettings({
    required this.barcodeScanDelaySeconds,
    required this.defaultMarginPercent,
    required this.productDefaultMarginPercent,
    required this.searchFilterMinChars,
    required this.movementsPageSize,
  });

  factory AppSettings.initial() {
    return const AppSettings(
      barcodeScanDelaySeconds: 2.0,
      defaultMarginPercent: 30.0,
      productDefaultMarginPercent: 30.0,
      searchFilterMinChars: 2,
      // Hareket listesi varsayılanı: 25 (5,10,15,...,100 aralığında bir değer)
      movementsPageSize: 25,
    );
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    final initial = AppSettings.initial();
    return AppSettings(
      barcodeScanDelaySeconds: (map['barcodeScanDelaySeconds'] as num?)?.toDouble() ??
          initial.barcodeScanDelaySeconds,
      defaultMarginPercent:
          (map['defaultMarginPercent'] as num?)?.toDouble() ?? initial.defaultMarginPercent,
      productDefaultMarginPercent: (map['productDefaultMarginPercent'] as num?)?.toDouble() ??
          initial.productDefaultMarginPercent,
      searchFilterMinChars:
          (map['searchFilterMinChars'] as num?)?.toInt() ?? initial.searchFilterMinChars,
      movementsPageSize:
          (map['movementsPageSize'] as num?)?.toInt() ?? initial.movementsPageSize,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'barcodeScanDelaySeconds': barcodeScanDelaySeconds,
      'defaultMarginPercent': defaultMarginPercent,
      'productDefaultMarginPercent': productDefaultMarginPercent,
      'searchFilterMinChars': searchFilterMinChars,
      'movementsPageSize': movementsPageSize,
    };
  }

  AppSettings copyWith({
    double? barcodeScanDelaySeconds,
    double? defaultMarginPercent,
    double? productDefaultMarginPercent,
    int? searchFilterMinChars,
    int? movementsPageSize,
  }) {
    return AppSettings(
      barcodeScanDelaySeconds:
          barcodeScanDelaySeconds ?? this.barcodeScanDelaySeconds,
      defaultMarginPercent: defaultMarginPercent ?? this.defaultMarginPercent,
      productDefaultMarginPercent:
          productDefaultMarginPercent ?? this.productDefaultMarginPercent,
      searchFilterMinChars: searchFilterMinChars ?? this.searchFilterMinChars,
      movementsPageSize: movementsPageSize ?? this.movementsPageSize,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.barcodeScanDelaySeconds == barcodeScanDelaySeconds &&
        other.defaultMarginPercent == defaultMarginPercent &&
        other.productDefaultMarginPercent == productDefaultMarginPercent &&
        other.searchFilterMinChars == searchFilterMinChars &&
        other.movementsPageSize == movementsPageSize;
  }

  @override
  int get hashCode => Object.hash(
        barcodeScanDelaySeconds,
        defaultMarginPercent,
        productDefaultMarginPercent,
        searchFilterMinChars,
        movementsPageSize,
      );
}

class AppSettingsController extends Notifier<AppSettings> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  String? _listeningCompanyId;
  bool? _lastDocExists;
  int _companyChangeToken = 0;
  final Set<String> _attemptedDefaultCreateForCompany = <String>{};

  @override
  AppSettings build() {
    ref.listen<String?>(activeCompanyIdProvider, (prev, next) {
      _onCompanyChanged(next);
    });

    ref.listen<User?>(currentUserProvider, (prev, next) {
      final companyId = _listeningCompanyId;
      if (companyId == null) return;
      if (_lastDocExists != false) return;
      if (!_isAdmin()) return;
      if (_attemptedDefaultCreateForCompany.contains(companyId)) return;

      _attemptedDefaultCreateForCompany.add(companyId);
      _systemSettingsDoc(companyId).set(AppSettings.initial().toMap());
    });

    Future.microtask(() {
      _onCompanyChanged(ref.read(activeCompanyIdProvider));
    });

    ref.onDispose(() {
      _companyChangeToken++;
      _sub?.cancel();
    });


    return AppSettings.initial();
  }

  DocumentReference<Map<String, dynamic>> _systemSettingsDoc(String companyId) {
    final refs = ref.read(firestoreRefsProvider);
    return refs.company(companyId).collection('settings').doc('system');
  }

  bool _isAdmin() {
    final user = ref.read(currentUserProvider);
    return user != null && user.role == UserRole.admin;
  }

  void _onCompanyChanged(String? companyId) {
    if (companyId == _listeningCompanyId) return;

    _companyChangeToken++;
    final token = _companyChangeToken;

    _sub?.cancel();
    _sub = null;
    _listeningCompanyId = companyId;
    _lastDocExists = null;
    state = AppSettings.initial();

    if (companyId == null) return;

    final docRef = _systemSettingsDoc(companyId);

    Future.microtask(() async {
      final snap = await docRef.get();
      if (!ref.mounted) return;
      if (token != _companyChangeToken) return;
      if (companyId != _listeningCompanyId) return;

      _lastDocExists = snap.exists;

      if (!snap.exists &&
          _isAdmin() &&
          !_attemptedDefaultCreateForCompany.contains(companyId)) {
        _attemptedDefaultCreateForCompany.add(companyId);
        await docRef.set(AppSettings.initial().toMap());
        return;
      }

      final data = snap.data();
      if (data == null) return;

      state = AppSettings.fromMap(data);
    });

    _sub = docRef.snapshots().listen((snap) {
      if (!ref.mounted) return;
      if (token != _companyChangeToken) return;
      if (companyId != _listeningCompanyId) return;

      _lastDocExists = snap.exists;

      if (!snap.exists) {
        if (_isAdmin() && !_attemptedDefaultCreateForCompany.contains(companyId)) {
          _attemptedDefaultCreateForCompany.add(companyId);
          docRef.set(AppSettings.initial().toMap());
        }
        return;
      }

      final data = snap.data();
      if (data == null) return;

      state = AppSettings.fromMap(data);
    });
  }

  Future<void> save(AppSettings next) async {
    final companyId = ref.read(activeCompanyIdProvider);
    if (companyId == null) return;

    final docRef = _systemSettingsDoc(companyId);
    await docRef.set(next.toMap(), SetOptions(merge: true));
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
  AppSettingsController.new,
);