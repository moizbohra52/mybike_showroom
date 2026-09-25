import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/features/showrooms/application/showrooms_controller.dart';
import 'package:mybike_showroom/features/showrooms/domain/showroom_admin.dart';
import 'package:mybike_showroom/features/showrooms/presentation/showroom_dialogs.dart';

/// Showrooms the caller can access (the owner also sees inactive ones).
class ShowroomsScreen extends ConsumerWidget {
  const ShowroomsScreen({super.key});

  static const String createPermission = 'showrooms.create';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Showroom>> showrooms = ref.watch(showroomListProvider);
    void open(Showroom s) => context.go(AppRoutes.showroomDetailPath(s.id!));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: context.pagePadding,
          children: <Widget>[
            AppSectionHeader(
              title: 'Showrooms',
              subtitle: 'Profile, GST, invoice numbering, bank details and staff of each showroom.',
              trailing: AppPermissionWidget(
                permission: createPermission,
                child: AppButton(
                  text: 'New showroom',
                  icon: Icons.add_business_outlined,
                  onPressed: () async {
                    final String? id = await ShowroomFormDialog.show(context);
                    if (id != null && context.mounted) {
                      context.go(AppRoutes.showroomDetailPath(id));
                    }
                  },
                ),
              ),
            ),
            AppAsyncView<List<Showroom>>(
              value: showrooms,
              onRetry: () => ref.invalidate(showroomListProvider),
              data: (List<Showroom> list) => context.isCompactLayout
                  ? Column(
                      children: <Widget>[
                        for (final Showroom s in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                            child: AppCard(onTap: () => open(s), child: ShowroomSummary(showroom: s)),
                          ),
                      ],
                    )
                  : AppDataTable<Showroom>(
                      items: list,
                      onRowTap: open,
                      emptyMessage: 'No showrooms',
                      columns: <AppDataTableColumn<Showroom>>[
                        AppDataTableColumn<Showroom>(title: 'Showroom', flex: 3, cellBuilder: (_, Showroom s) => ShowroomSummary(showroom: s)),
                        AppDataTableColumn<Showroom>(title: 'City', flex: 2, cellBuilder: (_, Showroom s) => Text(s.city ?? '—')),
                        AppDataTableColumn<Showroom>(title: 'GSTIN', flex: 2, cellBuilder: (_, Showroom s) => Text(s.gstin ?? '—')),
                        AppDataTableColumn<Showroom>(title: 'Prefix', cellBuilder: (_, Showroom s) => Text(s.invoicePrefix)),
                        AppDataTableColumn<Showroom>(title: 'Status', cellBuilder: (_, Showroom s) => ShowroomStatusBadge(isActive: s.isActive)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShowroomSummary extends StatelessWidget {
  const ShowroomSummary({required this.showroom, super.key});

  final Showroom showroom;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final bool compact = context.isCompactLayout;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(showroom.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              Text(
                compact ? '${showroom.code} · ${showroom.city ?? ''}' : showroom.code,
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (compact) ShowroomStatusBadge(isActive: showroom.isActive),
      ],
    );
  }
}

class ShowroomStatusBadge extends StatelessWidget {
  const ShowroomStatusBadge({required this.isActive, super.key});

  final bool isActive;

  @override
  Widget build(BuildContext context) => AppStatusBadge(
        label: isActive ? 'Active' : 'Inactive',
        intent: isActive ? AppStatusIntent.success : AppStatusIntent.warning,
      );
}
