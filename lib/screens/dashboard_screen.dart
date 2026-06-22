import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../services/auth_service.dart';
import '../services/connection_keep_alive_service.dart';
import '../services/delivery_alert_service.dart';
import '../services/delivery_sse_service.dart';
import '../services/fcm_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../widgets/backend_connection_banner.dart';
import '../widgets/delivery_history_tile.dart';
import '../widgets/order_card.dart';
import '../widgets/order_detail_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _selectedTab = 0;
  LocationService? _locationService;
  Timer? _pollTimer;
  bool _appInForeground = true;
  bool _localOnly = false;

  static const Color _gray50 = Color(0xFFF9FAFB);
  static const Color _gray100 = Color(0xFFF3F4F6);
  static const Color _gray200 = Color(0xFFE5E7EB);
  static const Color _gray500 = Color(0xFF6B7280);
  static const Color _gray900 = Color(0xFF111827);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
  }

  Future<void> _init() async {
    if (!mounted) return;
    final ordersProvider = context.read<OrdersProvider>();
    await ordersProvider.init();
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final locationService = context.read<LocationService>();
    if (auth.user != null) {
      _localOnly = await AuthService.instance.isLocalOnlySession();
      await NotificationService.instance.ensurePermission();
      FcmService.instance.listenForeground(onEvent: _onFcmEvent);

      ConnectionKeepAliveService.instance.setHeartbeatCallback(() async {
        if (!mounted) return;
        await ordersProvider.refresh(silent: true, alertOnNewOrders: true);
      });
      await ConnectionKeepAliveService.instance.syncWithSession();
      if (!mounted) return;

      unawaited(
        DeliverySseService.instance.start(onEvent: _onSseEvent),
      );

      _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        if (!mounted) return;
        if (!_localOnly && !_appInForeground) return;
        ordersProvider.refresh(silent: true, alertOnNewOrders: true);
      });

      _locationService = locationService;
      await _locationService!.startTracking(auth.user!.id);
      if (!mounted) return;
      _locationService!.addListener(_onLocationChanged);
    }
  }

  void _onFcmEvent(String type, Map<String, dynamic> data) {
    _handleRealtimeEvent(type, data);
  }

  void _onSseEvent(String event, Map<String, dynamic> data) {
    _handleRealtimeEvent(event, data);
  }

  void _handleRealtimeEvent(String type, Map<String, dynamic> data) {
    if (!mounted) return;

    if (DeliveryAlertService.isNewDeliveryEvent(type)) {
      final orderNumber = data['orderNumber']?.toString() ??
          data['order_number']?.toString() ??
          '';
      final deliveryType =
          data['deliveryType']?.toString() ?? data['delivery_type']?.toString();
      final label = _typeLabel(deliveryType);
      unawaited(DeliveryAlertService.instance.fromEventPayload(data));
      if (_appInForeground) {
        _showSnackbar(
          label.isEmpty
              ? '🚚 Nouvelle livraison #$orderNumber'
              : '🚚 Nouvelle livraison #$orderNumber · $label',
          isSuccess: true,
        );
      }
      context.read<OrdersProvider>().refresh(silent: true);
      return;
    }

    if (DeliveryAlertService.normalizeEventType(type) == 'order_status') {
      context.read<OrdersProvider>().refresh(silent: true);
    }
  }

  String _typeLabel(String? deliveryType) {
    final t = (deliveryType ?? '').toUpperCase();
    if (t == 'EXPRESS') return '⚡ Express';
    if (t == 'PROGRAMMER') return '🕐 Programmée';
    return '';
  }

  void _onLocationChanged() {
    if (!mounted) return;
    final loc = _locationService;
    if (loc != null) {
      context.read<OrdersProvider>().updateDriverLocation(loc.lat, loc.lng);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    unawaited(DeliverySseService.instance.stop());
    _locationService?.removeListener(_onLocationChanged);
    _locationService?.stopTracking();
    super.dispose();
  }

  void _onTabChanged(int index) {
    if (!mounted) return;
    setState(() => _selectedTab = index);
    final tab = switch (index) {
      0 => 'available',
      1 => 'my-orders',
      _ => 'history',
    };
    context.read<OrdersProvider>().loadOrders(tab);
  }

  Future<void> _handleLogout() async {
    final auth = context.read<AuthProvider>();
    _pollTimer?.cancel();
    await DeliverySseService.instance.stop();
    _locationService?.stopTracking();
    await auth.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _showSnackbar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess ? const Color(0xFF16A34A) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrdersProvider>();
    final auth = context.watch<AuthProvider>();
    final location = context.watch<LocationService>();
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: _gray50,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              const BackendConnectionBanner(),
              _buildHeader(auth, orders, location, primary),
              const SizedBox(height: 16),
              _buildTabSwitcher(orders),
              const SizedBox(height: 16),
              Expanded(child: _buildOrderList(orders, primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    AuthProvider auth,
    OrdersProvider orders,
    LocationService location,
    Color primary,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bonjour 👋',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _gray900,
                ),
              ),
              Text(
                'Prêt pour la route ?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _gray500.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: location.isTracking
                ? const Color(0xFFECFDF5)
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: location.isTracking
                  ? const Color(0xFFD1FAE5)
                  : _gray200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                location.isTracking
                    ? Icons.location_on
                    : Icons.location_off,
                size: 12,
                color: location.isTracking
                    ? const Color(0xFF10B981)
                    : _gray500,
              ),
              const SizedBox(width: 4),
              Text(
                location.isTracking ? 'GPS actif' : 'GPS inactif',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: location.isTracking
                      ? const Color(0xFF10B981)
                      : _gray500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _buildIconButton(
          icon: Icons.refresh,
          isActive: orders.isRefreshing,
          primary: primary,
          onTap: () => orders.refresh(),
        ),
        const SizedBox(width: 8),
        _buildIconButton(
          icon: Icons.logout,
          isActive: false,
          primary: primary,
          onTap: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required bool isActive,
    required Color primary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: isActive ? primary : _gray200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 19,
          color: isActive ? primary : _gray500,
        ),
      ),
    );
  }

  Widget _buildTabSwitcher(OrdersProvider orders) {
    final counts = [
      orders.availableOrders.length,
      orders.myOrders.length,
      orders.deliveryHistory.length,
    ];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTab('Disponibles', 0, counts[0]),
          _buildTab('En cours', 1, counts[1]),
          _buildTab('Historique', 2, counts[2]),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index, int count) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabChanged(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF242021) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : _gray500,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : _gray100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isActive ? const Color(0xFF242021) : _gray500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderList(OrdersProvider orders, Color primary) {
    if (orders.isLoading) return _buildSkeleton();

    if (_selectedTab == 2) {
      final history = orders.deliveryHistory;
      if (history.isEmpty) return _buildEmptyState();
      return RefreshIndicator(
        onRefresh: () => orders.refresh(),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          itemCount: history.length,
          itemBuilder: (_, i) {
            final order = history[i];
            return DeliveryHistoryTile(
              order: order,
              onTap: () => showOrderDetailSheet(context, order, mode: 'history'),
            );
          },
        ),
      );
    }

    final list =
        _selectedTab == 0 ? orders.availableOrders : orders.myOrders;

    if (list.isEmpty) return _buildEmptyState();

    final mode = _selectedTab == 0 ? 'available' : 'my-orders';

    return RefreshIndicator(
      onRefresh: () => orders.refresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final order = list[i];
          return OrderCard(
            order: order,
            mode: mode,
            onClaim: (order) async {
              try {
                await context.read<OrdersProvider>().claimOrder(order);
                if (!mounted) return;
                setState(() => _selectedTab = 1);
                _showSnackbar('Commande prise en charge !', isSuccess: true);
              } catch (e) {
                final msg = e.toString().replaceFirst('Exception: ', '');
                if (mounted) _showSnackbar(msg);
              }
            },
            onComplete: (order, code) async {
              try {
                await context.read<OrdersProvider>().completeDelivery(order, code);
                if (mounted) {
                  _showSnackbar('Livraison validée ! 🎉', isSuccess: true);
                }
              } catch (e) {
                final msg = e.toString().replaceFirst('Exception: ', '');
                if (mounted) _showSnackbar(msg);
                rethrow;
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      children: List.generate(
        2,
        (_) => Container(
          height: 160,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _gray200.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isAvailable = _selectedTab == 0;
    final isHistory = _selectedTab == 2;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _gray50,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: _gray100, width: 2),
              ),
              child: Icon(
                isHistory
                    ? Icons.history
                    : isAvailable
                        ? Icons.local_shipping_outlined
                        : Icons.check_circle_outline,
                size: 48,
                color: const Color(0xFFE5E7EB),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isHistory
                  ? 'Aucune livraison terminée'
                  : isAvailable
                      ? 'Aucune commande'
                      : 'Vous êtes libre !',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _gray900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isHistory
                  ? 'Vos courses livrées apparaîtront ici.'
                  : isAvailable
                      ? 'Revenez plus tard pour de nouvelles courses.'
                      : "Prenez une commande dans l'onglet « Disponibles ».",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _gray500, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
