import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/features/auth/application/session_controller.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';
import 'package:mybike_showroom/features/users/application/users_controller.dart';
import 'package:mybike_showroom/features/users/domain/user_admin.dart';
import 'package:mybike_showroom/features/users/presentation/user_dialogs.dart';

/// Users list: search, showroom and status filters, paging. RLS limits the
/// rows to users the caller may see; the showroom filter starts at the
/// current showroom.
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  static const String createPermission = 'users.create';

  @override
  ConsumerState<UsersScreen> createState() => UsersScreenState();
}

class UsersScreenState extends ConsumerState<UsersScreen> {
  late UsersQuery query;

  @override
  void initState() {
    super.initState();
    final SessionState? state = ref.read(sessionControllerProvider).value;
    query = UsersQuery(showroomId: state is SignedIn ? state.selection?.showroomId : null);
  }

  void update(UsersQuery next) => setState(() => query = next);

  Future<void> openCreate() async {
    final String? id = await CreateUserDialog.show(context);
    if (id != null && mounted) {
      context.go(AppRoutes.userDetailPath(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    final List<SessionShowroom> showrooms =
        state is SignedIn ? state.session?.showrooms ?? const <SessionShowroom>[] : const <SessionShowroom>[];
    final AsyncValue<UsersPage> page = ref.watch(usersPageProvider(query));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: context.pagePadding,
          children: <Widget>[
            AppSectionHeader(
              title: 'Users',
              subtitle: 'People who can sign in, their showrooms and roles.',
              trailing: AppPermissionWidget(
                permission: UsersScreen.createPermission,
                child: AppButton(text: 'New user', icon: Icons.person_add_alt_1, onPressed: openCreate),
              ),
            ),
            Wrap(
              spacing: AppDimensions.space12,
              runSpacing: AppDimensions.space12,
              children: <Widget>[
                SizedBox(
                  width: 320,
                  child: AppSearchField(
                    hint: 'Search name, email or employee code',
                    onSubmitted: (String value) => update(query.copyWith(search: value, page: 1)),
                    onClear: () => update(query.copyWith(search: '', page: 1)),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: AppDropdown<String?>(
                    label: 'Showroom',
                    value: query.showroomId,
                    items: <AppDropdownItem<String?>>[
                      const AppDropdownItem<String?>(value: null, label: 'All I can see'),
                      for (final SessionShowroom s in showrooms) AppDropdownItem<String?>(value: s.id, label: s.name),
                    ],
                    onChanged: (String? id) => update(query.copyWith(showroomId: () => id, page: 1)),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: AppDropdown<String?>(
                    label: 'Status',
                    value: query.status,
                    items: <AppDropdownItem<String?>>[
                      const AppDropdownItem<String?>(value: null, label: 'Any status'),
                      for (final String s in UserStatuses.all) AppDropdownItem<String?>(value: s, label: UserStatuses.label(s)),
                    ],
                    onChanged: (String? s) => update(query.copyWith(status: () => s, page: 1)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space16),
            AppAsyncView<UsersPage>(
              value: page,
              onRetry: () => ref.invalidate(usersPageProvider(query)),
              data: (UsersPage data) => UsersList(
                page: data,
                query: query,
                onPage: (int p) => update(query.copyWith(page: p)),
                onOpen: (ManagedUser user) => context.go(AppRoutes.userDetailPath(user.id)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Table on tablet/desktop, cards on phones.
class UsersList extends StatelessWidget {
  const UsersList({required this.page, required this.query, required this.onPage, required this.onOpen, super.key});

  final UsersPage page;
  final UsersQuery query;
  final ValueChanged<int> onPage;
  final ValueChanged<ManagedUser> onOpen;

  @override
  Widget build(BuildContext context) {
    final int totalPages = (page.total / query.pageSize).ceil();
    final Widget pagination = AppPagination(
      currentPage: query.page,
      totalPages: totalPages < 1 ? 1 : totalPages,
      totalItems: page.total,
      itemsPerPage: query.pageSize,
      onPageChanged: onPage,
    );
    if (page.items.isEmpty) {
      return const AppEmptyState(title: 'No users found', icon: Icons.person_search_outlined);
    }
    if (context.isCompactLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ManagedUser user in page.items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space8),
              child: AppCard(
                onTap: () => onOpen(user),
                child: UserSummaryTile(user: user),
              ),
            ),
          pagination,
        ],
      );
    }
    return AppDataTable<ManagedUser>(
      items: page.items,
      onRowTap: onOpen,
      pagination: pagination,
      columns: <AppDataTableColumn<ManagedUser>>[
        AppDataTableColumn<ManagedUser>(
          title: 'Name',
          flex: 3,
          cellBuilder: (_, ManagedUser u) => UserNameCell(user: u),
        ),
        AppDataTableColumn<ManagedUser>(title: 'Code', cellBuilder: (_, ManagedUser u) => Text(u.employeeCode ?? '—')),
        AppDataTableColumn<ManagedUser>(
          title: 'Roles',
          flex: 3,
          cellBuilder: (_, ManagedUser u) =>
              Text(u.roleNames.isEmpty ? 'No role' : u.roleNames.join(', '), overflow: TextOverflow.ellipsis),
        ),
        AppDataTableColumn<ManagedUser>(title: 'Status', cellBuilder: (_, ManagedUser u) => UserStatusBadge(status: u.status)),
      ],
    );
  }
}

class UserNameCell extends StatelessWidget {
  const UserNameCell({required this.user, super.key});

  final ManagedUser user;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(user.fullName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (user.email != null)
          Text(user.email!, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class UserSummaryTile extends StatelessWidget {
  const UserSummaryTile({required this.user, super.key});

  final ManagedUser user;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              UserNameCell(user: user),
              const SizedBox(height: AppDimensions.space4),
              Text(
                user.roleNames.isEmpty ? 'No role' : user.roleNames.join(', '),
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        UserStatusBadge(status: user.status),
      ],
    );
  }
}

class UserStatusBadge extends StatelessWidget {
  const UserStatusBadge({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    return AppStatusBadge(
      label: UserStatuses.label(status),
      intent: switch (status) {
        UserStatuses.active => AppStatusIntent.success,
        UserStatuses.suspended => AppStatusIntent.warning,
        UserStatuses.deactivated => AppStatusIntent.danger,
        _ => AppStatusIntent.neutral,
      },
    );
  }
}
