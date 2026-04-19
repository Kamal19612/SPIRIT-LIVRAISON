/// Configuration Supabase pour le flux Realtime (WebhookRelay → `webhook_events`).
///
/// Définir au lancement Flutter, par exemple :
/// `flutter run --dart-define=SUPABASE_URL=http://IP:8000 --dart-define=SUPABASE_ANON_KEY=eyJ...`
///
/// Si `SUPABASE_ANON_KEY` est vide, la valeur peut être lue depuis SQLite
/// (`app_config` clés `supabase_anon_key` et optionnellement `supabase_url`).
abstract final class SupabaseEnv {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
