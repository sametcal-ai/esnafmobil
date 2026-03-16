</old_ 'de><new_code>import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supplier_ledger_repository.dart';
import 'supplier.dart';
import 'supplier_ledger.dart';

class SupplierDetailState {
  final Supplier supplier;
  final List<SupplierLedgerEntry> entries;
  final double balance;
  final bool isLoading;
  final String? errorMessage;

  const SupplierDetailState({
    required this.supplier,
    required this.entries,
    required this.balance,
    required this.isLoading,
    required this.errorMessage,
  });

  SupplierDetailState copyWith({
    Supplier? supplier,
    List<SupplierLedgerEntry>? entries,
    double? balance,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SupplierDetailState(
      supplier: supplier ?? this.supplier,
      entries: entries ?? this.entries,
      balance: balance ?? this.balance,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class SupplierDetailController extends StateNotifier<SupplierDetailState> {
  final String companyId;
  final SupplierLedgerRepository _ledgerRepository;

  SupplierDetailController({
    required this.companyId,
    required Supplier supplier,
    required SupplierLedgerRepository ledgerRepository,
  })  : _ledgerRepository = ledgerRepository,
        super(
          SupplierDetailState(
            supplier: supplier,
            entries: const [],
            balance: 0,
            isLoading: true,
            errorMessage: null,
          ),
        ) {
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await _ledgerRepository.getEntriesForSupplier(
        companyId,
        state.supplier.id,
      );
      final balance = await _ledgerRepository.getBalanceForSupplier(
        companyId,
        state.supplier.id,
      );
      state = state.copyWith(
        entries: entries,
        balance: balance,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Hareketler yüklenemedi',
      );
    }
  }
}
