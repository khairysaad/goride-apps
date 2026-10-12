import 'package:flutter/material.dart';
import '../../providers/settings_provider.dart';
class HomeNavHost extends StatefulWidget {
  const HomeNavHost({
    super.key,
    required this.mapPage,
    required this.pages,
  });

  final Widget mapPage;
  final List<Widget> pages;

  @override
  State<HomeNavHost> createState() => _HomeNavHostState();
}

class _HomeNavHostState extends State<HomeNavHost> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [widget.mapPage, ...widget.pages];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: L10n.t('tab_home'),
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: L10n.t('tab_trips'),
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: L10n.t('my_account'),
          ),
        ],
      ),
    );
  }
}