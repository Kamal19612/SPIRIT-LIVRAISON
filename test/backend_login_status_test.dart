import 'package:flutter_test/flutter_test.dart';

import 'package:appstore/models/backend_login_status.dart';
import 'package:appstore/models/backend_server_model.dart';

BackendServer _server(String name) => BackendServer(
      id: 1,
      name: name,
      origin: 'http://localhost:8085',
    );

void main() {
  group('BackendLoginStatus', () {
    test('summary for full multi-backend success', () {
      final status = BackendLoginStatus(
        connected: [_server('A'), _server('B'), _server('C')],
      );
      expect(status.summaryMessage, 'Connecté sur 3/3 serveurs.');
      expect(status.isPartial, isFalse);
    });

    test('summary for partial connection', () {
      final status = BackendLoginStatus(
        connected: [_server('A'), _server('B')],
        failed: [
          BackendLoginFailure(
            backend: BackendServer(id: 3, name: 'C', origin: 'http://c:8085'),
            message: 'Identifiants refusés',
          ),
        ],
      );
      expect(status.summaryMessage, 'Connecté sur 2/3 serveurs.');
      expect(status.isPartial, isTrue);
      expect(status.snackbarMessage, contains('Échec : C'));
    });

    test('summary for single backend', () {
      final status = BackendLoginStatus(connected: [_server('Prod')]);
      expect(status.summaryMessage, 'Connecté à Prod.');
    });
  });
}
