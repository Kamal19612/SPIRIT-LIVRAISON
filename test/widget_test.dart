import 'package:appstore/database/local_database.dart';
import 'package:appstore/main.dart';
import 'package:appstore/providers/admin_provider.dart';
import 'package:appstore/providers/app_config_provider.dart';
import 'package:appstore/providers/auth_provider.dart';
import 'package:appstore/providers/orders_provider.dart';
import 'package:appstore/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalDatabase.instance.init();
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => AppConfigProvider()),
          ChangeNotifierProvider(create: (_) => OrdersProvider()),
          ChangeNotifierProvider(create: (_) => AdminProvider()),
          ChangeNotifierProvider(create: (_) => LocationService()),
        ],
        child: const DeliveryApp(),
      ),
    );
    expect(find.byType(DeliveryApp), findsOneWidget);
  });
}
