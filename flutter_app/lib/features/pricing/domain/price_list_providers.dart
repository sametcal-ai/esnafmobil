import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../company/domain/active_company_provider.dart';
import '../data/price_list_repository.dart';
import 'price_list.dart';
import 'price_list_item.dart';

final priceListsProvider = StreamProvider.autoDispose<List<PriceList>>((ref) {
  final companyId = ref.watch(activeCompanyIdProvider);
  if (companyId == null) {
    return const Stream<List<PriceList>>.empty();
  }

  final repo = ref.watch(priceListRepositoryProvider);
  return repo.watchPriceLists(companyId);
});

final activePriceListProvider = StreamProvider.autoDispose<PriceList?>((ref) {
  final companyId = ref.watch(activeCompanyIdProvider);
  if (companyId == null) {
    return const Stream<PriceList?>.empty();
  }

  final repo = ref.watch(priceListRepositoryProvider);

  // Aktif liste geçişi server (scheduled function) tarafında yapılır.

  return repo.watchActivePriceList(companyId);
});

final priceListItemsProvider =
    StreamProvider.family.autoDispose<List<PriceListItem>, String>((ref, priceListId) {
  final companyId = ref.watch(activeCompanyIdProvider);
  if (companyId == null) {
    return const Stream<List<PriceListItem>>.empty();
  }

  final repo = ref.watch(priceListRepositoryProvider);
  return repo.watchItems(companyId, priceListId);
});

final activePriceListItemsProvider = StreamProvider.autoDispose<List<PriceListItem>>((ref) {
  final activeAsync = ref.watch(activePriceListProvider);

  return activeAsync.when(
    data: (active) {
      if (active == null) {
        return const Stream<List<PriceListItem>>.empty();
      }
      return ref.watch(priceListItemsProvider(active.id).stream);
    },
    loading: () => const Stream<List<PriceListItem>>.empty(),
    error: (_, __) => const Stream<List<PriceListItem>>.empty(),
  );
});

final activePriceListPriceMapProvider = Provider.autoDispose<Map<String, double>>((ref) {
  final itemsAsync = ref.watch(activePriceListItemsProvider);
  final items = itemsAsync.asData?.value ?? const <PriceListItem>[];

  final map = <String, double>{};
  for (final item in items) {
    map[item.productId] = item.salePrice;
  }
  return map;
});
