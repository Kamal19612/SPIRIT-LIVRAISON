import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/backend_server_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/app_config_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/fcm_service.dart';
import '../../services/store_sse_service.dart';
import '../../widgets/backend_connection_banner.dart';
import 'admin_dashboard_screen.dart';
import 'admin_drivers_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_settings_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _appInForeground = true;

  static const _screens = [
    AdminDashboardScreen(),
    AdminOrdersScreen(),
    AdminDriversScreen(),
    AdminSettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed && !_appInForeground) {
      _appInForeground = true;
      unawaited(_syncAll());
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _appInForeground = false;
    }
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final admin = context.read<AdminProvider>();
    await admin.loadAll();
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    if (auth.user?.isAdmin != true) return;

    FcmService.instance.listenForeground(onEvent: _onFcmEvent);

    await StoreSseService.instance.start(
      stream: StoreSseStream.admin,
      onEvent: _onSseEvent,
    );
  }

  /// FCM : serveur d’origine inconnu → resync tous les backends connectés.
  void _onFcmEvent(String type, Map<String, dynamic> data) {
    if (!mounted) return;
    final admin = context.read<AdminProvider>();
    switch (type) {
      case 'new_order':
      case 'order_status':
      case 'new_delivery':
        unawaited(admin.syncFromDatabase(orders: true));
        break;
      case 'staff_changed':
        unawaited(admin.syncFromDatabase(drivers: true));
        break;
      default:
        break;
    }
  }

  void _onSseEvent(
    BackendServer backend,
    String type,
    Map<String, dynamic> data,
  ) {
    if (!mounted) return;
    final backendId = backend.id;
    if (backendId == null) return;

    final admin = context.read<AdminProvider>();
    switch (type) {
      case 'new_order':
      case 'order_status':
      case 'new_delivery':
        unawaited(admin.syncFromDatabase(orders: true, backendId: backendId));
        break;
      case 'staff_changed':
        unawaited(admin.syncFromDatabase(drivers: true, backendId: backendId));
        break;
      default:
        break;
    }
  }

  Future<void> _syncAll() async {
    if (!mounted) return;
    await context.read<AdminProvider>().syncFromDatabase(orders: true, drivers: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(StoreSseService.instance.stop(stream: StoreSseStream.admin));
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await StoreSseService.instance.stop(stream: StoreSseStream.admin);
    if (!mounted) return;
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
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: BackendConnectionBanner(),
          ),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
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
