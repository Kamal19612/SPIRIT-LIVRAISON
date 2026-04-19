import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/external_source_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/app_config_provider.dart';
import '../../services/polling_service.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.palette_outlined), text: 'Application'),
                Tab(icon: Icon(Icons.cloud_outlined), text: 'Intégrations'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _AppConfigTab(),
                _IntegrationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Onglet configuration application ────────────────────────────────────────

class _AppConfigTab extends StatefulWidget {
  const _AppConfigTab();

  @override
  State<_AppConfigTab> createState() => _AppConfigTabState();
}

class _AppConfigTabState extends State<_AppConfigTab> {
  final _nameCtrl    = TextEditingController();
  final _logoCtrl    = TextEditingController();
  final _colorCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final config = context.read<AppConfigProvider>();
      _nameCtrl.text    = config.appName;
      _logoCtrl.text    = config.logoUrl;
      _colorCtrl.text   = config.primaryColorHex;
      _phoneCtrl.text   = config.contactPhone;
      _addressCtrl.text = config.contactAddress;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _logoCtrl.dispose(); _colorCtrl.dispose();
    _phoneCtrl.dispose(); _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await context.read<AppConfigProvider>().save(
        appName:         _nameCtrl.text.trim(),
        logoUrl:         _logoCtrl.text.trim(),
        primaryColorHex: _colorCtrl.text.trim(),
        contactPhone:    _phoneCtrl.text.trim(),
        contactAddress:  _addressCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration sauvegardée'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Color _previewColor() {
    try {
      final h = _colorCtrl.text.replaceFirst('#', '');
      if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    } catch (_) {}
    return const Color(0xFFF5AD41);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Aperçu logo ──────────────────────────────────────────────
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                  ),
                  child: ClipOval(
                    child: _logoCtrl.text.trim().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: _logoCtrl.text.trim(),
                            fit: BoxFit.cover,
                            errorWidget: (ctx, url, err) => const Icon(
                              Icons.local_shipping,
                              size: 50,
                              color: Color(0xFF9CA3AF),
                            ),
                          )
                        : const Icon(
                            Icons.local_shipping,
                            size: 50,
                            color: Color(0xFF9CA3AF),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _Section(
            title: 'Identité',
            children: [
              _SettingField(
                ctrl: _nameCtrl,
                label: "Nom de l'application",
                icon: Icons.label_outline,
              ),
              const SizedBox(height: 12),
              _SettingField(
                ctrl: _logoCtrl,
                label: 'URL du logo',
                icon: Icons.image_outlined,
                hint: 'https://exemple.com/logo.png',
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _Section(
            title: 'Apparence',
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SettingField(
                      ctrl: _colorCtrl,
                      label: 'Couleur principale (hex)',
                      icon: Icons.color_lens_outlined,
                      hint: '#F5AD41',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _previewColor(),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          _Section(
            title: 'Contact',
            children: [
              _SettingField(
                ctrl: _phoneCtrl,
                label: 'Téléphone',
                icon: Icons.phone_outlined,
                hint: '+224 6XX XXX XXX',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _SettingField(
                ctrl: _addressCtrl,
                label: 'Adresse',
                icon: Icons.location_on_outlined,
                hint: 'Kaloum, Conakry',
              ),
            ],
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    height: 16, width: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Sauvegarde...' : 'Sauvegarder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Onglet intégrations ──────────────────────────────────────────────────────

class _IntegrationsTab extends StatelessWidget {
  const _IntegrationsTab();

  void _showAddSourceDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _AddSourceDialog());
  }

  @override
  Widget build(BuildContext context) {
    final admin   = context.watch<AdminProvider>();
    final polling = context.watch<PollingService>();
    final sources = admin.sources;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: sources.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 56, color: Color(0xFFD1D5DB)),
                  const SizedBox(height: 12),
                  const Text(
                    'Aucune intégration configurée',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddSourceDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une source'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sources.length,
              itemBuilder: (_, i) => _SourceTile(
                source: sources[i],
                state: polling.stateFor(sources[i].id ?? -1),
              ),
            ),
      floatingActionButton: sources.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddSourceDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
    );
  }
}

// ── Tuile source avec statut sync ────────────────────────────────────────────

class _SourceTile extends StatelessWidget {
  final ExternalSource source;
  final SourceState    state;
  const _SourceTile({required this.source, required this.state});

  @override
  Widget build(BuildContext context) {
    final admin   = context.read<AdminProvider>();
    final polling = context.read<PollingService>();
    final isSyncing = state.status == SourceSyncStatus.syncing;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud, color: Color(0xFF3B82F6), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(source.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827))),
                    Text(
                      source.platformType == 'webhook' ? 'Webhook' : 'REST Polling',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              Switch(
                value: source.isActive,
                onChanged: (val) => admin.toggleSource(source.id!, val),
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),

          // ── Infos spécifiques au type ──
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 10),

          if (source.platformType == 'rest_polling') ...[
            // REST Polling — statut sync + bouton
            Row(
              children: [
                _SyncBadge(state: state),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (source.lastSyncAt.isNotEmpty)
                        Text('Sync: ${_formatDate(source.lastSyncAt)}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      if (source.syncedCount > 0)
                        Text('${source.syncedCount} commande(s) importée(s)',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      if (state.status == SourceSyncStatus.error && state.errorMessage != null)
                        Text(state.errorMessage!,
                            style: const TextStyle(fontSize: 10, color: Color(0xFFEF4444)),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (!isSyncing)
                  TextButton.icon(
                    onPressed: () => admin.pollSource(source, polling),
                    icon: const Icon(Icons.sync, size: 14),
                    label: const Text('Sync', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                else
                  const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ] else ...[
            // Webhook — statut réception + secret configuré
            Row(
              children: [
                // Badge connexion
                _webhookStatusBadge(source),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Secret HMAC
                      Row(children: [
                        Icon(
                          source.webhookSecret.isNotEmpty
                              ? Icons.lock_outline : Icons.lock_open,
                          size: 12,
                          color: source.webhookSecret.isNotEmpty
                              ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          source.webhookSecret.isNotEmpty
                              ? 'Secret HMAC configuré' : 'Secret non configuré',
                          style: TextStyle(
                            fontSize: 11,
                            color: source.webhookSecret.isNotEmpty
                                ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                          ),
                        ),
                      ]),
                      // Identifiant source
                      Text('Identifiant : ${source.sourceIdentifier}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      // Statistiques reçus
                      if (source.receivedCount > 0)
                        Text('${source.receivedCount} événement(s) reçu(s)',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      if (source.lastReceivedAt.isNotEmpty)
                        Text('Dernier : ${_formatDate(source.lastReceivedAt)}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
              ],
            ),
          ],

          // ── Action buttons ──
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showConfigSheet(context, source),
                icon: const Icon(Icons.tune, size: 14),
                label: const Text('Configurer', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFEF4444), size: 20),
                onPressed: () => admin.deleteSource(source.id!),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _webhookStatusBadge(ExternalSource source) {
    if (!source.isActive) {
      return _inlineBadge('Inactif', const Color(0xFF9CA3AF), const Color(0xFFF3F4F6));
    }
    if (source.receivedCount > 0) {
      return _inlineBadge('Actif', const Color(0xFF16A34A), const Color(0xFFF0FDF4));
    }
    return _inlineBadge('En écoute', const Color(0xFF3B82F6), const Color(0xFFEFF6FF));
  }

  Widget _inlineBadge(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  void _showConfigSheet(BuildContext context, ExternalSource source) {
    showModalBottomSheet(
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

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} '
          '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Sync status badge ────────────────────────────────────────────────────────

class _SyncBadge extends StatelessWidget {
  final SourceState state;
  const _SyncBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case SourceSyncStatus.syncing:
        return _badge('Sync...', const Color(0xFF3B82F6), const Color(0xFFEFF6FF));
      case SourceSyncStatus.ok:
        return _badge('OK', const Color(0xFF16A34A), const Color(0xFFF0FDF4));
      case SourceSyncStatus.error:
        return _badge('Erreur', const Color(0xFFEF4444), const Color(0xFFFEF2F2));
      case SourceSyncStatus.idle:
        return _badge('En attente', const Color(0xFF9CA3AF), const Color(0xFFF3F4F6));
    }
  }

  Widget _badge(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ── Feuille de configuration Webhook ────────────────────────────────────────

class _WebhookConfigSheet extends StatefulWidget {
  final ExternalSource source;
  const _WebhookConfigSheet({required this.source});

  @override
  State<_WebhookConfigSheet> createState() => _WebhookConfigSheetState();
}

class _WebhookConfigSheetState extends State<_WebhookConfigSheet> {
  late final TextEditingController _secretCtrl;
  late final TextEditingController _identifierCtrl;
  bool _isSaving = false;
  bool _secretVisible = false;

  @override
  void initState() {
    super.initState();
    _secretCtrl     = TextEditingController(text: widget.source.webhookSecret);
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
        'webhook_secret':    _secretCtrl.text.trim(),
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
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Configurer — ${widget.source.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),

            // ── Sécurité HMAC ──
            _SheetSection(title: 'Sécurité HMAC-SHA256', children: [
              TextFormField(
                controller: _secretCtrl,
                obscureText: !_secretVisible,
                decoration: InputDecoration(
                  labelText: 'Secret partagé',
                  hintText: 'clé secrète du serveur relais',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(_secretVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined, size: 18),
                    onPressed: () => setState(() => _secretVisible = !_secretVisible),
                  ),
                  helperText:
                      'Même valeur que WEBHOOK_SECRET dans le serveur relais',
                  helperMaxLines: 2,
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Identifiant source ──
            _SheetSection(title: 'Identification', children: [
              TextFormField(
                controller: _identifierCtrl,
                decoration: const InputDecoration(
                  labelText: 'Identifiant source',
                  hintText: 'shopify  /  woocommerce  /  mon-backend',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                  isDense: true,
                  helperText:
                      'Valeur du champ "source" dans les payloads envoyés par le relais',
                  helperMaxLines: 2,
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Architecture webhook ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(children: [
                    Icon(Icons.info_outline, size: 14, color: Color(0xFFB45309)),
                    SizedBox(width: 6),
                    Text('Comment ça fonctionne',
                        style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                  ]),
                  SizedBox(height: 6),
                  Text(
                    '1. Votre backend envoie un POST webhook au serveur relais\n'
                    '2. Le relais vérifie la signature HMAC avec le secret\n'
                    '3. Le relais envoie le payload à l\'app via push notification\n'
                    '4. L\'app traite l\'événement en temps réel',
                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Sauvegarder',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feuille de configuration REST Polling ────────────────────────────────────

class _RestPollingConfigSheet extends StatefulWidget {
  final ExternalSource source;
  const _RestPollingConfigSheet({required this.source});

  @override
  State<_RestPollingConfigSheet> createState() => _RestPollingConfigSheetState();
}

class _RestPollingConfigSheetState extends State<_RestPollingConfigSheet> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _responsePathCtrl;
  late String _authType;

  // Field mapping: canonical name → source field name
  final _mappingRows = <_MappingRow>[];
  bool _isSaving = false;

  static const _canonicalFields = [
    'orderNumber', 'customerName', 'customerPhone',
    'customerAddress', 'total', 'status', 'lat', 'lng',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _urlCtrl          = TextEditingController(text: s.url);
    _apiKeyCtrl       = TextEditingController(text: s.apiKey);
    _responsePathCtrl = TextEditingController(text: s.responsePath);
    _authType         = s.authType.isEmpty ? 'none' : s.authType;

    s.fieldMapping.forEach((canonical, sourceField) {
      _mappingRows.add(_MappingRow(
        canonicalCtrl: TextEditingController(text: canonical),
        sourceCtrl: TextEditingController(text: sourceField),
      ));
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose(); _apiKeyCtrl.dispose(); _responsePathCtrl.dispose();
    for (final r in _mappingRows) { r.canonicalCtrl.dispose(); r.sourceCtrl.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final mapping = <String, String>{};
      for (final row in _mappingRows) {
        final k = row.canonicalCtrl.text.trim();
        final v = row.sourceCtrl.text.trim();
        if (k.isNotEmpty && v.isNotEmpty) mapping[k] = v;
      }

      await context.read<AdminProvider>().updateSourceConfig(widget.source.id!, {
        'url':           _urlCtrl.text.trim(),
        'api_key':       _apiKeyCtrl.text.trim(),
        'auth_type':     _authType,
        'response_path': _responsePathCtrl.text.trim(),
        'field_mapping': jsonEncode(mapping),
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
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Configurer — ${widget.source.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),

            // ── Connexion ──
            _SheetSection(title: 'Connexion', children: [
              TextFormField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL de l\'API',
                  hintText: 'https://api.exemple.com/orders',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _authType,
                decoration: const InputDecoration(
                  labelText: 'Authentification',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'none',             child: Text('Aucune')),
                  DropdownMenuItem(value: 'bearer',           child: Text('Bearer Token')),
                  DropdownMenuItem(value: 'api_key_header',   child: Text('Clé API (header)')),
                  DropdownMenuItem(value: 'query_param',      child: Text('Clé API (query param)')),
                  DropdownMenuItem(value: 'basic',            child: Text('Basic Auth (base64)')),
                ],
                onChanged: (v) => setState(() => _authType = v!),
              ),
              if (_authType != 'none') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _apiKeyCtrl,
                  decoration: InputDecoration(
                    labelText: _authType == 'basic' ? 'user:password (base64)' : 'Clé / Token',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    isDense: true,
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 16),

            // ── Parsing ──
            _SheetSection(title: 'Parsing de la réponse', children: [
              TextFormField(
                controller: _responsePathCtrl,
                decoration: const InputDecoration(
                  labelText: 'Chemin vers la liste (dot notation)',
                  hintText: 'data.orders  ou  results',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_tree_outlined),
                  isDense: true,
                  helperText: 'Laisser vide si la réponse est directement un tableau',
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Mapping de champs ──
            _SheetSection(
              title: 'Correspondance des champs (optionnel)',
              children: [
                const Text(
                  'Définissez les noms de champs de votre API pour chaque champ canonique. '
                  'Laisser vide pour utiliser la détection automatique.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 12),
                ..._mappingRows.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MappingRowWidget(row: row, onDelete: () {
                    setState(() => _mappingRows.remove(row));
                  }),
                )),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _mappingRows.add(_MappingRow(
                        canonicalCtrl: TextEditingController(),
                        sourceCtrl: TextEditingController(),
                      ))),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter un champ'),
                    ),
                    const Spacer(),
                    Text('Champs: ${_canonicalFields.join(', ')}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Sauvegarder', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MappingRow {
  final TextEditingController canonicalCtrl;
  final TextEditingController sourceCtrl;
  _MappingRow({required this.canonicalCtrl, required this.sourceCtrl});
}

class _MappingRowWidget extends StatelessWidget {
  final _MappingRow row;
  final VoidCallback onDelete;
  const _MappingRowWidget({required this.row, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: row.canonicalCtrl,
            decoration: const InputDecoration(
              hintText: 'orderNumber',
              labelText: 'Champ canonique',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward, size: 16, color: Color(0xFF9CA3AF)),
        ),
        Expanded(
          child: TextFormField(
            controller: row.sourceCtrl,
            decoration: const InputDecoration(
              hintText: 'ref_cmd',
              labelText: 'Champ source',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
          onPressed: onDelete,
          padding: const EdgeInsets.only(left: 4),
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SheetSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.8,
            )),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

// ── Dialog : Ajouter une intégration ────────────────────────────────────────

class _AddSourceDialog extends StatefulWidget {
  const _AddSourceDialog();

  @override
  State<_AddSourceDialog> createState() => _AddSourceDialogState();
}

class _AddSourceDialogState extends State<_AddSourceDialog> {
  final _nameCtrl   = TextEditingController();
  final _urlCtrl    = TextEditingController();
  final _keyCtrl    = TextEditingController(); // API key (REST) ou webhook secret
  String _type      = 'rest_polling';
  bool   _isSaving  = false;
  bool   _keyVisible = false;

  bool get _isWebhook => _type == 'webhook';

  @override
  void dispose() {
    _nameCtrl.dispose(); _urlCtrl.dispose(); _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    final config = _isWebhook
        ? {
            'webhook_secret':    _keyCtrl.text.trim(),
            'source_identifier': _nameCtrl.text.trim().toLowerCase()
                .replaceAll(' ', '_'),
          }
        : {
            'url':       _urlCtrl.text.trim(),
            'api_key':   _keyCtrl.text.trim(),
            'auth_type': 'none',
          };
    await context.read<AdminProvider>().addExternalSource(
      name: _nameCtrl.text.trim(),
      platformType: _type,
      config: config,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle intégration',
          style: TextStyle(fontWeight: FontWeight.w800)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nom
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom de la plateforme',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 12),
            // Type
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'rest_polling',
                    child: Text('REST Polling — interrogation active')),
                DropdownMenuItem(value: 'webhook',
                    child: Text('Webhook — réception passive')),
              ],
              onChanged: (v) => setState(() { _type = v!; _keyCtrl.clear(); }),
            ),
            const SizedBox(height: 12),

            // Champs spécifiques au type
            if (!_isWebhook) ...[
              TextFormField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL de l\'API',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                  hintText: 'https://api.exemple.com/orders',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _keyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Clé API (optionnelle)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
              ),
            ] else ...[
              TextFormField(
                controller: _keyCtrl,
                obscureText: !_keyVisible,
                decoration: InputDecoration(
                  labelText: 'Secret HMAC (optionnel)',
                  hintText: 'configurez-le après si inconnu',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_keyVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined, size: 18),
                    onPressed: () => setState(() => _keyVisible = !_keyVisible),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Text(
                  'Le webhook est passif : votre serveur relais envoie les '
                  'événements à l\'app via push notification. '
                  'Configurez le secret HMAC après la création.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF166534)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
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
          child: const Text('Ajouter',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ── Widgets communs ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SettingField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final String? hint;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _SettingField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
