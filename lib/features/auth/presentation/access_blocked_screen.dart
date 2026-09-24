import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/widgets/app_button.dart';
import 'package:mybike_showroom/common/widgets/app_outlined_button.dart';
import 'package:mybike_showroom/core/constants/app_strings.dart';
import 'package:mybike_showroom/core/errors/app_failure.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/features/auth/application/session_controller.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';
import 'package:mybike_showroom/features/auth/presentation/auth_card_layout.dart';

/// Signed in but not allowed in: deactivated, no profile, no showroom — or,
/// with [forbidden], a module the current role cannot open.
class AccessBlockedScreen extends ConsumerWidget {
  const AccessBlockedScreen({this.forbidden = false, super.key});

  final bool forbidden;

  static String messageFor(SessionBlockReason? reason) => switch (reason) {
    SessionBlockReason.deactivated => FailureMessages.accountDisabled,
    SessionBlockReason.noShowroom =>
      'No showroom is assigned to your account yet. Contact your administrator.',
    SessionBlockReason.noProfile =>
      'Your account is not set up in MyBike yet. Contact your administrator.',
    null => FailureMessages.permission,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    final SessionBlockReason? reason = forbidden || state is! SignedIn ? null : state.blockReason;
    final AppPalette palette = AppPalette.of(context);

    return AuthCardLayout(
      children: <Widget>[
        Icon(forbidden ? Icons.lock_outline : Icons.block, size: AppDimensions.iconXl, color: palette.danger),
        const SizedBox(height: AppDimensions.space16),
        Text(
          forbidden ? 'Access denied' : 'Access unavailable',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppDimensions.space8),
        Text(
          messageFor(reason),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppDimensions.space24),
        if (forbidden) ...<Widget>[
          AppButton(text: 'Back to dashboard', expanded: true, onPressed: () => context.go(AppRoutes.dashboardPath)),
          const SizedBox(height: AppDimensions.space12),
        ],
        AppOutlinedButton(
          text: AppStrings.signOut,
          icon: Icons.logout,
          expanded: true,
          onPressed: () => ref.read(sessionControllerProvider.notifier).signOut(),
        ),
      ],
    );
  }
}
