import 'backend_server_model.dart';

/// Échec de connexion JWT sur un serveur configuré.
class BackendLoginFailure {
  final BackendServer backend;
  final String message;

  const BackendLoginFailure({required this.backend, required this.message});
}

/// Synthèse après login multi-backend.
class BackendLoginStatus {
  final List<BackendServer> connected;
  final List<BackendLoginFailure> failed;

  const BackendLoginStatus({
    required this.connected,
    this.failed = const [],
  });

  int get connectedCount => connected.length;
  int get totalCount => connected.length + failed.length;

  bool get isMultiBackend => totalCount > 1;
  bool get isPartial => failed.isNotEmpty && connected.isNotEmpty;
  bool get allConnected => failed.isEmpty && connected.isNotEmpty;

  /// Ex. « Connecté sur 2/3 serveurs »
  String get summaryMessage {
    if (totalCount == 0) return '';
    if (totalCount == 1) {
      if (connectedCount == 1) return 'Connecté à ${connected.first.name}.';
      return '';
    }
    return 'Connecté sur $connectedCount/$totalCount serveur${totalCount > 1 ? 's' : ''}.';
  }

  /// SnackBar courte après login.
  String get snackbarMessage {
    final base = summaryMessage;
    if (!isPartial) return base;
    final names = failed.map((f) => f.backend.name).join(', ');
    return '$base Échec : $names.';
  }

  List<String> get failureDetails =>
      failed.map((f) => '${f.backend.name} : ${f.message}').toList();
}
