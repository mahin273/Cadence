import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  /// Supabase project URL passed via --dart-define=SUPABASE_URL=...
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://placeholder-project.supabase.co',
  );

  /// Supabase public anon key passed via --dart-define=SUPABASE_ANON_KEY=...
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'placeholder-anon-key',
  );

  /// Whether Supabase credentials have been configured with genuine values.
  static bool get isConfigured =>
      url != 'https://placeholder-project.supabase.co' &&
      anonKey != 'placeholder-anon-key' &&
      url.isNotEmpty &&
      anonKey.isNotEmpty;

  /// Initializes the Supabase client safely with offline tolerance.
  static Future<void> initialize() async {
    if (isConfigured) {
      try {
        await Supabase.initialize(
          url: url,
          publishableKey: anonKey,
          debug: kDebugMode,
        );
      } catch (e) {
        debugPrint('Supabase initialization notice: $e');
      }
    }
  }
}
