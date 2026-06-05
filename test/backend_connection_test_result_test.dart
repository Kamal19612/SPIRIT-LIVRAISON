import 'package:flutter_test/flutter_test.dart';

import 'package:appstore/models/backend_connection_test_result.dart';

void main() {
  group('BackendConnectionTestResult', () {
    test('network only success', () {
      final r = BackendConnectionTestResult(steps: [
        const BackendTestStep(label: 'API publique', ok: true, detail: 'Boutique (200)'),
        const BackendTestStep(
          label: 'Login JWT',
          ok: true,
          skipped: true,
          detail: 'non testé',
        ),
      ]);
      expect(r.isSuccess, isTrue);
      expect(r.headline, 'Connexion OK (réseau)');
    });

    test('partial when jwt fails', () {
      final r = BackendConnectionTestResult(steps: [
        const BackendTestStep(label: 'API publique', ok: true, detail: 'OK'),
        const BackendTestStep(label: 'Login JWT', ok: false, detail: 'refusé'),
      ]);
      expect(r.isPartial, isTrue);
      expect(r.headline, 'Connexion partielle');
    });

    test('full success with delivery', () {
      final r = BackendConnectionTestResult(steps: [
        const BackendTestStep(label: 'API publique', ok: true, detail: 'OK'),
        const BackendTestStep(label: 'Login JWT', ok: true, detail: 'livreur'),
        const BackendTestStep(label: 'API livraison', ok: true, detail: '5 commandes'),
      ]);
      expect(r.isSuccess, isTrue);
      expect(r.headline, 'Connexion complète OK');
    });
  });
}
