import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/firebase_auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/user_management_page.dart';
import '../../features/auth/presentation/user_detail_page.dart';
import '../../features/auth/presentation/account_page.dart';
import '../../features/company/domain/active_company_provider.dart';
import '../../features/company/presentation/company_gate_page.dart';

import '../../features/products/presentation/products_page.dart';
import '../../features/products/presentation/products_lookup_page.dart';
import '../../features/products/presentation/product_detail_page.dart';
import '../../features/products/presentation/product_purchases_page.dart';
import '../../features/products/presentation/product_movements_page.dart';
import '../../features/suppliers/presentation/suppliers_page.dart';
import '../../features/suppliers/presentation/stock_entry_page.dart';
import '../../features/suppliers/presentation/stock_movements_page.dart';
import '../../features/suppliers/presentation/supplier_detail_page.dart';
import '../../features/suppliers/presentation/supplier_payments_page.dart';
import '../../features/suppliers/presentation/supplier_statement_page.dart';
import '../../features/suppliers/domain/supplier.dart';
import '../../features/customers/presentation/customers_page.dart';
import '../../features/customers/presentation/customer_detail_page.dart';
import '../../features/customers/presentation/customer_balances_page.dart';
import '../../features/customers/presentation/customer_collections_page.dart';
import '../../features/customers/presentation/customer_statement_page.dart';
import '../../features/pricing/presentation/pricing_page.dart';
import '../../features/sales/quick_sale/quick_sale_screen.dart';
import '../../features/sales/held_sales/held_sales_tab.dart';
import '../../features/sales/presentation/sales_list_page.dart';
import '../../features/sales/presentation/sale_edit_args.dart';
import '../../features/scanner/presentation/barcode_scanner_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/settings/presentation/system_settings_page.dart';
import '../../features/alerts/presentation/alerts_page.dart';
import '../../features/operations/presentation/operations_page.dart';
import '../../features/operations/presentation/stock_adjustment_page.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/app_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Router'ı yeniden yaratmadan redirect'leri tetiklemek için
/// auth state değişimlerinden haberdar olan bir ChangeNotifier.
class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}

/// Auth değiştiğinde GoRouter.redirect'in yeniden çalışması için
/// kullanılan notifier provider.
/// Burada authControllerProvider'ı dinleyip sadece notifyListeners çağırıyoruz.
final routerRefreshNotifierProvider =
    Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier();

  ref.listen(authStateProvider, (_, __) {
    notifier.refresh();
  });

  ref.listen(activeCompanyIdProvider, (_, __) {
    notifier.refresh();
  });

  

  ref.onDispose(notifier.dispose);

  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  // GoRouter tek instance olarak kalsın diye redirect içinde auth state'e ref.read ile erişiyoruz.
  // Ancak refresh notifier'ın dispose olmaması için burada watch etmemiz gerekiyor.
  final refreshNotifier = ref.watch(routerRefreshNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/company-gate',
        name: 'company_gate',
        builder: (context, state) => const CompanyGatePage(),
      ),
      GoRoute(
        path: '/pending-approval',
        name: 'pending_approval',
        builder: (context, state) => const CompanyGatePage(),
      ),
      GoRoute(
        path: '/no-company',
        name: 'no_company',
        builder: (context, state) => const CompanyGatePage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Dashboard (Ana Menü) ve admin sayfaları
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                builder: (context, state) => const DashboardPage(),
              ),
              GoRoute(
                path: '/products',
                name: 'products',
                builder: (context, state) => const ProductsPage(),
              ),
              GoRoute(
                path: '/products/:id',
                name: 'product_detail',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return ProductDetailPage(productId: id);
                },
              ),
              GoRoute(
                path: '/products/:id/purchases',
                name: 'product_purchases',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return ProductPurchasesPage(productId: id);
                },
              ),
              GoRoute(
                path: '/products/:id/movements',
                name: 'product_movements',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return ProductMovementsPage(productId: id);
                },
              ),
              GoRoute(
                path: '/suppliers',
                name: 'suppliers',
                builder: (context, state) => const SuppliersPage(),
              ),
              GoRoute(
                path: '/suppliers/:id',
                name: 'supplier_detail',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return SupplierDetailPage(supplierId: id);
                },
              ),
              GoRoute(
                path: '/suppliers/:id/payments',
                name: 'supplier_payments',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return SupplierPaymentsPage(supplierId: id);
                },
              ),
              GoRoute(
                path: '/suppliers/:id/statement',
                name: 'supplier_statement',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return SupplierStatementPage(supplierId: id);
                },
              ),
              GoRoute(
                path: '/stock-entry',
                name: 'stock_entry',
                builder: (context, state) {
                  final initialSupplier = state.extra is Supplier
                      ? state.extra as Supplier
                      : null;
                  return StockEntryPage(initialSupplier: initialSupplier);
                },
              ),
              GoRoute(
                path: '/stock-movements',
                name: 'stock_movements',
                builder: (context, state) => const StockMovementsPage(),
              ),
              GoRoute(
                path: '/customers',
                name: 'customers',
                builder: (context, state) => const CustomersPage(),
              ),
              GoRoute(
                path: '/customers/:id',
                name: 'customer_detail',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return CustomerDetailPage(customerId: id);
                },
              ),
              GoRoute(
                path: '/customers/:id/collections',
                name: 'customer_collections',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return CustomerCollectionsPage(customerId: id);
                },
              ),
              GoRoute(
                path: '/customers/:id/statement',
                name: 'customer_statement',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return CustomerStatementPage(customerId: id);
                },
              ),
              GoRoute(
                path: '/customer-balances',
                name: 'customer_balances',
                builder: (context, state) => const CustomerBalancesPage(),
              ),
              GoRoute(
                path: '/pricing',
                name: 'pricing',
                builder: (context, state) => const PricingPage(),
              ),
              GoRoute(
                path: '/sales-list',
                name: 'sales_list',
                builder: (context, state) => const SalesListPage(),
              ),
              GoRoute(
                path: '/sales-list/edit',
                name: 'sale_edit',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final extra = state.extra;
                  if (extra is! SaleEditArgs) {
                    return const AppScaffold(
                      title: 'Satışı Düzenle',
                      body: Center(child: Text('Satış bilgisi eksik')),
                    );
                  }
                  return SaleEditScreen(editArgs: extra);
                },
              ),
              GoRoute(
                path: '/users',
                name: 'users',
                builder: (context, state) => const UserManagementPage(),
              ),
              GoRoute(
                path: '/users/:uid',
                name: 'user_detail',
                builder: (context, state) {
                  final uid = state.pathParameters['uid']!;
                  return UserDetailPage(uid: uid);
                },
              ),
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SystemSettingsPage(),
              ),
              GoRoute(
                path: '/alerts',
                name: 'alerts',
                builder: (context, state) => const AlertsPage(),
              ),
              GoRoute(
                path: '/operations',
                name: 'operations',
                builder: (context, state) => const OperationsPage(),
              ),
              GoRoute(
                path: '/operations/stock-adjustment',
                name: 'stock_adjustment',
                builder: (context, state) => const StockAdjustmentPage(),
              ),
            ],
          ),
          // Branch 1: Ürünler (salt okunur)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/products-lookup',
                name: 'products_lookup',
                builder: (context, state) => const ProductsLookupPage(),
              ),
            ],
          ),
          // Branch 2: Sales (Hızlı Satış) ve ilgili sayfalar
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sales',
                name: 'sales',
                builder: (context, state) => const QuickSaleScreen(),
              ),
              GoRoute(
                path: '/scan',
                name: 'scan',
                builder: (context, state) => const BarcodeScannerPage(),
              ),
            ],
          ),
          // Branch 3: Bekleyen Satışlar
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/held-sales',
                name: 'held_sales',
                builder: (context, state) => const HeldSalesTab(),
              ),
            ],
          ),
          // Branch 4: Account (Hesabım)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                name: 'account',
                builder: (context, state) => const AccountPage(),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      // side-effect provider (logout => activeCompanyId reset)
      ref.read(activeCompanyResetterProvider);

      final authState = ref.read(authStateProvider);
      // FirebaseAuth initial state is async; redirect sırasında `loading` ise
      // kullanıcıyı login'e geri fırlatmak yerine mevcut lokasyonda kal.
      if (authState.isLoading) return null;

      final authUser = authState.asData?.value;
      final isLoggedIn = authUser != null;
      final activeCompanyId = ref.read(activeCompanyIdProvider);

      final location = state.matchedLocation;
      final loggingIn = location == '/login';
      final inCompanyGate = location == '/company-gate';

      if (!isLoggedIn) {
        return loggingIn ? null : '/login';
      }

      // Auth var ama henüz aktif firma seçilmediyse her şeyi gate'e çek.
      if (activeCompanyId == null) {
        return inCompanyGate ? null : '/company-gate';
      }

      // Auth + activeCompanyId hazırsa login/gate'e girişleri ana sayfaya al.
      if (loggingIn || inCompanyGate) {
        return '/dashboard';
      }

      return null;
    },
  );
});
