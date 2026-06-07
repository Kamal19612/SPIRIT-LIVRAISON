import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Mot de passe livreur (affichage admin sur fiche CNIB — stockage local chiffré).
class DriverCredentialsStorage {
  DriverCredentialsStorage._();
  static final DriverCredentialsStorage instance = DriverCredentialsStorage._();

  final _storage = const FlutterSecureStorage();

  String _key(int driverId) => 'driver_login_password_$driverId';

  Future<void> setPassword(int driverId, String password) async {
    await _storage.write(key: _key(driverId), value: password);
  }

  Future<String?> getPassword(int driverId) =>
      _storage.read(key: _key(driverId));

  Future<void> deletePassword(int driverId) async {
    await _storage.delete(key: _key(driverId));
  }
}
