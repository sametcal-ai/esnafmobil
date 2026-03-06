import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class AppShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShellScaffold({
    super.key,
    required this.navigationShell,
  });

  void _onTabTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    // Sağdan sola (sonraki tab)
    if (velocity < -300) {
      final nextIndex = navigationShell.currentIndex + 1;
      // 0: Dashboard, 1: Sales, 2: Account
      if (nextIndex <= 2) {
        navigationShell.goBranch(
          nextIndex,
          initialLocation: false,
        );
      }
      return;
    }

    // Soldan sağa (önceki tab)
    if (velocity > 300) {
      final prevIndex = navigationShell.currentIndex - 1;
      if (prevIndex >= 0) {
        navigationShell.goBranch(
          prevIndex,
          initialLocation: false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        final navigator = Navigator.of(context);

        // Önce iç sayfa stack'inde geri gidilebiliyorsa onu yap.
        if (navigator.canPop()) {
          navigator.pop();
          return;
        }

        // İç sayfa yok ve Sales / Account sekmesindeyiz -> Dashboard'a dön.
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0, initialLocation: false);
          return;
        }

        // Dashboard root'tayız, uygulamadan çık.
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: _handleSwipe,
          child: navigationShell,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: _onTabTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              label: 'Ana Menü',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale_outlined),
              label: 'Hızlı Satış',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Hesabım',
            ),
          ],
        ),
      ),
    );
  }
}