/// Messages d'erreur auth API STORE-ALL (401 vs 403).
String storeApiAuthErrorMessage({
  required int statusCode,
  required String backendName,
  String context = 'admin',
}) {
  if (statusCode == 401) {
    return 'Session invalidée sur $backendName. Reconnectez-vous '
        '(une autre connexion mobile a pu remplacer cette session).';
  }
  if (statusCode == 403) {
    if (context == 'users') {
      return 'Accès utilisateurs refusé sur $backendName (rôle ou boutique).';
    }
    return 'Accès $context refusé sur $backendName (rôle ou boutique).';
  }
  return 'Erreur $statusCode sur $backendName.';
}

bool isStoreApiAuthStatus(int statusCode) =>
    statusCode == 401 || statusCode == 403;
