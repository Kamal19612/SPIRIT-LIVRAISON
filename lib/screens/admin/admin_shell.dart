import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/app_config_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/polling_service.dart';
import 'admin_dashboard_screen.dart';
import 'admin_drivers_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_settings_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  static const _screens = [
    AdminDashboardScreen(),
    AdminOrdersScreen(),
    AdminDriversScreen(),
    AdminSettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadAll();
      context.read<PollingService>().addListener(_onPollUpdate);
    });
  }

  @override
  void dispose() {
    context.read<PollingService>().removeListener(_onPollUpdate);
    super.dispose();
  }

  void _onPollUpdate() {
    final polling = context.read<PollingService>();
    final anyDone = polling.states.values.any(
      (s) => s.status == SourceSyncStatus.ok || s.status == SourceSyncStatus.error,
    );
    if (anyDone && mounted) {
      context.read<AdminProvider>().loadOrders();
    }
  }

  Future<void> _handleLogout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: config.primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          config.appName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: _handleLogout,
          ),
        ],
        elevation: 0,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor: Colors.white,
        elevation: 3,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Commandes',
          ),
          NavigationDestination(
            icon: Icon(Icons.delivery_dining_outlined),
            selectedIcon: Icon(Icons.delivery_dining),
            label: 'Livreurs',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}
