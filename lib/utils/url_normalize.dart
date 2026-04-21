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

  return s.isEmpty ? null : s;
}
