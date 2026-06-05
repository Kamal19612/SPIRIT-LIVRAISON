import 'package:flutter/material.dart';

import '../../database/backends_dao.dart';
import '../../models/backend_server_model.dart';
import '../../utils/url_normalize.dart';
import '../../widgets/admin_setting_field.dart';
import '../../widgets/backend_test_sheet.dart';

/// Backends Spring (STORE-ALL, etc.) — une entrée par serveur.
class AdminIntegrationsTab extends StatefulWidget {
  const AdminIntegrationsTab({super.key});

  @override
  State<AdminIntegrationsTab> createState() => _AdminIntegrationsTabState();
}

class _AdminIntegrationsTabState extends State<AdminIntegrationsTab> {
  List<BackendServer> _backends = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final list = await BackendsDao.instance.getAll();
    if (mounted) {
      setState(() {
        _backends = list;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({BackendServer? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _BackendEditorSheet(existing: existing),
      ),
    );
    if (saved == true) await _reload();
  }

  Future<void> _toggleActive(BackendServer backend) async {
    if (backend.id == null) return;
    await BackendsDao.instance.setActive(backend.id!, !backend.isActive);
    await _reload();
  }

  Future<void> _delete(BackendServer backend) async {
    if (backend.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce serveur ?'),
        content: Text('« ${backend.name} » sera retiré de la configuration.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    await BackendsDao.instance.delete(backend.id!);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _GuideHeader(primary: primary)),
          if (_backends.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(primary: primary, onAdd: () => _openEditor()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _BackendTile(
                    backend: _backends[i],
                    onEdit: () => _openEditor(existing: _backends[i]),
                    onToggle: () => _toggleActive(_backends[i]),
                    onDelete: () => _delete(_backends[i]),
                  ),
                  childCount: _backends.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un serveur'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _GuideHeader extends StatelessWidget {
  const _GuideHeader({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.hub_outlined, size: 22, color: primary),
              const SizedBox(width: 8),
              Text(
                'Serveurs backend',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Ajoutez un serveur par boutique ou instance STORE-ALL. '
            'À la connexion, l’app s’authentifie sur chaque serveur actif '
            'et fusionne les commandes livraison dans un seul tableau de bord.',
            style: TextStyle(fontSize: 12, height: 1.45, color: primary.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 8),
          Text(
            '1. URL sans /api (ex. http://192.168.0.12:8085)\n'
            '2. Testez : API publique + login JWT optionnel + commandes livraison\n'
            '3. Le livreur se connecte avec son compte sur chaque serveur actif',
            style: const TextStyle(fontSize: 11.5, height: 1.5, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.primary, required this.onAdd});

  final Color primary;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dns_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Aucun serveur configuré',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mode local uniquement tant qu’aucun backend n’est ajouté.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un serveur'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackendTile extends StatefulWidget {
  const _BackendTile({
    required this.backend,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final BackendServer backend;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  State<_BackendTile> createState() => _BackendTileState();
}

class _BackendTileState extends State<_BackendTile> {
  @override
  Widget build(BuildContext context) {
    final b = widget.backend;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                b.isActive ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                color: b.isActive ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      b.origin,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                    ),
                    if (b.storeCode.isNotEmpty)
                      Text(
                        'Code boutique : ${b.storeCode}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      ),
                  ],
                ),
              ),
              Switch(value: b.isActive, onChanged: (_) => widget.onToggle()),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                onPressed: () => BackendTestSheet.show(context, backend: widget.backend),
                icon: const Icon(Icons.network_check, size: 16),
                label: const Text('Tester'),
              ),
              TextButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Modifier'),
              ),
              TextButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                label: const Text('Supprimer', style: TextStyle(color: Color(0xFFDC2626))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackendEditorSheet extends StatefulWidget {
  const _BackendEditorSheet({this.existing});

  final BackendServer? existing;

  @override
  State<_BackendEditorSheet> createState() => _BackendEditorSheetState();
}

class _BackendEditorSheetState extends State<_BackendEditorSheet> {
  final _nameCtrl = TextEditingController();
  final _originCtrl = TextEditingController();
  final _storeCodeCtrl = TextEditingController();
  bool _isSaving = false;

  bool get _isEdit => widget.existing?.id != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _originCtrl.text = e.origin;
      _storeCodeCtrl.text = e.storeCode;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _originCtrl.dispose();
    _storeCodeCtrl.dispose();
    super.dispose();
  }

  void _openTestSheet() {
    final origin = _originCtrl.text.trim();
    if (origin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez d’abord l’URL du serveur.')),
      );
      return;
    }
    BackendTestSheet.showForOrigin(
      context,
      origin: origin,
      storeCode: _storeCodeCtrl.text.trim(),
      label: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final origin = _originCtrl.text.trim();
    if (name.isEmpty || origin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom et URL sont obligatoires.')),
      );
      return;
    }
    if (normalizeBackendOrigin(origin) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL invalide (http:// ou https://, sans /api).')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEdit) {
        await BackendsDao.instance.update(
          id: widget.existing!.id!,
          name: name,
          origin: origin,
          storeCode: _storeCodeCtrl.text.trim(),
        );
      } else {
        await BackendsDao.instance.insert(
          name: name,
          origin: origin,
          storeCode: _storeCodeCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('ArgumentError: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEdit ? 'Modifier le serveur' : 'Nouveau serveur',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          AdminSettingField(
            ctrl: _nameCtrl,
            label: 'Nom affiché',
            icon: Icons.label_outline,
            hint: 'Boutique Centre, STORE-ALL Prod…',
          ),
          const SizedBox(height: 10),
          AdminSettingField(
            ctrl: _originCtrl,
            label: 'URL du serveur',
            icon: Icons.dns_outlined,
            hint: 'http://192.168.0.12:8085',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 10),
          AdminSettingField(
            ctrl: _storeCodeCtrl,
            label: 'Code boutique (optionnel)',
            icon: Icons.tag_outlined,
            hint: 'pour X-Store-Code sur les réglages publics',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _openTestSheet,
                icon: const Icon(Icons.network_check, size: 18),
                label: const Text('Tester'),
              ),
              const Spacer(),
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEdit ? 'Enregistrer' : 'Ajouter'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
