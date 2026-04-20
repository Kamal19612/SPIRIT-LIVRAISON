import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/admin_provider.dart';
import '../../services/cnib_text_recognition_service.dart';
import '../../services/driver_identity_storage.dart';
import '../../utils/cnib_ocr_parser.dart';

class AdminDriversScreen extends StatelessWidget {
  const AdminDriversScreen({super.key});

  void _showAddDriverSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _AddDriverSheet(),
      ),
    );
  }

  void _showDriverDetail(BuildContext context, UserModel driver) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DriverDetailSheet(driver: driver),
    );
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
                        onPressed: () => _showAddDriverSheet(context),
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
                    itemBuilder: (_, i) => _DriverTile(
                      driver: admin.drivers[i],
                      onOpenDetail: () =>
                          _showDriverDetail(context, admin.drivers[i]),
                    ),
                  ),
                ),
      floatingActionButton: admin.drivers.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddDriverSheet(context),
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
  final VoidCallback onOpenDetail;

  const _DriverTile({
    required this.driver,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final admin = context.read<AdminProvider>();
    final hasLocation = driver.lat != null && driver.lng != null;
    final label = driver.displayName.isNotEmpty
        ? driver.displayName
        : driver.username;
    final initial =
        label.isNotEmpty ? label.substring(0, 1).toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onOpenDetail,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: driver.active
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12)
                          : const Color(0xFFF3F4F6),
                      child: Text(
                        initial,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.displayName,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827)),
                          ),
                          if (driver.displayPhone != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              driver.displayPhone!,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            'Connexion : ${driver.username}',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF9CA3AF)),
                          ),
                          Row(
                            children: [
                              Icon(
                                hasLocation
                                    ? Icons.location_on
                                    : Icons.location_off,
                                size: 12,
                                color: hasLocation
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFD1D5DB),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  hasLocation
                                      ? 'Pos: ${driver.lat!.toStringAsFixed(4)}, ${driver.lng!.toStringAsFixed(4)}'
                                      : 'Position inconnue',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9CA3AF)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Appuyez pour voir la fiche CNIB',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 8),
            child: Column(
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
          ),
        ],
      ),
    );
  }
}

// ── Détail livreur ──────────────────────────────────────────────────────────

class _DriverDetailSheet extends StatelessWidget {
  final UserModel driver;
  const _DriverDetailSheet({required this.driver});

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce livreur ?'),
        content: const Text(
          'Le compte et les données associées seront supprimés. '
          'Les commandes ne seront plus liées à ce livreur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style: TextStyle(
                    color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AdminProvider>().deleteDriver(driver.id);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Livreur supprimé'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final path = driver.cnibImagePath;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Text(
              driver.displayName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              'Compte : ${driver.username}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            if (path != null && path.isNotEmpty && !kIsWeb)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(path),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            if (path != null && path.isNotEmpty) const SizedBox(height: 16),
            _detailSection('Coordonnées', [
              _DetailRow('Téléphone', driver.displayPhone ?? '—'),
              _DetailRow('Statut', driver.active ? 'Actif' : 'Inactif'),
            ]),
            _detailSection('Identité (CNIB)', [
              _DetailRow('Nom', driver.lastName ?? '—'),
              _DetailRow('Prénoms', driver.firstName ?? '—'),
              _DetailRow('N° identifiant national', driver.cnibNationalId ?? '—'),
              _DetailRow('N° série carte', driver.cnibSerial ?? '—'),
              _DetailRow('Né(e) le', driver.birthDate ?? '—'),
              _DetailRow('À', driver.birthPlace ?? '—'),
              _DetailRow('Sexe', driver.gender ?? '—'),
              _DetailRow('Profession', driver.profession ?? '—'),
              _DetailRow('Délivrée le', driver.cnibIssueDate ?? '—'),
              _DetailRow('Expire le', driver.cnibExpiryDate ?? '—'),
            ]),
            if (driver.cnibOcrText != null &&
                driver.cnibOcrText!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                title: const Text('Texte OCR brut',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                children: [
                  SelectableText(
                    driver.cnibOcrText!,
                    style: const TextStyle(fontSize: 11, height: 1.35),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
              label: const Text('Supprimer ce livreur',
                  style: TextStyle(color: Color(0xFFDC2626))),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Fermer', style: TextStyle(color: primary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Formulaire création livreur ─────────────────────────────────────────────

class _AddDriverSheet extends StatefulWidget {
  const _AddDriverSheet();

  @override
  State<_AddDriverSheet> createState() => _AddDriverSheetState();
}

class _AddDriverSheetState extends State<_AddDriverSheet> {
  final _formKey = GlobalKey<FormState>();
  final _lastCtrl = TextEditingController();
  final _firstCtrl = TextEditingController();
  final _nationalIdCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _birthPlaceCtrl = TextEditingController();
  final _professionCtrl = TextEditingController();
  final _issueDateCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _picker = ImagePicker();

  String? _gender;
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isSaving = false;
  bool _ocrBusy = false;
  String? _error;
  String? _pickedPath;
  String _ocrRaw = '';

  @override
  void dispose() {
    _lastCtrl.dispose();
    _firstCtrl.dispose();
    _nationalIdCtrl.dispose();
    _serialCtrl.dispose();
    _birthDateCtrl.dispose();
    _birthPlaceCtrl.dispose();
    _professionCtrl.dispose();
    _issueDateCtrl.dispose();
    _expiryCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final x = await _picker.pickImage(
      source: source,
      maxWidth: 2400,
      imageQuality: 92,
    );
    if (x != null) {
      setState(() {
        _pickedPath = x.path;
        _ocrRaw = '';
        _error = null;
      });
    }
  }

  Future<void> _runOcr() async {
    if (_pickedPath == null) return;
    setState(() {
      _ocrBusy = true;
      _error = null;
    });
    final text = await recognizeTextFromImagePath(_pickedPath!);
    if (!mounted) return;
    setState(() {
      _ocrBusy = false;
      _ocrRaw = text ?? '';
    });
    if (text != null && text.trim().isNotEmpty) {
      final p = CnibOcrParser.parseBurkinaCnib(text);
      setState(() {
        if (p.lastName != null) _lastCtrl.text = p.lastName!;
        if (p.firstNames != null) _firstCtrl.text = p.firstNames!;
        if (p.nationalIdNumber != null) {
          _nationalIdCtrl.text = p.nationalIdNumber!;
        }
        if (p.cardSerial != null) _serialCtrl.text = p.cardSerial!;
        if (p.birthDate != null) _birthDateCtrl.text = p.birthDate!;
        if (p.birthPlace != null) _birthPlaceCtrl.text = p.birthPlace!;
        if (p.gender != null) _gender = p.gender;
        if (p.profession != null) _professionCtrl.text = p.profession!;
        if (p.issueDate != null) _issueDateCtrl.text = p.issueDate!;
        if (p.expiryDate != null) _expiryCtrl.text = p.expiryDate!;
      });
    } else if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      setState(() => _error =
          'Aucun texte détecté. Vérifiez la netteté de la photo ou saisissez les champs à la main.');
    } else {
      setState(() => _error =
          'OCR disponible sur Android et iOS. Saisissez les champs à la main.');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedPath == null) {
      setState(() => _error = 'La photo de la CNIB est obligatoire.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final stored = await persistCnibPhoto(_pickedPath!);
      if (!mounted) return;
      final username = await context.read<AdminProvider>().createDriver(
            lastName: _lastCtrl.text.trim(),
            firstName: _firstCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            password: _passCtrl.text.trim(),
            cnibImagePath: stored,
            cnibOcrText: _ocrRaw.isEmpty ? null : _ocrRaw,
            cnibNationalId: _nationalIdCtrl.text.trim(),
            cnibSerial: _serialCtrl.text.trim(),
            birthDate: _birthDateCtrl.text.trim(),
            birthPlace: _birthPlaceCtrl.text.trim(),
            gender: _gender,
            profession: _professionCtrl.text.trim(),
            cnibIssueDate: _issueDateCtrl.text.trim(),
            cnibExpiryDate: _expiryCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Livreur créé. Identifiant de connexion : $username'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
        _error = e.toString().contains('UNIQUE')
            ? 'Un compte avec ce numéro existe déjà'
            : e.toString();
      });
    }
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey.shade700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.45,
      maxChildSize: 0.98,
      expand: false,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                'Nouveau livreur',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Modèle CNIB Burkina Faso : photographiez le recto, lancez la lecture, '
                'complétez le téléphone et le mot de passe.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                  ),
                ),

              _fieldLabel('PHOTO CNIB (RECTO)'),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Galerie'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Appareil'),
                    ),
                  ),
                ],
              ),
              if (_pickedPath != null && !kIsWeb) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(_pickedPath!),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: (_pickedPath == null || _ocrBusy || _isSaving)
                    ? null
                    : _runOcr,
                icon: _ocrBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.document_scanner_outlined, size: 18),
                label: Text(_ocrBusy ? 'Lecture OCR…' : 'Lire la CNIB (OCR)'),
              ),

              const SizedBox(height: 16),
              _fieldLabel('IDENTITÉ SUR LA CARTE'),
              TextFormField(
                controller: _lastCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Nom *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _firstCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Prénoms *',
                  hintText: 'Comme sur la CNIB',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nationalIdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'N° identifiant national',
                  hintText: 'Ex. 03010400215072870',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serialCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'N° série de la carte',
                  hintText: 'Ex. B11127698',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code_2_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _birthDateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Né(e) le',
                        hintText: 'JJ/MM/AAAA',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _birthPlaceCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'À (lieu de naissance)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey(_gender),
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Sexe',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem<String?>(
                            value: null, child: Text('—')),
                        DropdownMenuItem(value: 'M', child: Text('M')),
                        DropdownMenuItem(value: 'F', child: Text('F')),
                      ],
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _professionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Profession',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _issueDateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Délivrée le',
                        hintText: 'JJ/MM/AAAA',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _expiryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Expire le',
                        hintText: 'JJ/MM/AAAA',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _fieldLabel('COMPTE LIVREUR'),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone * (pas sur la CNIB)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: '+226 …',
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 6) ? 'Numéro invalide' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure1,
                decoration: InputDecoration(
                  labelText: 'Mot de passe *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure1
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
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
                  labelText: 'Confirmer le mot de passe *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure2
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
                validator: (v) =>
                    v != _passCtrl.text ? 'Mots de passe différents' : null,
              ),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Créer le compte',
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
