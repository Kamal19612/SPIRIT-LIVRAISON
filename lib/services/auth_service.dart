import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import 'supabase_app_client.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _storage = const FlutterSecureStorage();
  static const _sessionKey = 'supabase_session_json';

  Future<UserModel> login(String email, String password) async {
    final client = await SupabaseAppClient.instance.client();
    final res = await client.auth.signInWithPassword(
      email: email.trim(),
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

    return UserModel(id: storeUserId, username: email.trim(), role: role);
  }

  Future<void> logout() async {
    try {
      final client = await SupabaseAppClient.instance.client();
      await client.auth.signOut();
    } catch (_) {}
    await _storage.delete(key: _sessionKey);
  }

  Future<UserModel?> tryRestoreSession() async {
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
