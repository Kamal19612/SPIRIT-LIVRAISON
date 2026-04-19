import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/admin_provider.dart';

class AdminDriversScreen extends StatelessWidget {
  const AdminDriversScreen({super.key});

  void _showAddDriverDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _AddDriverDialog());
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: admin.isLoading
          ? const Center(child: CircularProgressIndicator())
          : admin.drivers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delivery_dining,
                          size: 64, color: Color(0xFFD1D5DB)),
                      const SizedBox(height: 12),
                      const Text('Aucun livreur enregistré',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280))),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddDriverDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un livreur'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: admin.loadDrivers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: admin.drivers.length,
                    itemBuilder: (_, i) =>
                        _DriverTile(driver: admin.drivers[i]),
                  ),
                ),
      floatingActionButton: admin.drivers.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddDriverDialog(context),
              icon: const Icon(Icons.person_add),
              label: const Text('Nouveau livreur'),
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
    );
  }
}

class _DriverTile extends StatelessWidget {
  final UserModel driver;
  const _DriverTile({required this.driver});

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminProvider>();
    final hasLocation = driver.lat != null && driver.lng != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: driver.active
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                : const Color(0xFFF3F4F6),
            child: Text(
              driver.username.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: driver.active
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.username,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827)),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      hasLocation ? Icons.location_on : Icons.location_off,
                      size: 12,
                      color: hasLocation
                          ? const Color(0xFF10B981)
                          : const Color(0xFFD1D5DB),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasLocation
                          ? 'Pos: ${driver.lat!.toStringAsFixed(4)}, ${driver.lng!.toStringAsFixed(4)}'
                          : 'Position inconnue',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Toggle actif
          Column(
            children: [
              Switch(
                value: driver.active,
                onChanged: (val) => admin.toggleDriver(driver.id, val),
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
              Text(
                driver.active ? 'Actif' : 'Inactif',
                style: TextStyle(
                  fontSize: 10,
                  color: driver.active
                      ? const Color(0xFF10B981)
                      : const Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Dialog : Créer un livreur ───────────────────────────────────────────────

class _AddDriverDialog extends StatefulWidget {
  const _AddDriverDialog();

  @override
  State<_AddDriverDialog> createState() => _AddDriverDialogState();
}

class _AddDriverDialogState extends State<_AddDriverDialog> {
  final _formKey   = GlobalKey<FormState>();
  final _userCtrl  = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose(); _passCtrl.dispose(); _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSaving = true; _error = null; });
    try {
      await context.read<AdminProvider>().createDriver(
        _userCtrl.text.trim(),
        _passCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isSaving = false;
        _error = e.toString().contains('UNIQUE')
            ? 'Ce nom d\'utilisateur existe déjà'
            : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau livreur',
          style: TextStyle(fontWeight: FontWeight.w800)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: const TextStyle(
                        color: Color(0xFFDC2626), fontSize: 12)),
              ),
            TextFormField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                labelText: "Nom d'utilisateur",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure1,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure1
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure1 = !_obscure1),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 6) ? 'Min 6 caractères' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass2Ctrl,
              obscureText: _obscure2,
              decoration: InputDecoration(
                labelText: 'Confirmer le mot de passe',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure2
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure2 = !_obscure2),
                ),
              ),
              validator: (v) => v != _passCtrl.text ? 'Mots de passe différents' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 16, width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Créer',
                  style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
