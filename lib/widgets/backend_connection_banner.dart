import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/backend_login_status.dart';
import '../providers/auth_provider.dart';

/// Bannière persistante si connexion partielle (ex. 2/3 serveurs).
class BackendConnectionBanner extends StatelessWidget {
  const BackendConnectionBanner({super.key});

  static void showFailureDetails(BuildContext context, BackendLoginStatus status) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Serveurs non connectés'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: status.failureDetails
                .map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(line, style: const TextStyle(fontSize: 13, height: 1.4)),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  static void showLoginSnackBar(BuildContext context, BackendLoginStatus status) {
    if (status.summaryMessage.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(status.snackbarMessage),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        backgroundColor: status.isPartial ? const Color(0xFFB45309) : const Color(0xFF16A34A),
        action: status.isPartial
            ? SnackBarAction(
                label: 'Détails',
                textColor: Colors.white,
                onPressed: () => showFailureDetails(context, status),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().backendLoginStatus;
    if (status == null || !status.isPartial) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.summaryMessage,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Certaines commandes peuvent manquer. Vérifiez identifiants ou URL.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: const Color(0xFF92400E).withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => showFailureDetails(context, status),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Détails', style: TextStyle(fontSize: 11)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: const Color(0xFF92400E),
            onPressed: () => context.read<AuthProvider>().clearBackendLoginStatus(),
          ),
        ],
      ),
    );
  }
}
