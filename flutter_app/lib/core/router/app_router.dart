import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_controller.dart';
import '../../features/auth/domain/user.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/user_management_page.dart';
import '../../features/auth/presentation/account_page.dart';
import '../../features/company_context/domain/company_context_controller.dart';
import '../../features/company_context/presentation/company_select_page.dart';
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
import '../../features/customers/presentation/customers_page.dart';
import '../../features/customers/presentation/customer_detail_page.dart';
import '../../features/customers/presentation/customer_balances_page.dart';
import '../../features/customers/presentation/customer_collections_page.dart';
import '../../features/customers/presentation/customer_statement_page.dart';
import '../../features/pricing/presentation/pricing_page.dart';
import '../../features/sales/quick_sale/quick_sale_screen.dart';
import '../../features/sales/held_sales/held_sales_tab.dart';
import '../../features/scanner/presentation/barcode_scanner_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/settings/presentation/system_settings_page.dart';
import '../widgets/app_shell_scaffold.dart';

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

  ref.listen(authControllerProvider, (_, __) {
    notifier.refresh();
  });

  ref.listen(companyContextProvider, (_, __) {
    notifier.refresh();
  });

  ref.onDispose(notifier.dispose);

  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  // GoRouter tek instance olarak kalsın diye burada hiçbir provider'ı watch etmiyoruz.
  // Redirect içinde auth state'e ref.read ile erişeceğiz.
  final refreshNotifier = ref.read(routerRefreshNotifierProvider);

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
        path: '/company-select',
        name: 'company_select',
        builder: (context, state) => const CompanySelectPage(),
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
                builder: (context, state) => const StockEntryPage(),
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
                path: '/users',
                name: 'users',
                builder: (context, state) => const UserManagementPage(),
              ),
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SystemSettingsPage(),
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
      final authState = ref.read(authControllerProvider);
      final isLoggedIn = authState.isAuthenticated;
      final loggingIn = state.matchedLocation == '/login';
      final selectingCompany = state.matchedLocation == '/company-select';

      final companyState = ref.read(companyContextProvider);
      final hasCompany = companyState.activeCompanyId != null;
      final user = ref.read(currentUserProvider);

      // Giriş yapmamış kullanıcılar sadece /login'e gidebilir.
      if (!isLoggedIn) {
        return loggingIn ? null : '/login';
      }

      // Giriş var ama firma seçimi yoksa kullanıcıyı firma seçimine al.
      if (!hasCompany) {
        return selectingCompany ? null : '/company-select';
      }

      // Giriş yapmış kullanıcı login sayfasına giderse rolüne göre yönlendir.
      if (loggingIn) {
        if (user?.role == UserRole.admin) {
          return '/dashboard';
        } else {
          return '/sales';
        }
      }

      // Firma seçimi sayfasındayken aktif firma set edildiyse ana sayfaya yönlendir.
      if (selectingCompany) {
        if (user?.role == UserRole.admin) {
          return '/dashboard';
        } else {
          return '/sales';
        }
      }

      // Rol tabanlı erişim kontrolü.
      final location = state.matchedLocation;

      // Admin olmayan (cashier) kullanıcının erişemeyeceği rotalar.
      final adminOnlyPaths = <String>[
        '/suppliers',
        '/stock-entry',
        '/stock-movements',
        '/pricing',
        '/customers',
        '/scan',
        '/users',
        '/products',
      ];

      if (user != null && user.role == UserRole.cashier) {
        if (adminOnlyPaths.any((path) => location.startsWith(path))) {
          // Cashier admin ekranına girmeye çalışıyorsa satış ekranına at.
          return '/sales';
        }
      }

      // Diğer tüm durumlarda yönlendirme yok.
      return null;
    },
  );
});