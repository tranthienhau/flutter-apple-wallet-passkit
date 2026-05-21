import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  static const _tabs = <_NavItem>[
    _NavItem(path: '/wallet', icon: Icons.account_balance_wallet, label: 'Wallet'),
    _NavItem(path: '/transactions', icon: Icons.swap_horiz, label: 'Transactions'),
    _NavItem(path: '/settings', icon: Icons.settings, label: 'Settings'),
  ];

  int _indexFromLocation(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexFromLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
        onDestinationSelected: (i) => context.go(_tabs[i].path),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.path, required this.icon, required this.label});
  final String path;
  final IconData icon;
  final String label;
}
