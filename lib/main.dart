import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/navigation.dart';
import 'database/local_database.dart';
import 'providers/admin_provider.dart';
import 'providers/app_config_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/orders_provider.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/polling_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalDatabase.instance.init();
  await NotificationService.instance.init();

  final authProvider = AuthProvider();
  await authProvider.init();

  final appConfigProvider = AppConfigProvider();
  await appConfigProvider.init();

  final pollingService = PollingService()..start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: appConfigProvider),
        ChangeNotifierProvider.value(value: pollingService),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => LocationService()),
      ],
      child: const DeliveryApp(),
    ),
  );
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>();

    return MaterialApp(
      title: config.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: config.primaryColor),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login':     (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/admin':     (_) => const AdminShell(),
      },
    );
  }
}
