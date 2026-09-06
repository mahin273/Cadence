import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthStatus {
  guest,
  authenticated,
  loading,
  error,
}

class CadenceAuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  /// Default deterministic user ID for offline guest operation.
  static const String guestUserId = 'local_guest_user';

  const CadenceAuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  const CadenceAuthState.guest()
      : status = AuthStatus.guest,
        user = null,
        errorMessage = null;

  const CadenceAuthState.authenticated(User this.user)
      : status = AuthStatus.authenticated,
        errorMessage = null;

  const CadenceAuthState.loading()
      : status = AuthStatus.loading,
        user = null,
        errorMessage = null;

  const CadenceAuthState.error(String message)
      : status = AuthStatus.error,
        user = null,
        errorMessage = message;

  /// Active user ID to bind to database entries.
  String get activeUserId => user?.id ?? guestUserId;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isGuest => status == AuthStatus.guest;
  bool get isLoading => status == AuthStatus.loading;
}
