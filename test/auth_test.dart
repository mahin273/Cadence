import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cadence/core/supabase/auth_state.dart';
import 'package:cadence/core/supabase/auth_provider.dart';

void main() {
  group('Supabase Auth State & Provider', () {
    test('CadenceAuthState.guest defaults to deterministic offline user ID', () {
      const state = CadenceAuthState.guest();

      expect(state.status, AuthStatus.guest);
      expect(state.isGuest, true);
      expect(state.isAuthenticated, false);
      expect(state.activeUserId, 'local_guest_user');
      expect(state.user, isNull);
      expect(state.errorMessage, isNull);
    });

    test('CadenceAuthState.authenticated supplies user id for database operations', () {
      final mockUser = User(
        id: '11111111-2222-3333-4444-555555555555',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'cadence_user@example.com',
      );

      final state = CadenceAuthState.authenticated(mockUser);

      expect(state.status, AuthStatus.authenticated);
      expect(state.isGuest, false);
      expect(state.isAuthenticated, true);
      expect(state.activeUserId, '11111111-2222-3333-4444-555555555555');
      expect(state.user?.email, 'cadence_user@example.com');
    });

    test('activeUserIdProvider reactively reflects active user in Riverpod container', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Default should be local guest
      expect(container.read(activeUserIdProvider), 'local_guest_user');
    });
  });
}
