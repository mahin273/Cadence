import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String _envUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String _envAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static String _activeUrl = _envUrl;
  static String _activeAnonKey = _envAnonKey;
  static bool _initialized = false;

  /// Supabase project URL currently active.
  static String get url => _activeUrl;

  /// Supabase public anon key currently active.
  static String get anonKey => _activeAnonKey;

  /// Whether Supabase credentials have been configured with genuine values.
  static bool get isConfigured =>
      _activeUrl.isNotEmpty &&
      _activeUrl != 'https://placeholder-project.supabase.co' &&
      _activeAnonKey.isNotEmpty &&
      _activeAnonKey != 'placeholder-anon-key';

  /// File where user-configured credentials are saved on disk.
  static Future<File?> _getConfigFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/supabase_config.json');
    } catch (_) {
      // Return null in test harness environments lacking platform channels
      return null;
    }
  }

  /// Load credentials from local storage or compile-time dart-defines.
  static Future<void> loadSavedConfig() async {
    // 1. Initialize from dart-define if provided
    if (_envUrl.isNotEmpty && _envAnonKey.isNotEmpty) {
      _activeUrl = _envUrl.trim();
      _activeAnonKey = _envAnonKey.trim();
    }

    // 2. Override with persisted user configuration if present
    try {
      final file = await _getConfigFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final savedUrl = data['url'] as String?;
        final savedKey = data['anonKey'] as String?;
        if (savedUrl != null &&
            savedUrl.isNotEmpty &&
            savedKey != null &&
            savedKey.isNotEmpty) {
          _activeUrl = savedUrl.trim();
          _activeAnonKey = savedKey.trim();
        }
      }
    } catch (e) {
      debugPrint('Notice reading supabase_config.json: $e');
    }
  }

  /// Initializes the Supabase client safely with offline tolerance.
  static Future<void> initialize() async {
    await loadSavedConfig();

    if (isConfigured && !_initialized) {
      try {
        await Supabase.initialize(
          url: _activeUrl,
          publishableKey: _activeAnonKey,
          debug: kDebugMode,
        );
        _initialized = true;
      } catch (e) {
        debugPrint('Supabase initialization notice: $e');
      }
    }
  }

  /// Save new credentials at runtime and initialize client.
  static Future<bool> saveConfig({
    required String url,
    required String anonKey,
  }) async {
    final cleanUrl = url.trim();
    final cleanKey = anonKey.trim();

    if (cleanUrl.isEmpty || cleanKey.isEmpty) return false;

    try {
      final file = await _getConfigFile();
      if (file != null) {
        await file.writeAsString(jsonEncode({
          'url': cleanUrl,
          'anonKey': cleanKey,
        }));
      }

      _activeUrl = cleanUrl;
      _activeAnonKey = cleanKey;

      if (!_initialized) {
        await Supabase.initialize(
          url: _activeUrl,
          publishableKey: _activeAnonKey,
          debug: kDebugMode,
        );
        _initialized = true;
      }
      return true;
    } catch (e) {
      debugPrint('Failed to save Supabase config: $e');
      return false;
    }
  }

  /// Clear saved credentials.
  static Future<void> clearConfig() async {
    try {
      final file = await _getConfigFile();
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    _activeUrl = _envUrl;
    _activeAnonKey = _envAnonKey;
  }

  @visibleForTesting
  static void setCredentialsForTesting({String? url, String? anonKey}) {
    _activeUrl = url ?? '';
    _activeAnonKey = anonKey ?? '';
  }

  @visibleForTesting
  static void resetForTesting() {
    _activeUrl = _envUrl;
    _activeAnonKey = _envAnonKey;
    _initialized = false;
  }
}
