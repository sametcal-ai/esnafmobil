import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/customer_repository.dart';
import '../data/customer_ledger_repository.dart';
import 'customer.dart';
import 'customer_ledger.dart';

class CustomerDetailState {
  final Customer customer;
  final List<CustomerLedgerEntry> entries;
  final double balance;
  final bool isLoading;
  final String? errorMessage;
  final bool isLoadingMore;
  final bool hasMore;

  const CustomerDetailState({
    required this.customer,
    required this.entries,
    required this.balance,
    required this.isLoading,
    required this.errorMessage,
    required this.isLoadingMore,
    required this.hasMore,
  });

  CustomerDetailState copyWith({
    Customer? customer,
    List<CustomerLedgerEntry>? entries,
    double? balance,
    bool? isLoading,
    String? errorMessage,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return CustomerDetailState(
      customer: customer ?? this.customer,
      entries: entries ?? this.entries,
      balance: balance ?? this.balance,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class CustomerDetailController extends StateNotifier<CustomerDetailState> {
  final String companyId;
  final CustomerLedgerRepository _ledgerRepository;
  final int _pageSize;

  CustomerDetailController({
    required this.companyId,
    required Customer customer,
    required CustomerLedgerRepository ledgerRepository,
    required int pageSize,
  })  : _ledgerRepository = ledgerRepository,
        _pageSize = pageSize,
        super(
          CustomerDetailState(
            customer: customer,
            entries: const [],
            balance: 0,
            isLoading: true,
            errorMessage: null,
            isLoadingMore: false,
            hasMore: true,
          ),
        ) {
    _load();
  }

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isLoadingMore: false,
      hasMore: true,
    );
    await _load();
  }

  Future<void> _load() async {
    try {
      final entries = await _ledgerRepository.getEntriesForCustomerPaged(
        companyId,
        state.customer.id,
        offset: 0,
        limit: _pageSize,
      );
      final balance =
          await _ledgerRepository.getBalanceForCustomer(companyId, state.customer.id);
      state = state.copyWith(
        entries: entries,
        balance: balance,
        isLoading: false,
        errorMessage: null,
        hasMore: entries.length == _pageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Hareketler yüklenemedi',
      );
    }
  }

  Future<void> addPayment(double amount) async {
    if (amount <= 0) return;
    await _ledgerRepository.addPaymentEntry(
      companyId: companyId,
      customer: state.customer,
      amount: amount,
    );
    await _load();
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);

    try {
      final nextOffset = state.entries.length;
      final next = await _ledgerRepository.getEntriesForCustomerPaged(
        companyId,
        state.customer.id,
        offset: nextOffset,
        limit: _pageSize,
      );
      if (next.isEmpty) {
        state = state.copyWith(
          isLoadingMore: false,
          hasMore: false,
        );
        return;
      }

      final updated = [...state.entries, ...next];
      state = state.copyWith(
        entries: updated,
        isLoadingMore: false,
        hasMore: next.length == _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

