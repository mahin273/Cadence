import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_state.dart';
import 'supabase_config.dart';

/// Notifier managing the SupabaseClient instance dynamically.
class SupabaseClientNotifier extends Notifier<SupabaseClient?> {
  @override
  SupabaseClient? build() {
    if (SupabaseConfig.isConfigured) {
      try {
        return Supabase.instance.client;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Configure new Supabase project credentials at runtime.
  Future<bool> configure({
    required String url,
    required String anonKey,
  }) async {
    final success = await SupabaseConfig.saveConfig(url: url, anonKey: anonKey);
    if (success) {
      try {
        state = Supabase.instance.client;
        return true;
      } catch (_) {
        try {
          state = SupabaseClient(url, anonKey);
          return true;
        } catch (_) {
          return false;
        }
      }
    }
    return false;
  }

  /// Disconnect and remove saved Supabase credentials.
  Future<void> clearConfig() async {
    await SupabaseConfig.clearConfig();
    state = null;
  }
}

final supabaseClientProvider =
    NotifierProvider<SupabaseClientNotifier, SupabaseClient?>(
  SupabaseClientNotifier.new,
);

class AuthNotifier extends Notifier<CadenceAuthState> {
  StreamSubscription<AuthState>? _authSub;

  @override
  CadenceAuthState build() {
    ref.onDispose(() {
      _authSub?.cancel();
    });

    final client = ref.watch(supabaseClientProvider);
    if (client != null) {
      final currentUser = client.auth.currentUser;
      if (currentUser != null) {
        return CadenceAuthState.authenticated(currentUser);
      }

      // Listen to auth state changes from GoTrue
      _authSub?.cancel();
      _authSub = client.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        if (session != null) {
          state = CadenceAuthState.authenticated(session.user);
        } else {
          state = const CadenceAuthState.guest();
        }
      });
    }

    return const CadenceAuthState.guest();
  }

  Future<void> signIn({required String email, required String password}) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      state = const CadenceAuthState.error(
        'Supabase is not configured. Running in offline Guest Mode.',
      );
      return;
    }

    state = const CadenceAuthState.loading();
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.user != null) {
        state = CadenceAuthState.authenticated(response.user!);
      } else {
        state = const CadenceAuthState.guest();
      }
    } on AuthException catch (e) {
      state = CadenceAuthState.error(e.message);
    } catch (e) {
      state = CadenceAuthState.error('Sign in failed: $e');
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      state = const CadenceAuthState.error(
        'Supabase is not configured. Running in offline Guest Mode.',
      );
      return;
    }

    state = const CadenceAuthState.loading();
    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      if (response.user != null) {
        state = CadenceAuthState.authenticated(response.user!);
      } else {
        state = const CadenceAuthState.guest();
      }
    } on AuthException catch (e) {
      state = CadenceAuthState.error(e.message);
    } catch (e) {
      state = CadenceAuthState.error('Sign up failed: $e');
    }
  }

  Future<void> signOut() async {
    final client = ref.read(supabaseClientProvider);
    if (client != null) {
      await client.auth.signOut();
    }
    state = const CadenceAuthState.guest();
  }

  void continueAsGuest() {
    state = const CadenceAuthState.guest();
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, CadenceAuthState>(
  AuthNotifier.new,
);

/// Provider exposing the current active user ID (UUID or guest fallback).
final activeUserIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.activeUserId;
});
