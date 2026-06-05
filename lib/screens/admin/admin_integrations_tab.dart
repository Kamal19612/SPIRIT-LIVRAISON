import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../database/app_config_dao.dart';
import '../../models/external_source_model.dart';
import '../../providers/admin_provider.dart';
import '../../services/app_config_service.dart';
import '../../services/backend_connection_service.dart';
import '../../services/external_source_secrets.dart';
import '../../services/polling_service.dart';
import '../../utils/url_normalize.dart';
import '../../widgets/admin_setting_field.dart';

/// Onglet Intégrations : guide simple + saisie manuelle (aucune URL imposée).
class AdminIntegrationsTab extends StatelessWidget {
  const AdminIntegrationsTab({super.key});

  void _showAddSourceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _AddSourceSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final polling = context.watch<PollingService>();
    final sources = admin.sources;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _GuideHeader(primary: primary),
          ),
          SliverToBoxAdapter(
            child: _BackendSetupCard(onAddShop: () => _showAddSourceSheet(context)),
          ),
          if (sources.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptySourcesState(
                primary: primary,
                onAdd: () => _showAddSourceSheet(context),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Sources de commandes (${sources.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _SourceTile(
                    source: sources[i],
                    state: polling.stateFor(sources[i].id ?? -1),
                  ),
                  childCount: sources.length,
                ),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: sources.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddSourceSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une source'),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 22, color: primary),
              const SizedBox(width: 8),
              Text(
                'Comment connecter votre système',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _step(
            '1',
            'Serveur principal',
            'URL de votre API (Spring, Node, Django, etc.). '
            'Les livreurs s’y connectent pour login, commandes et statuts. '
            'L’app teste `GET …/api/public/settings`. Laissez vide = mode local uniquement.',
          ),
          const SizedBox(height: 8),
          _step(
            '2',
            'Sources de commandes',
            'Une entrée par boutique ou canal. '
            'Webhook = votre serveur envoie les commandes (recommandé). '
            'REST = l’app interroge une URL de temps en temps.',
          ),
          const SizedBox(height: 8),
          _step(
            '3',
            'Aucune valeur par défaut',
            'Rien n’est prérempli : vous choisissez chaque URL et chaque identifiant '
            'selon votre propre backend.',
          ),
        ],
      ),
    );
  }

  Widget _step(String n, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: const Color(0xFFEFF6FF),
          child: Text(
            n,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: Color(0xFF4B5563),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BackendSetupCard extends StatefulWidget {
  const _BackendSetupCard({required this.onAddShop});

  final VoidCallback onAddShop;

  @override
  State<_BackendSetupCard> createState() => _BackendSetupCardState();
}

class _BackendSetupCardState extends State<_BackendSetupCard> {
  final _originCtrl = TextEditingController();
  final _platformCtrl = TextEditingController();

  bool _loaded = false;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _testMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    AppConfigDao.instance.getValue(AppConfig.storeApiOriginConfigKey).then((v) {
      if (mounted) setState(() => _originCtrl.text = v ?? '');
    });
    AppConfigDao.instance.getValue('store_source_platform').then((v) {
      if (mounted) setState(() => _platformCtrl.text = v ?? '');
    });
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _platformCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final raw = _originCtrl.text.trim();
      var storeOrigin = '';
      if (raw.isNotEmpty) {
        final normalized = normalizeBackendOrigin(raw);
        if (normalized == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('URL invalide (http:// ou https://, sans /api à la fin).'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        storeOrigin = normalized;
      }
      await AppConfigService.instance.save({
        AppConfig.storeApiOriginConfigKey: storeOrigin,
        'store_source_platform': _platformCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            storeOrigin.isEmpty
                ? 'Mode local activé. Les livreurs n’utilisent plus l’API distante.'
                : 'Serveur enregistré. Demandez aux livreurs de se reconnecter.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _testConnection() async {
    if (_isTesting) return;
    setState(() {
      _isTesting = true;
      _testMessage = null;
    });
    try {
      final msg = await BackendConnectionService.instance.testOrigin(_originCtrl.text.trim());
      if (mounted) setState(() => _testMessage = msg);
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Serveur principal',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ex. `https://api.mon-domaine.com` ou `http://192.168.0.12:8080` '
              '(sans le suffixe /api).',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280), height: 1.35),
            ),
            const SizedBox(height: 12),
            AdminSettingField(
              ctrl: _originCtrl,
              label: 'URL du serveur',
              icon: Icons.dns_outlined,
              hint: 'https://…',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            AdminSettingField(
              ctrl: _platformCtrl,
              label: 'Code boutique (optionnel)',
              icon: Icons.tag_outlined,
              hint: 'si votre API filtre par plateforme',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_isSaving ? 'Enregistrement…' : 'Enregistrer'),
                ),
                OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check, size: 18),
                  label: Text(_isTesting ? 'Test…' : 'Tester'),
                ),
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () => setState(() {
                            _originCtrl.clear();
                            _testMessage = null;
                          }),
                  child: const Text('Effacer'),
                ),
              ],
            ),
            if (_testMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _testMessage!,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _testMessage!.startsWith('Connexion OK')
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.onAddShop,
              icon: const Icon(Icons.add_link),
              label: const Text('Ajouter une source de commandes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySourcesState extends StatelessWidget {
  const _EmptySourcesState({required this.primary, required this.onAdd});

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
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Aucune source pour l’instant',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajoutez un webhook ou une API REST quand vous êtes prêt.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une source'),
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

// ── Liste des sources, feuilles de config (inchangées fonctionnellement) ─────

class _SourceTile extends StatelessWidget {
  final ExternalSource source;
  final SourceState state;

  const _SourceTile({required this.source, required this.state});

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminProvider>();
    final polling = context.read<PollingService>();
    final isSyncing = state.status == SourceSyncStatus.syncing;
    final isWebhook = source.platformType == 'webhook';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWebhook ? Icons.webhook : Icons.sync,
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      isWebhook ? 'Webhook' : 'Synchronisation REST',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              Switch(
                value: source.isActive,
                onChanged: (v) => admin.toggleSource(source.id!, v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isWebhook) ...[
            Row(
              children: [
                _SyncBadge(state: state),
                const Spacer(),
                if (!isSyncing)
                  TextButton.icon(
                    onPressed: () => admin.pollSource(source, polling),
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Synchroniser'),
                  )
                else
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ] else
            Text(
              'Identifiant : ${source.sourceIdentifier}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openConfig(context, source),
              icon: const Icon(Icons.tune, size: 16),
              label: Text(isWebhook ? 'Secret & identifiant' : 'Options avancées'),
            ),
          ),
        ],
      ),
    );
  }

  void _openConfig(BuildContext context, ExternalSource source) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => source.platformType == 'webhook'
          ? _WebhookConfigSheet(source: source)
          : _RestPollingConfigSheet(source: source),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.state});

  final SourceState state;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (state.status) {
      SourceSyncStatus.syncing => ('En cours', const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
      SourceSyncStatus.ok => ('OK', const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
      SourceSyncStatus.error => ('Erreur', const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
      SourceSyncStatus.idle => ('En attente', const Color(0xFF9CA3AF), const Color(0xFFF3F4F6)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _AddSourceSheet extends StatefulWidget {
  const _AddSourceSheet();

  @override
  State<_AddSourceSheet> createState() => _AddSourceSheetState();
}

class _AddSourceSheetState extends State<_AddSourceSheet> {
  final _nameCtrl = TextEditingController();
  final _sourceIdCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  String _type = 'webhook';
  bool _isSaving = false;

  bool get _isWebhook => _type == 'webhook';

  String _defaultId() =>
      _nameCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sourceIdCtrl.dispose();
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final sourceId = _sourceIdCtrl.text.trim().isEmpty
          ? _defaultId()
          : _sourceIdCtrl.text.trim();
      final config = _isWebhook
          ? {
              'webhook_secret': _keyCtrl.text.trim(),
              'source_identifier': sourceId,
            }
          : {
              'url': _urlCtrl.text.trim(),
              'auth_type': 'none',
              'api_key': '',
              'id_field': 'id',
              'since_param': '',
              'page_param': '',
              'limit_param': '',
              'page_size': 50,
            };
      final newId = await context.read<AdminProvider>().addExternalSource(
            name: _nameCtrl.text.trim(),
            platformType: _type,
            config: config,
          );
      if (!_isWebhook && _keyCtrl.text.trim().isNotEmpty) {
        await ExternalSourceSecrets.instance.setApiKey(newId, _keyCtrl.text.trim());
      }
      if (mounted) Navigator.pop(context);
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
          const Text('Nouvelle source', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Donnez un nom lisible. Le type indique comment les commandes arrivent dans l’app.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.35),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nom',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_type),
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(
                value: 'webhook',
                child: Text('Webhook — votre serveur pousse les commandes'),
              ),
              DropdownMenuItem(
                value: 'rest_polling',
                child: Text('REST — l’app récupère les commandes périodiquement'),
              ),
            ],
            onChanged: _isSaving ? null : (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 12),
          if (_isWebhook) ...[
            TextField(
              controller: _sourceIdCtrl,
              decoration: InputDecoration(
                labelText: 'Identifiant technique (champ « source » JSON)',
                hintText: _defaultId().isEmpty ? 'ex. ma_boutique' : 'défaut : ${_defaultId()}',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyCtrl,
              decoration: const InputDecoration(
                labelText: 'Secret HMAC (optionnel)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ] else ...[
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL de l’API commandes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyCtrl,
              decoration: const InputDecoration(
                labelText: 'Clé API (optionnelle)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Annuler')),
              const Spacer(),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Ajouter'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WebhookConfigSheet extends StatefulWidget {
  const _WebhookConfigSheet({required this.source});

  final ExternalSource source;

  @override
  State<_WebhookConfigSheet> createState() => _WebhookConfigSheetState();
}

class _WebhookConfigSheetState extends State<_WebhookConfigSheet> {
  late final TextEditingController _secretCtrl;
  late final TextEditingController _identifierCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _secretCtrl = TextEditingController(text: widget.source.webhookSecret);
    _identifierCtrl = TextEditingController(text: widget.source.sourceIdentifier);
  }

  @override
  void dispose() {
    _secretCtrl.dispose();
    _identifierCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await context.read<AdminProvider>().updateSourceConfig(widget.source.id!, {
        'webhook_secret': _secretCtrl.text.trim(),
        'source_identifier': _identifierCtrl.text.trim().isEmpty
            ? widget.source.name
            : _identifierCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.source.name} — webhook',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Votre backend envoie un POST signé (HMAC). Le secret ci-dessous doit être le même '
              'que celui utilisé pour calculer la signature (ex. en-tête X-Webhook-Signature).',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _secretCtrl,
              decoration: const InputDecoration(
                labelText: 'Secret partagé',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _identifierCtrl,
              decoration: const InputDecoration(
                labelText: 'Identifiant « source »',
                border: OutlineInputBorder(),
                helperText: 'Valeur du champ source dans le JSON reçu',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestPollingConfigSheet extends StatefulWidget {
  const _RestPollingConfigSheet({required this.source});

  final ExternalSource source;

  @override
  State<_RestPollingConfigSheet> createState() => _RestPollingConfigSheetState();
}

class _RestPollingConfigSheetState extends State<_RestPollingConfigSheet> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _responsePathCtrl;
  late String _authType;
  late final TextEditingController _idFieldCtrl;
  bool _showAdvanced = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _urlCtrl = TextEditingController(text: s.url);
    _apiKeyCtrl = TextEditingController();
    _responsePathCtrl = TextEditingController(text: s.responsePath);
    _authType = s.authType.isEmpty ? 'none' : s.authType;
    _idFieldCtrl = TextEditingController(text: s.idFieldPath);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _responsePathCtrl.dispose();
    _idFieldCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      if (_idFieldCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indiquez au minimum le champ ID (ex. id).')),
        );
        return;
      }
      if (widget.source.id != null && _apiKeyCtrl.text.trim().isNotEmpty) {
        await ExternalSourceSecrets.instance.setApiKey(widget.source.id!, _apiKeyCtrl.text.trim());
      }
      if (!mounted) return;
      await context.read<AdminProvider>().updateSourceConfig(widget.source.id!, {
        'url': _urlCtrl.text.trim(),
        'auth_type': _authType,
        'response_path': _responsePathCtrl.text.trim(),
        'id_field': _idFieldCtrl.text.trim(),
        'api_key': '',
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.source.name} — REST',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL de l’API',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _idFieldCtrl,
              decoration: const InputDecoration(
                labelText: 'Champ ID dans la réponse',
                hintText: 'id',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Options avancées', style: TextStyle(fontSize: 13)),
              value: _showAdvanced,
              onChanged: (v) => setState(() => _showAdvanced = v),
            ),
            if (_showAdvanced) ...[
              DropdownButtonFormField<String>(
                key: ValueKey(_authType),
                initialValue: _authType,
                decoration: const InputDecoration(labelText: 'Authentification', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('Aucune')),
                  DropdownMenuItem(value: 'bearer', child: Text('Bearer')),
                  DropdownMenuItem(value: 'api_key_header', child: Text('Clé dans un header')),
                  DropdownMenuItem(value: 'query_param', child: Text('Clé en query')),
                  DropdownMenuItem(value: 'basic', child: Text('Basic')),
                ],
                onChanged: (v) => setState(() => _authType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Clé / token (laisser vide = inchangé)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _responsePathCtrl,
                decoration: const InputDecoration(
                  labelText: 'Chemin vers la liste (ex. data.orders)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
