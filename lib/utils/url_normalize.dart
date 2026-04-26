/// Normalise une URL saisie par un humain (espaces parasites, slashs finaux, etc.).
///
/// Exemples de problèmes vus en prod :
/// - `http:// 5.189.133.248:8000` → host invalide `5.189.133.248:8000`
/// - `https://boutique.com:8081/` → OK sans slash final
String? normalizeHttpOrigin(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;

  // Retire les espaces internes (copier/coller depuis messagerie / PDF)
  s = s.replaceAll(RegExp(r'\s+'), '');

  // Si l'utilisateur colle seulement "5.189.133.248:8000", on préfixe http://
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(s)) {
    s = 'http://$s';
  }

  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }

  // Port explicite invalide (ex. « :0 » collé par erreur). replace(port: null) ne retire pas :0.
  final parsed = Uri.tryParse(s);
  if (parsed != null &&
      parsed.hasPort &&
      (parsed.port <= 0 || parsed.port > 65535)) {
    s = Uri(
      scheme: parsed.scheme.isEmpty ? null : parsed.scheme,
      host: parsed.host.isEmpty ? null : parsed.host,
      path: parsed.path,
      query: parsed.hasQuery ? parsed.query : null,
      fragment: parsed.hasFragment ? parsed.fragment : null,
    ).toString();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
  }

  return s.isEmpty ? null : s;
}

/// Normalise l’origine du backend Spring Boot attendue par l’app, **sans** suffixe `/api`.
///
/// L’app construit ensuite les endpoints avec `{origin}/api/...`.
/// Ex: si l’utilisateur colle `https://spdelivery.socialracine.com/api`,
/// on doit stocker/consommer `https://spdelivery.socialracine.com` pour éviter `/api/api/...`.
String? normalizeBackendOrigin(String raw) {
  final base = normalizeHttpOrigin(raw);
  if (base == null || base.isEmpty) return null;

  final uri = Uri.tryParse(base);
  if (uri == null) {
    return base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
  }

  if (uri.path == '/api') {
    final cleaned = uri.replace(path: '').toString();
    return cleaned.isEmpty ? null : cleaned;
  }

  // Fallback (au cas où Uri.tryParse garde un path atypique)
  if (base.endsWith('/api')) return base.substring(0, base.length - 4);
  return base;
}
