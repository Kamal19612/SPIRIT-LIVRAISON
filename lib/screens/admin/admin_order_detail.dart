import 'package:flutter/material.dart';

import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../widgets/order_detail_sheet.dart';

/// Ouvre la fiche détail d'une commande (charge le détail API si besoin).
Future<void> showAdminOrderDetail(BuildContext context, Order order) async {
  var loadingShown = false;
  try {
    if (context.mounted) {
      loadingShown = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
        ),
      );
    }

    final detail = await OrderService.instance.fetchAdminOrderDetail(order);
    if (!context.mounted) return;
    if (loadingShown) {
      Navigator.of(context, rootNavigator: true).pop();
      loadingShown = false;
    }
    await showOrderDetailSheet(context, detail, mode: 'admin');
  } catch (_) {
    if (context.mounted && loadingShown) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (!context.mounted) return;
    await showOrderDetailSheet(context, order, mode: 'admin');
  }
}
