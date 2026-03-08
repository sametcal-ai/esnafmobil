import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'bottom_navigation_bar.dart';

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

    if (velocity < -300) {
      final nextIndex = navigationShell.currentIndex + 1;
      if (nextIndex <= 4) {
        navigationShell.goBranch(
          nextIndex,
          initialLocation: false,
        );
      }
      return;
    }

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

        if (navigator.canPop()) {
          navigator.pop();
          return;
        }

        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0, initialLocation: false);
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: _handleSwipe,
          child: navigationShell,
        ),
        bottomNavigationBar: EsnafBottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: _onTabTapped,
        ),
      ),
    );
  }
}