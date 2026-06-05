import 'package:flutter/material.dart';

import '../models/backend_connection_test_result.dart';
import '../models/backend_server_model.dart';
import '../services/backend_connection_service.dart';
import '../utils/url_normalize.dart';
import 'admin_setting_field.dart';

/// Feuille de test : API publique + login JWT optionnel + `/api/delivery/orders`.
class BackendTestSheet extends StatefulWidget {
  const BackendTestSheet({
    super.key,
    required this.origin,
    this.storeCode = '',
    this.label,
  });

  final String origin;
  final String storeCode;
  final String? label;

  static Future<void> show(
    BuildContext context, {
    required BackendServer backend,
  }) {
    return showForOrigin(
      context,
      origin: backend.origin,
      storeCode: backend.storeCode,
      label: backend.name,
    );
  }

  static Future<void> showForOrigin(
    BuildContext context, {
    required String origin,
    String storeCode = '',
    String? label,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: BackendTestSheet(
          origin: origin,
          storeCode: storeCode,
          label: label,
        ),
      ),
    );
  }

  @override
  State<BackendTestSheet> createState() => _BackendTestSheetState();
}

class _BackendTestSheetState extends State<BackendTestSheet> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _testing = false;
  BackendConnectionTestResult? _result;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _runTest() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    final result = await BackendConnectionService.instance.testFull(
      rawOrigin: widget.origin,
      storeCode: widget.storeCode,
      label: widget.label,
      username: _userCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (mounted) {
      setState(() {
        _testing = false;
        _result = result;
      });
    }
  }

  Color _headlineColor(BackendConnectionTestResult r) {
    if (!r.publicOk) return const Color(0xFFDC2626);
    if (r.isPartial) return const Color(0xFFB45309);
    return const Color(0xFF16A34A);
  }

  @override
  Widget build(BuildContext context) {
    final origin = normalizeBackendOrigin(widget.origin) ?? widget.origin;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tester la connexion',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              origin,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Étape 1 : API publique (réseau).\n'
              'Étape 2–3 : login JWT + commandes livraison (si identifiants fournis).',
              style: TextStyle(fontSize: 11.5, height: 1.45, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 14),
            AdminSettingField(
              ctrl: _userCtrl,
              label: 'Identifiant test (optionnel)',
              icon: Icons.person_outline,
              hint: 'compte livreur ou manager',
            ),
            const SizedBox(height: 10),
            AdminSettingField(
              ctrl: _passCtrl,
              label: 'Mot de passe test (optionnel)',
              icon: Icons.lock_outline,
              hint: 'pour valider JWT + API livraison',
              obscure: _obscure,
              suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _result!.headline,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _headlineColor(_result!),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._result!.steps.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          _formatStep(s),
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: s.skipped
                                ? const Color(0xFF6B7280)
                                : (s.ok ? const Color(0xFF166534) : const Color(0xFFDC2626)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _testing ? null : _runTest,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_outlined, size: 18),
                  label: Text(_testing ? 'Test en cours…' : 'Lancer le test'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _testing ? null : () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatStep(BackendTestStep s) {
    if (s.skipped) return '• ${s.label} : — ${s.detail}';
    final status = s.ok ? 'OK' : 'Échec';
    return '• ${s.label} : $status — ${s.detail}';
  }
}
