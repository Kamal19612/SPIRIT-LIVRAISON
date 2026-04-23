/// Configuration Supabase (URL + anon key).
///
/// Définir au lancement Flutter, par exemple :
/// `flutter run --dart-define=SUPABASE_URL=https://spdelivery.socialracine.com --dart-define=SUPABASE_ANON_KEY=eyJ...`
///
/// Si `SUPABASE_ANON_KEY` est vide, la valeur peut être lue depuis SQLite
/// (`app_config` clés `supabase_anon_key` et optionnellement `supabase_url`).
abstract final class SupabaseEnv {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://spdelivery.socialracine.com',
  );

  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
