import 'package:flutter/material.dart';

class NetworkBanner extends StatelessWidget {
  final bool isOnline;

  const NetworkBanner({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    if (isOnline) return const SizedBox.shrink();

    return Container(
      color: const Color(0xFFF59E0B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Text('📡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hors-ligne',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF1C1917),
                ),
              ),
              Text(
                'Vos actions seront synchronisées à la reconnexion',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF44403C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
