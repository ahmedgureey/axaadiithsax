import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/widgets.dart';

/// Persistent shell for the five main tabs.
///
/// * Each tab keeps its own navigation stack and scroll state
///   (`StatefulShellRoute.indexedStack`).
/// * Re-selecting the current tab returns it to its root instead of pushing
///   a duplicate entry.
/// * Android back: pops inside the current tab first; at a tab root other than
///   Home it switches to Home; on Home root it leaves the app.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTabSelected(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final isHome = navigationShell.currentIndex == 0;
    return PopScope(
      canPop: isHome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigationShell.goBranch(0);
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: navigationShell.currentIndex,
          onDestinationSelected: _onTabSelected,
        ),
      ),
    );
  }
}
