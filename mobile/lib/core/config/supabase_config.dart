/// Connection details for the shared Warq database.
///
/// The anonymous key is *designed* to be public: it identifies the project, not
/// the caller, and every table is behind row-level security that resolves the
/// real user from their signed-in session. It ships inside the app binary
/// whatever we do, so committing it buys convenience at no cost.
///
/// The service-role key is the dangerous one. It bypasses row-level security
/// entirely and must never appear in client code.
///
/// Both values can be overridden at build time without touching the source,
/// which is how a staging project is pointed at:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://befjsognpcqxuhqfmlpe.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6'
        'ImJlZmpzb2ducGNxeHVocWZtbHBlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYzMDA3'
        'NDMsImV4cCI6MjEwMTg3Njc0M30.NKVIpWtSaKUb5kSS9FHKyhvm9-rPpCXwjXRJxCUeYEU',
  );

  /// False when a build has been pointed at nothing, so startup can fail with
  /// an explanation instead of a confusing network error later.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
