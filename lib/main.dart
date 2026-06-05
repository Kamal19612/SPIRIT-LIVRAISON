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
import 'services/fcm_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabase.instance.init();

  final authProvider = AuthProvider();
  final appConfigProvider = AppConfigProvider();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: appConfigProvider),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => LocationService()),
      ],
      child: const DeliveryApp(),
    ),
  );

  await NotificationService.instance.init();
  try {
    await FcmService.instance.init();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (_) {}

  await appConfigProvider.init();
  await authProvider.init();
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
      home: const _AppStartupGate(),
      routes: {
        '/login':     (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/admin':     (_) => const AdminShell(),
      },
    );
  }
}

/// Écran neutre pendant l’init (sans logo) ; puis login ou route sauvegardée.
class _AppStartupGate extends StatelessWidget {
  const _AppStartupGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (auth.isAuthenticated) {
      return auth.user!.isAdmin ? const AdminShell() : const DashboardScreen();
    }

    return const LoginScreen();
  }
}
