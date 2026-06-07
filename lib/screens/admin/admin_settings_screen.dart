import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_config_provider.dart';
import '../../widgets/admin_setting_field.dart';
import 'admin_integrations_tab.dart';

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
                AdminIntegrationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppConfigTab extends StatefulWidget {
  const _AppConfigTab();

  @override
  State<_AppConfigTab> createState() => _AppConfigTabState();
}

class _AppConfigTabState extends State<_AppConfigTab> {
  final _nameCtrl = TextEditingController();
  final _logoCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final config = context.read<AppConfigProvider>();
      _nameCtrl.text = config.appName;
      _logoCtrl.text = config.logoUrl;
      _colorCtrl.text = config.primaryColorHex;
      _phoneCtrl.text = config.contactPhone;
      _emailCtrl.text = config.contactEmail;
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
            appName: _nameCtrl.text.trim(),
            logoUrl: _logoCtrl.text.trim(),
            primaryColorHex: _colorCtrl.text.trim(),
            contactPhone: _phoneCtrl.text.trim(),
            contactEmail: _emailCtrl.text.trim(),
            supportWhatsapp: _whatsappCtrl.text.trim(),
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
              'Ces réglages définissent l\'identité affichée aux livreurs et les coordonnées '
              'utiles pour l\'administration (support, contact).',
              style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.35),
            ),
          ),
          const SizedBox(height: 16),
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
              AdminSettingField(
                ctrl: _nameCtrl,
                label: "Nom de l'application",
                icon: Icons.label_outline,
              ),
              const SizedBox(height: 12),
              AdminSettingField(
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
                    child: AdminSettingField(
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
              AdminSettingField(
                ctrl: _phoneCtrl,
                label: 'Téléphone support',
                icon: Icons.phone_outlined,
                hint: '+224 6XX XXX XXX',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              AdminSettingField(
                ctrl: _emailCtrl,
                label: 'Email administrateur / support',
                icon: Icons.email_outlined,
                hint: 'support@exemple.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              AdminSettingField(
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
              'L\'URL du serveur API et les sources de commandes se configurent '
              'dans l\'onglet Intégrations.',
              style: TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.35),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Sauvegarde...' : 'Sauvegarder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
