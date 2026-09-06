import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_state.dart';
import 'supabase_config.dart';

/// Provider exposing the raw SupabaseClient instance if initialized.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (SupabaseConfig.isConfigured) {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
  return null;
});

class AuthNotifier extends Notifier<CadenceAuthState> {
  @override
  CadenceAuthState build() {
    final client = ref.watch(supabaseClientProvider);
    if (client != null) {
      final currentUser = client.auth.currentUser;
      if (currentUser != null) {
        return CadenceAuthState.authenticated(currentUser);
      }

      // Listen to auth state changes from GoTrue
      client.auth.onAuthStateChange.listen((data) {
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
