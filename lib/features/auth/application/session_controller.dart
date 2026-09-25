import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mybike_showroom/core/constants/storage_keys.dart';
import 'package:mybike_showroom/core/storage/preference_store.dart';
import 'package:mybike_showroom/features/auth/data/auth_repository.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_controller.g.dart';

/// Authentication state driving the router guard.
sealed class SessionState {
  const SessionState();
}

final class SignedOut extends SessionState {
  const SignedOut();
}

@immutable
final class SignedIn extends SessionState {
  const SignedIn({required this.session, this.selection});

  /// `null` when the JWT has no profile row.
  final UserSession? session;

  /// `null` until a showroom (or ALL SHOWROOMS) is chosen.
  final ShowroomSelection? selection;

  SessionBlockReason? get blockReason => session == null ? SessionBlockReason.noProfile : session!.blockReason;

  bool get needsShowroom => blockReason == null && selection == null;

  /// Permissions in the current showroom context (empty until selected).
  Set<String> get permissions =>
      (session == null || selection == null) ? const <String>{} : session!.permissionsFor(selection!);

  SessionShowroom? get showroom =>
      (selection == null || selection!.isAll) ? null : session?.showroomById(selection!.showroomId!);
}

/// Permissions in the current showroom context; empty unless signed in with a
/// showroom (or ALL SHOWROOMS) selected. UI gating only — RLS decides.
@riverpod
Set<String> currentPermissions(Ref ref) {
  final SessionState? state = ref.watch(sessionControllerProvider).value;
  return state is SignedIn ? state.permissions : const <String>{};
}

/// The working showroom (or ALL SHOWROOMS); `null` until chosen. Showroom-
/// scoped screens watch this so switching showroom reloads their data.
@riverpod
ShowroomSelection? currentSelection(Ref ref) {
  final SessionState? state = ref.watch(sessionControllerProvider).value;
  return state is SignedIn ? state.selection : null;
}

/// Loads the session after sign-in / app start, keeps the showroom choice and
/// clears everything on sign-out.
@Riverpod(keepAlive: true)
class SessionController extends _$SessionController {
  @override
  Future<SessionState> build() async {
    final AuthRepository repository = ref.watch(authRepositoryProvider);
    final StreamSubscription<void> subscription = repository.signedOut.listen((_) {
      state = const AsyncData<SessionState>(SignedOut());
    });
    ref.onDispose(subscription.cancel);

    if (!repository.hasSession) {
      return const SignedOut();
    }
    return loadSession();
  }

  /// Signs in and loads the session. Throws an AppFailure with a user-safe
  /// message; the state stays [SignedOut] on failure.
  Future<void> signIn({required String email, required String password}) async {
    await ref.read(authRepositoryProvider).signIn(email: email, password: password);
    final SessionState next = await loadSession();
    state = AsyncData<SessionState>(next);
  }

  Future<void> signOut() async {
    state = const AsyncData<SessionState>(SignedOut());
    await ref.read(authRepositoryProvider).signOut();
  }

  /// Switches the working showroom (or ALL SHOWROOMS) and remembers it.
  Future<void> selectShowroom(ShowroomSelection selection) async {
    final SessionState? current = state.value;
    if (current is! SignedIn || current.session == null) {
      return;
    }
    final UserSession session = current.session!;
    final bool allowed = selection.isAll
        ? session.canViewAllShowrooms
        : session.showroomById(selection.showroomId!) != null;
    if (!allowed) {
      return;
    }
    state = AsyncData<SessionState>(SignedIn(session: session, selection: selection));
    await ref
        .read(preferenceStoreProvider)
        .writeString(StorageKeys.lastShowroomFor(session.profileId), selection.storageValue);
  }

  /// Reloads showrooms and permissions after an administrative change (a new
  /// or deactivated showroom). Keeps the current showroom while it is still
  /// available, otherwise falls back to the start-up rule.
  Future<void> refresh() async {
    final SessionState? current = state.value;
    if (current is! SignedIn) {
      return;
    }
    final UserSession? session = await ref.read(authRepositoryProvider).fetchSession();
    final ShowroomSelection? selection = current.selection;
    if (session == null || session.blockReason != null) {
      state = AsyncData<SessionState>(SignedIn(session: session));
      return;
    }
    final bool stillValid = selection != null &&
        (selection.isAll ? session.canViewAllShowrooms : session.showroomById(selection.showroomId!) != null);
    state = AsyncData<SessionState>(
      SignedIn(session: session, selection: stillValid ? selection : session.initialSelection(null)),
    );
  }

  /// Fetches profile, showrooms and permissions and restores the showroom.
  Future<SessionState> loadSession() async {
    final UserSession? session = await ref.read(authRepositoryProvider).fetchSession();
    if (session == null || session.blockReason != null) {
      return SignedIn(session: session);
    }
    final String? lastUsed = await ref
        .read(preferenceStoreProvider)
        .readString(StorageKeys.lastShowroomFor(session.profileId));
    return SignedIn(session: session, selection: session.initialSelection(lastUsed));
  }
}
