import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/external_source_model.dart';
import '../../database/app_config_dao.dart';
import '../../providers/admin_provider.dart';
import '../../providers/app_config_provider.dart';
import '../../services/app_config_service.dart';
import '../../services/polling_service.dart';
import '../../services/external_source_secrets.dart';
import '../../utils/url_normalize.dart';

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
  final _nameCtrl     = TextEditingController();
  final _logoCtrl     = TextEditingController();
  final _colorCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final config = context.read<AppConfigProvider>();
      _nameCtrl.text      = config.appName;
      _logoCtrl.text      = config.logoUrl;
      _colorCtrl.text     = config.primaryColorHex;
      _phoneCtrl.text     = config.contactPhone;
      _emailCtrl.text     = config.contactEmail;
      _whatsappCtrl.text = config.supportWhatsapp;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _logoCtrl.dispose();
    _colorCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await context.read<AppConfigProvider>().save(
        appName:           _nameCtrl.text.trim(),
        logoUrl:           _logoCtrl.text.trim(),
        primaryColorHex:   _colorCtrl.text.trim(),
        contactPhone:      _phoneCtrl.text.trim(),
        contactEmail:      _emailCtrl.text.trim(),
        supportWhatsapp:   _whatsappCtrl.text.trim(),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Text(
              'Ces réglages définissent l’identité affichée aux livreurs et les coordonnées '
              'utiles pour l’administration (support, contact).',
              style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.35),
            ),
          ),
          const SizedBox(height: 16),

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
            title: 'Support & administration',
            children: [
              _SettingField(
                ctrl: _phoneCtrl,
                label: 'Téléphone support',
                icon: Icons.phone_outlined,
                hint: '+224 6XX XXX XXX',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _SettingField(
                ctrl: _emailCtrl,
                label: 'Email administrateur / support',
                icon: Icons.email_outlined,
                hint: 'support@exemple.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _SettingField(
                ctrl: _whatsappCtrl,
                label: 'WhatsApp support (optionnel)',
                icon: Icons.chat_outlined,
                hint: '+224 6XX XXX XXX',
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              'La connexion API boutique, Supabase Realtime et chaque boutique '
              '(webhook / polling) se configurent dans l’onglet Intégrations.',
              style: TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.35),
            ),
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

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

// ── Onglet intégrations ──────────────────────────────────────────────────────

class _IntegrationsTab extends StatelessWidget {
  const _IntegrationsTab();

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
    final admin   = context.watch<AdminProvider>();
    final polling = context.watch<PollingService>();
    final sources = admin.sources;
    final primary = Theme.of(context).colorScheme.primary;

    Widget introCard() => Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hub_outlined, size: 20, color: primary),
                    const SizedBox(width: 8),
                    Text(
                      'Intégrations & commandes',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Les commandes sont créées automatiquement à partir des sources externes. '
                  'Le mode recommandé est le webhook (votre boutique envoie chaque commande). '
                  'Le mode REST sert à interroger périodiquement une API si vous ne pouvez pas utiliser de webhook.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF1E40AF),
                  ),
                ),
              ],
            ),
          ),
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _ConnectionCard(onAddShop: () => _showAddSourceSheet(context)),
          ),
          SliverToBoxAdapter(child: introCard()),
          if (sources.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, size: 56, color: Color(0xFFD1D5DB)),
                      const SizedBox(height: 12),
                      const Text(
                        'Aucune intégration configurée',
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddSourceSheet(context),
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
              ),
            )
          else
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
      ),
      floatingActionButton: sources.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddSourceSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle intégration'),
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
    );
  }
}

class _ConnectionCard extends StatefulWidget {
  const _ConnectionCard({required this.onAddShop});

  final VoidCallback onAddShop;

  @override
  State<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<_ConnectionCard> {
  final _storeOriginCtrl = TextEditingController();
  final _storePlatformCtrl = TextEditingController();

  bool _loaded = false;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;

    AppConfigDao.instance.getValue('store_api_origin').then((v) {
      if (mounted) setState(() => _storeOriginCtrl.text = v ?? '');
    });
    AppConfigDao.instance.getValue('store_source_platform').then((v) {
      if (mounted) setState(() => _storePlatformCtrl.text = v ?? '');
    });
  }

  @override
  void dispose() {
    _storeOriginCtrl.dispose();
    _storePlatformCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final storeOrigin = normalizeBackendOrigin(_storeOriginCtrl.text) ?? '';
      await AppConfigService.instance.save({
        'store_api_origin': storeOrigin,
        'store_source_platform': _storePlatformCtrl.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration sauvegardée.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    Widget sectionTitle(String n, String title) => Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  n,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.settings_ethernet, size: 20, color: primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Formulaire connexion',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(_isSaving ? '…' : 'Enregistrer'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Un même projet Spirit peut recevoir des commandes de plusieurs boutiques : '
              'une URL Supabase partagée, une API « boutique par défaut » pour la connexion livreur, '
              'et une fiche par boutique ci‑dessous (webhook ou API REST).',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280), height: 1.4),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            sectionTitle('1', 'Connexion & temps réel — Spring Boot'),
            const Text(
              'Les livreurs se connectent via l’API Spring Boot (JWT). '
              'Les notifications temps réel arrivent via FCM (recommandé) ou rafraîchissement manuel.',
              style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.35),
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 16),
            const Divider(height: 1),
            sectionTitle('2', 'API livreur — boutique par défaut'),
            const Text(
              'URL du backend boutique (sans /api) et identifiant sourcePlatform pour le JWT livreur. '
              'Pour une deuxième boutique avec une autre URL API, utilisez plutôt une source « REST Polling ».',
              style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.35),
            ),
            const SizedBox(height: 10),
            _SettingField(
              ctrl: _storeOriginCtrl,
              label: 'URL origine API boutique',
              icon: Icons.cloud_sync_outlined,
              hint: 'https://boutique.example.com',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            _SettingField(
              ctrl: _storePlatformCtrl,
              label: 'SourcePlatform (JWT / commandes API)',
              icon: Icons.hub_outlined,
              hint: 'ex. sucre_store — aligné sur le backend',
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            sectionTitle('3', 'Autres boutiques'),
            const Text(
              'Chaque boutique supplémentaire = une entrée dans la liste (webhook recommandé). '
              'L’identifiant « source » du payload doit correspondre à la source enregistrée ici.',
              style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.35),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.onAddShop,
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Ajouter une boutique (webhook ou REST)'),
            ),
          ],
        ),
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
                  hintText: 'clé secrète partagée (HMAC)',
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
                      'Identique au secret boutique (Sucre Store : app_settings '
                      'webhook_secret) et à votre endpoint qui vérifie '
                      'X-Webhook-Signature',
                  helperMaxLines: 3,
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
                      'Valeur du champ "source" dans les payloads envoyés par votre boutique',
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
                    '1. Votre boutique envoie un POST webhook à votre backend / Edge Function\n'
                    '2. L’endpoint vérifie la signature HMAC avec le secret\n'
                    '3. Le backend insère/met à jour les commandes en base\n'
                    '4. L’app mobile lit les commandes en direct via Supabase (Auth + RPC)',
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
  late final TextEditingController _idFieldCtrl;
  late final TextEditingController _sinceParamCtrl;
  late final TextEditingController _pageParamCtrl;
  late final TextEditingController _limitParamCtrl;
  late final TextEditingController _pageSizeCtrl;

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
    // API keys are stored in secure storage (never in SQLite).
    _apiKeyCtrl       = TextEditingController(text: '');
    _responsePathCtrl = TextEditingController(text: s.responsePath);
    _authType         = s.authType.isEmpty ? 'none' : s.authType;
    _idFieldCtrl      = TextEditingController(text: s.idFieldPath);
    _sinceParamCtrl   = TextEditingController(text: s.sinceParam);
    _pageParamCtrl    = TextEditingController(text: s.pageParam);
    _limitParamCtrl   = TextEditingController(text: s.limitParam);
    _pageSizeCtrl     = TextEditingController(text: s.pageSize > 0 ? '${s.pageSize}' : '50');

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
    _idFieldCtrl.dispose();
    _sinceParamCtrl.dispose();
    _pageParamCtrl.dispose();
    _limitParamCtrl.dispose();
    _pageSizeCtrl.dispose();
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

      final idField = _idFieldCtrl.text.trim();
      final hasCanonicalIdMapping =
          mapping.containsKey('orderNumber') && mapping['orderNumber']!.trim().isNotEmpty;
      if (idField.isEmpty && !hasCanonicalIdMapping) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Renseignez "Champ ID" ou mappez "orderNumber".'),
          ));
        }
        return;
      }

      // Save only if user entered a new key; leaving empty keeps existing key.
      if (widget.source.id != null && _apiKeyCtrl.text.trim().isNotEmpty) {
        await ExternalSourceSecrets.instance.setApiKey(
          widget.source.id!,
          _apiKeyCtrl.text.trim(),
        );
      }

      if (!mounted) return;
      await context.read<AdminProvider>().updateSourceConfig(widget.source.id!, {
        'url':           _urlCtrl.text.trim(),
        'auth_type':     _authType,
        'response_path': _responsePathCtrl.text.trim(),
        'id_field':      idField,
        'since_param':   _sinceParamCtrl.text.trim(),
        'page_param':    _pageParamCtrl.text.trim(),
        'limit_param':   _limitParamCtrl.text.trim(),
        'page_size':     int.tryParse(_pageSizeCtrl.text.trim()) ?? 50,
        'field_mapping': jsonEncode(mapping),
        // legacy cleanup: never store api_key in SQLite config
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
                    helperText: 'Laisser vide pour conserver la clé actuelle.',
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

            _SheetSection(title: 'Identifiant & synchro (recommandé)', children: [
              TextFormField(
                controller: _idFieldCtrl,
                decoration: const InputDecoration(
                  labelText: 'Champ ID (obligatoire)',
                  hintText: 'id  ou  order.id  ou  ref_cmd',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.fingerprint),
                  isDense: true,
                  helperText: 'Permet la déduplication correcte (évite les doublons/collisions).',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sinceParamCtrl,
                decoration: const InputDecoration(
                  labelText: 'Paramètre "since" (optionnel)',
                  hintText: 'updated_since',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.update),
                  isDense: true,
                  helperText: 'Si l’API supporte un filtre depuis une date ISO (last_sync_at).',
                ),
              ),
            ]),
            const SizedBox(height: 16),

            _SheetSection(title: 'Pagination (optionnel)', children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pageParamCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Paramètre page',
                        hintText: 'page',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _limitParamCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Paramètre limit',
                        hintText: 'limit',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pageSizeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Taille de page',
                  hintText: '50',
                  border: OutlineInputBorder(),
                  isDense: true,
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

// ── Feuille : Nouvelle intégration (même présentation que les autres feuilles) ─

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
  bool _keyVisible = false;

  bool get _isWebhook => _type == 'webhook';

  String _defaultSourceIdFromName() => _nameCtrl.text
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_');

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
      final sourceIdRaw = _sourceIdCtrl.text.trim();
      final sourceId = sourceIdRaw.isNotEmpty
          ? sourceIdRaw
          : _defaultSourceIdFromName();
      final config = _isWebhook
          ? {
              'webhook_secret': _keyCtrl.text.trim(),
              'source_identifier': sourceId,
            }
          : {
              'url': _urlCtrl.text.trim(),
              'auth_type': 'none',
              // Never store api keys in SQLite; use secure storage instead.
              'api_key': '',
              // Safe defaults; can be edited later in config sheet.
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
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nouvelle intégration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Choisissez le type de source, puis renseignez les champs. '
              'Le webhook est recommandé pour recevoir les commandes en temps réel.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom affiché de la boutique',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
              onChanged: (_) {
                if (_isWebhook && _sourceIdCtrl.text.trim().isEmpty) {
                  setState(() {});
                }
              },
            ),
            if (_isWebhook) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _sourceIdCtrl,
                decoration: InputDecoration(
                  labelText: 'Identifiant « source » dans les webhooks',
                  hintText: _defaultSourceIdFromName().isEmpty
                      ? 'ex. sucre_store'
                      : 'Défaut si vide : ${_defaultSourceIdFromName()}',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.fingerprint_outlined),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Doit être identique au champ JSON « source » envoyé par votre backend '
                '(et à store_source_platform si vous utilisez la même boutique en API).',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.35),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_type),
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: 'webhook',
                  child: Text(
                    'Webhook (recommandé), réception des commandes',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                DropdownMenuItem(
                  value: 'rest_polling',
                  child: Text(
                    'REST Polling, synchronisation planifiée',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
              onChanged: _isSaving
                  ? null
                  : (v) => setState(() {
                        _type = v!;
                        _keyCtrl.clear();
                      }),
            ),
            const SizedBox(height: 12),
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
                  hintText: 'À configurer après création si besoin',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _keyVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _keyVisible = !_keyVisible),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Text(
                  'Le webhook déclenche l’import / la mise à jour des commandes. '
                  'Le secret HMAC doit être exactement le même que celui utilisé par la boutique '
                  'pour signer le corps JSON (et par votre endpoint pour vérifier X-Webhook-Signature).',
                  style: TextStyle(fontSize: 11, color: Color(0xFF166534), height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Ajouter',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ── Widgets communs ──────────────────────────────────────────────────────────

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
      maxLines: 1,
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
