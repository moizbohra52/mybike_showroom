import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/core/errors/error_mapper.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication boundary. The Supabase implementation is the only one in
/// the app; tests provide an in-memory fake.
abstract interface class AuthRepository {
  /// True when the SDK holds a (possibly refreshable) session.
  bool get hasSession;

  /// Fires when the SDK ends the session (sign-out elsewhere, refresh failure).
  Stream<void> get signedOut;

  /// Throws an AppFailure with a user-safe message on failure.
  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  /// Profile, showrooms and permissions; `null` when the user has no profile.
  Future<UserSession?> fetchSession();
}

final class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this.client);

  final SupabaseClient client;

  @override
  bool get hasSession => client.auth.currentSession != null;

  @override
  Stream<void> get signedOut => client.auth.onAuthStateChange
      .where((AuthState s) => s.event == AuthChangeEvent.signedOut)
      .map((AuthState _) {});

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await client.auth.signInWithPassword(email: email.trim(), password: password);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } on AuthException {
      // The local session is cleared even when the server call fails
      // (offline); nothing else to do.
    }
  }

  @override
  Future<UserSession?> fetchSession() async {
    try {
      final Object? data = await client.rpc<Object?>('rpc_get_my_session');
      if (data == null) {
        return null;
      }
      return UserSession.fromJson((data as Map<Object?, Object?>).cast<String, Object?>());
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }
}

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>(
  (Ref ref) => SupabaseAuthRepository(Supabase.instance.client),
);
