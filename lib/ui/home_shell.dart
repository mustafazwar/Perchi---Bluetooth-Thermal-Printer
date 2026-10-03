import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/printer_service.dart';
import 'flow.dart';
import 'screens/create_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/printers_screen.dart';
import 'screens/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PrinterService>().startup());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: shellTab,
      builder: (context, i, _) => Scaffold(
        body: IndexedStack(index: i, children: const [
          HomeScreen(),
          CreateScreen(),
          HistoryScreen(),
          PrintersScreen(),
          SettingsScreen(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => shellTab.value = v,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.print_outlined), selectedIcon: Icon(Icons.print), label: 'Print'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Create'),
            NavigationDestination(icon: Icon(Icons.history), label: 'History'),
            NavigationDestination(icon: Icon(Icons.bluetooth), label: 'Printers'),
            NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}
