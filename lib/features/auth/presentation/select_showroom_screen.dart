import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/widgets/app_outlined_button.dart';
import 'package:mybike_showroom/core/constants/app_strings.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/features/auth/application/session_controller.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';
import 'package:mybike_showroom/features/auth/presentation/auth_card_layout.dart';

/// Showroom picker after login (multi-showroom users) and the target of the
/// header's showroom switcher.
class SelectShowroomScreen extends ConsumerWidget {
  const SelectShowroomScreen({super.key});

  Future<void> choose(BuildContext context, WidgetRef ref, ShowroomSelection selection) async {
    await ref.read(sessionControllerProvider.notifier).selectShowroom(selection);
    if (context.mounted) {
      context.go(AppRoutes.dashboardPath);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    final SignedIn? signedIn = state is SignedIn ? state : null;
    final UserSession? session = signedIn?.session;
    final AppPalette palette = AppPalette.of(context);

    return AuthCardLayout(
      children: <Widget>[
        Text('Choose a showroom', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppDimensions.space4),
        Text(
          'Data, reports and documents follow the showroom you pick.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppDimensions.space16),
        if (session != null && session.canViewAllShowrooms)
          ListTile(
            leading: const Icon(Icons.store_mall_directory_outlined),
            title: const Text(AppStrings.allShowrooms),
            subtitle: const Text('Consolidated view'),
            selected: signedIn!.selection?.isAll ?? false,
            onTap: () => choose(context, ref, const ShowroomSelection.all()),
          ),
        for (final SessionShowroom showroom in session?.showrooms ?? const <SessionShowroom>[])
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: Text(showroom.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(showroom.code, maxLines: 1, overflow: TextOverflow.ellipsis),
            selected: signedIn!.selection?.showroomId == showroom.id,
            onTap: () => choose(context, ref, ShowroomSelection.showroom(showroom.id)),
          ),
        const SizedBox(height: AppDimensions.space16),
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
