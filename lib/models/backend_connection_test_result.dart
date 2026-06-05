/// Une étape du diagnostic de connexion backend.
class BackendTestStep {
  final String label;
  final bool ok;
  final bool skipped;
  final String detail;

  const BackendTestStep({
    required this.label,
    required this.ok,
    required this.detail,
    this.skipped = false,
  });
}

/// Résultat agrégé : API publique + login JWT + endpoint livraison.
class BackendConnectionTestResult {
  final List<BackendTestStep> steps;

  const BackendConnectionTestResult({required this.steps});

  bool get publicOk => _step('API publique')?.ok ?? false;
  bool get jwtTested => _step('Login JWT') != null && !(_step('Login JWT')!.skipped);
  bool get jwtOk => _step('Login JWT')?.ok ?? false;
  bool get deliveryTested =>
      _step('API livraison') != null && !(_step('API livraison')!.skipped);
  bool get deliveryOk => _step('API livraison')?.ok ?? false;

  bool get isSuccess {
    if (!publicOk) return false;
    if (jwtTested && !jwtOk) return false;
    if (deliveryTested && !deliveryOk) return false;
    return true;
  }

  bool get isPartial => publicOk && ((jwtTested && !jwtOk) || (deliveryTested && !deliveryOk));

  String get headline {
    if (!publicOk) return 'Échec réseau';
    if (isPartial) return 'Connexion partielle';
    if (jwtTested && deliveryTested) return 'Connexion complète OK';
    return 'Connexion OK (réseau)';
  }

  String get displayText {
    final lines = steps.map((s) {
      final status = s.skipped ? '—' : (s.ok ? 'OK' : 'Échec');
      return '• ${s.label} : $status — ${s.detail}';
    });
    return '$headline\n${lines.join('\n')}';
  }

  BackendTestStep? _step(String label) {
    for (final s in steps) {
      if (s.label == label) return s;
    }
    return null;
  }
}
