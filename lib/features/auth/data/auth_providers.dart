import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/providers.dart';
import '../../../shared/models/user.dart';
import 'auth_repository.dart';

/// Provides the AuthRepository as a singleton.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthRepository(api, storage);
});

/// Auth state — what the app knows about the current user.
sealed class AuthState {
  const AuthState();
}

/// Initial state on app boot (before we've checked persistent storage).
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading state — used during login and during the boot-time /me check.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// User is fully authenticated and password is changed.
class AuthAuthenticated extends AuthState {
  final User user;
  const AuthAuthenticated(this.user);
}

/// User is logged in but must change their password before doing anything else.
class AuthPasswordChangeRequired extends AuthState {
  final User user;
  const AuthPasswordChangeRequired(this.user);
}

/// No valid session — user must log in.
class AuthUnauthenticated extends AuthState {
  /// Optional message to show on the login screen (e.g., from a failed login).
  final String? message;
  const AuthUnauthenticated({this.message});
}

/// Notifier that holds and mutates the auth state.
class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthStateNotifier(this._repo) : super(const AuthInitial());

  /// Called once on app startup. Checks persistent storage and verifies
  /// the token still works by calling /me.
  Future<void> bootstrap() async {
    state = const AuthLoading();

    final hasToken = await _repo.hasStoredToken();
    if (!hasToken) {
      state = const AuthUnauthenticated();
      return;
    }

    try {
      final user = await _repo.me();
      final mustChange = await _repo.mustChangePassword();

      state = mustChange
          ? AuthPasswordChangeRequired(user)
          : AuthAuthenticated(user);
    } on ApiException catch (e) {
      // Token expired or invalid — clear and force re-login
      if (e.isUnauthorized) {
        await _repo.logout();
        state = const AuthUnauthenticated();
      } else {
        // Network or server error — leave token, but show login with error
        state = AuthUnauthenticated(message: e.message);
      }
    } catch (_) {
      // Parse error, type error, or any other unexpected exception.
      // Best response: clear the token and force a fresh login so the user
      // isn't stuck on a frozen splash screen.
      await _repo.logout();
      state = const AuthUnauthenticated(
        message: 'Could not load user data. Please sign in again.',
      );
    }
  }

  /// Login with email + password.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    try {
      final response = await _repo.login(email: email, password: password);
      state = response.user.mustChangePassword
          ? AuthPasswordChangeRequired(response.user)
          : AuthAuthenticated(response.user);
    } on ApiException catch (e) {
      state = AuthUnauthenticated(message: e.message);
    }
  }

  /// Change password (used in forced-change flow and voluntary change).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final currentState = state;
    if (currentState is! AuthPasswordChangeRequired &&
        currentState is! AuthAuthenticated) {
      throw const ApiException(
        message: 'Cannot change password without an active session.',
      );
    }

    final user = currentState is AuthPasswordChangeRequired
        ? currentState.user
        : (currentState as AuthAuthenticated).user;

    state = const AuthLoading();
    try {
      await _repo.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        newPasswordConfirmation: newPasswordConfirmation,
      );
      // Promote to authenticated with mustChangePassword cleared
      state = AuthAuthenticated(user.copyWith(mustChangePassword: false));
    } on ApiException catch (_) {
      // Restore previous state so user can retry
      state = currentState;
      rethrow;
    }
  }

  /// Re-fetches the authenticated user from `/api/auth/me` and replaces
  /// the cached [User] in state. Used by the Profile screen after a
  /// self-service update to keep the global user data fresh.
  ///
  /// Idempotent — safe to call any number of times. Only meaningful when
  /// already in [AuthAuthenticated]; for other states this is a no-op.
  /// Re-throws [ApiException] so the caller can surface failures.
  Future<User> refreshUser() async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) {
      throw const ApiException(
        message: 'Cannot refresh user without an active session.',
      );
    }
    final user = await _repo.me();
    state = AuthAuthenticated(user);
    return user;
  }

  /// Replace the cached user with one returned by another endpoint
  /// (e.g. profile photo upload). Avoids a redundant /me round-trip
  /// when the calling endpoint already returned a refreshed user.
  /// No-op unless we're currently authenticated.
  void replaceUser(User user) {
    final current = state;
    if (current is AuthAuthenticated) {
      state = AuthAuthenticated(user);
    } else if (current is AuthPasswordChangeRequired) {
      state = AuthPasswordChangeRequired(user);
    }
  }

  /// Logout — clears tokens and returns to unauthenticated.
  Future<void> logout() async {
    state = const AuthLoading();
    await _repo.logout();
    state = const AuthUnauthenticated();
  }
}

/// The auth state for the whole app.
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthStateNotifier(repo);
});
