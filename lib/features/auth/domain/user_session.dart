import 'package:flutter/foundation.dart';

/// Why a signed-in user cannot enter the app.
enum SessionBlockReason {
  /// The JWT has no `profiles` row.
  noProfile,

  /// `profiles.status` is not active.
  deactivated,

  /// No accessible showroom (and no ALL SHOWROOMS permission).
  noShowroom,
}

/// A showroom the user can work in, with the effective permissions there.
@immutable
class SessionShowroom {
  const SessionShowroom({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    required this.isDefault,
    required this.roles,
    required this.permissions,
  });

  factory SessionShowroom.fromJson(Map<String, Object?> json) {
    return SessionShowroom(
      id: json['id']! as String,
      code: json['code']! as String,
      name: json['name']! as String,
      isActive: json['is_active'] as bool? ?? true,
      isDefault: json['is_default'] as bool? ?? false,
      roles: stringList(json['roles']),
      permissions: stringList(json['permissions']).toSet(),
    );
  }

  final String id;
  final String code;
  final String name;
  final bool isActive;
  final bool isDefault;
  final List<String> roles;
  final Set<String> permissions;
}

/// What `rpc_get_my_session()` returned for the signed-in user.
///
/// Display and navigation only — RLS decides what data is actually visible.
@immutable
class UserSession {
  const UserSession({
    required this.profileId,
    required this.fullName,
    required this.email,
    required this.isActive,
    required this.isSuperAdmin,
    required this.globalPermissions,
    required this.showrooms,
  });

  factory UserSession.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> profile = (json['profile']! as Map<Object?, Object?>).cast<String, Object?>();
    return UserSession(
      profileId: profile['id']! as String,
      fullName: profile['full_name'] as String? ?? '',
      email: profile['email'] as String?,
      isActive: profile['is_active'] as bool? ?? false,
      isSuperAdmin: json['is_super_admin'] as bool? ?? false,
      globalPermissions: stringList(json['global_permissions']).toSet(),
      showrooms: <SessionShowroom>[
        for (final Object? item in (json['showrooms'] as List<Object?>?) ?? const <Object?>[])
          SessionShowroom.fromJson((item! as Map<Object?, Object?>).cast<String, Object?>()),
      ],
    );
  }

  final String profileId;
  final String fullName;
  final String? email;
  final bool isActive;
  final bool isSuperAdmin;
  final Set<String> globalPermissions;
  final List<SessionShowroom> showrooms;

  static const String viewAllPermission = 'showrooms.view_all';

  bool get canViewAllShowrooms => globalPermissions.contains(viewAllPermission);

  SessionBlockReason? get blockReason {
    if (!isActive) {
      return SessionBlockReason.deactivated;
    }
    if (showrooms.isEmpty && !canViewAllShowrooms) {
      return SessionBlockReason.noShowroom;
    }
    return null;
  }

  SessionShowroom? showroomById(String id) {
    for (final SessionShowroom showroom in showrooms) {
      if (showroom.id == id) {
        return showroom;
      }
    }
    return null;
  }

  /// Showroom to open without asking: the only one, else the last used (if
  /// still accessible). `null` = the user must choose.
  ShowroomSelection? initialSelection(String? lastUsed) {
    if (showrooms.length == 1) {
      return ShowroomSelection.showroom(showrooms.single.id);
    }
    if (lastUsed == ShowroomSelection.allSentinel && canViewAllShowrooms) {
      return const ShowroomSelection.all();
    }
    if (lastUsed != null && showroomById(lastUsed) != null) {
      return ShowroomSelection.showroom(lastUsed);
    }
    return null;
  }

  /// Whether [permission] applies in [showroomId]: granted there or globally
  /// (global roles apply in every showroom). UI hint only.
  bool can(String permission, String showroomId) =>
      globalPermissions.contains(permission) || (showroomById(showroomId)?.permissions.contains(permission) ?? false);

  /// Permissions in effect for [selection]: the showroom's, or the global set
  /// in ALL SHOWROOMS mode.
  Set<String> permissionsFor(ShowroomSelection selection) {
    if (selection.isAll) {
      return globalPermissions;
    }
    return showroomById(selection.showroomId!)?.permissions ?? const <String>{};
  }
}

/// The current working context: one showroom, or ALL SHOWROOMS.
@immutable
class ShowroomSelection {
  const ShowroomSelection.showroom(String this.showroomId);

  const ShowroomSelection.all() : showroomId = null;

  /// Stored in preferences for ALL SHOWROOMS (same as StorageKeys.allShowroomsSentinel).
  static const String allSentinel = 'all';

  final String? showroomId;

  bool get isAll => showroomId == null;

  String get storageValue => showroomId ?? allSentinel;

  @override
  bool operator ==(Object other) => other is ShowroomSelection && other.showroomId == showroomId;

  @override
  int get hashCode => showroomId.hashCode;
}

/// JSON array of strings → `List<String>` (null → empty).
List<String> stringList(Object? value) {
  return <String>[for (final Object? item in (value as List<Object?>?) ?? const <Object?>[]) item! as String];
}
