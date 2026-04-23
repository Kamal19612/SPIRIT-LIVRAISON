import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/local_database.dart';
import '../models/user_model.dart';
import 'supabase_app_client.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _storage = const FlutterSecureStorage();
  static const _sessionKey = 'supabase_session_json';
  static const _localSessionKey = 'local_delivery_user_json';

  Future<UserModel> login(String email, String password) async {
    final trimmed = email.trim();
    final localUser =
        await LocalDatabase.instance.authenticateLocalUser(trimmed, password);
    if (localUser != null) {
      await _storage.delete(key: _sessionKey);
      await _persistLocalSession(localUser);
      return localUser;
    }

    final client = await SupabaseAppClient.instance.client();
    await _storage.delete(key: _localSessionKey);

    final res = await client.auth.signInWithPassword(
      email: trimmed,
      password: password,
    );

    final session = res.session;
    if (session == null) {
      throw Exception('Connexion Supabase impossible (session absente).');
    }

    // Persister la session pour restauration au prochain démarrage.
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));

    // Lire le mapping delivery_agents (auth -> store user id + rôle)
    final resRows = await client
        .from('delivery_agents')
        .select('store_user_id, role, is_active')
        .eq('auth_user_id', session.user.id)
        .limit(1);

    final agentRows = (resRows as List).cast<dynamic>();
    if (agentRows.isEmpty) {
      await client.auth.signOut();
      throw Exception(
        'Compte non autorisé: ce user Supabase n’est pas enregistré dans delivery_agents.',
      );
    }

    final row = Map<String, dynamic>.from(agentRows.first as Map);
    final active = row['is_active'] == true;
    if (!active) {
      await client.auth.signOut();
      throw Exception('Compte désactivé.');
    }

    final storeUserId = (row['store_user_id'] as num).toInt();
    final role = (row['role']?.toString() ?? 'DELIVERY_AGENT').toUpperCase();

    return UserModel(id: storeUserId, username: trimmed, role: role);
  }

  Future<void> _persistLocalSession(UserModel user) async {
    await _storage.write(
      key: _localSessionKey,
      value: jsonEncode({
        'id': user.id,
        'username': user.username,
        'role': user.role,
      }),
    );
  }

  Future<UserModel?> _tryRestoreLocalSession() async {
    final raw = await _storage.read(key: _localSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final id = (map['id'] as num).toInt();
      final rows = await LocalDatabase.instance.db.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      if ((row['active'] as int? ?? 1) != 1) return null;
      return UserModel.fromSqlite(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      final client = await SupabaseAppClient.instance.client();
      await client.auth.signOut();
    } catch (_) {}
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _localSessionKey);
  }

  Future<UserModel?> tryRestoreSession() async {
    final local = await _tryRestoreLocalSession();
    if (local != null) return local;

    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final client = await SupabaseAppClient.instance.client();
      final res = await client.auth.recoverSession(raw);
      final session = res.session;
      if (session == null) return null;

      final resRows = await client
          .from('delivery_agents')
          .select('store_user_id, role, is_active')
          .eq('auth_user_id', session.user.id)
          .limit(1);

      final agentRows = (resRows as List).cast<dynamic>();
      if (agentRows.isEmpty) return null;
      final row = Map<String, dynamic>.from(agentRows.first as Map);
      if (row['is_active'] != true) return null;

      final storeUserId = (row['store_user_id'] as num).toInt();
      final role = (row['role']?.toString() ?? 'DELIVERY_AGENT').toUpperCase();
      return UserModel(id: storeUserId, username: session.user.email ?? '', role: role);
    } catch (_) {
      return null;
    }
  }

  Future<int?> getCurrentUserId() async {
    final u = await tryRestoreSession();
    return u?.id;
  }
}
