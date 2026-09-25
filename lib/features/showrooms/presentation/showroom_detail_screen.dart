import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/features/auth/application/session_controller.dart';
import 'package:mybike_showroom/features/showrooms/application/showrooms_controller.dart';
import 'package:mybike_showroom/features/showrooms/domain/showroom_admin.dart';
import 'package:mybike_showroom/features/showrooms/presentation/showroom_dialogs.dart';
import 'package:mybike_showroom/features/showrooms/presentation/showrooms_screen.dart';
import 'package:mybike_showroom/features/users/application/users_controller.dart';
import 'package:mybike_showroom/features/users/domain/user_admin.dart';
import 'package:mybike_showroom/features/users/presentation/users_screen.dart';

/// What the caller may do in one showroom (from the session; RLS decides).
@immutable
class ShowroomAccess {
  const ShowroomAccess({required this.canEdit, required this.canViewUsers, required this.canAssignUsers});

  factory ShowroomAccess.of(WidgetRef ref, String showroomId) {
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    bool can(String permission) => state is SignedIn && (state.session?.can(permission, showroomId) ?? false);
    return ShowroomAccess(
      canEdit: can('showrooms.edit'),
      canViewUsers: can('users.view'),
      canAssignUsers: can('users.edit'),
    );
  }

  final bool canEdit;
  final bool canViewUsers;
  final bool canAssignUsers;
}

/// One showroom: overview (profile + GST), settings, invoice numbering, bank
/// accounts and staff.
class ShowroomDetailScreen extends ConsumerWidget {
  const ShowroomDetailScreen({required this.showroomId, super.key});

  final String showroomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: AppAsyncView<Showroom?>(
          value: ref.watch(showroomProvider(showroomId)),
          onRetry: () => ref.invalidate(showroomProvider(showroomId)),
          data: (Showroom? showroom) => showroom == null
              ? AppEmptyState(
                  title: 'Showroom not found',
                  message: 'It does not exist, is inactive, or you are not assigned to it.',
                  icon: Icons.store_mall_directory_outlined,
                  actionText: 'Back to showrooms',
                  onAction: () => context.go(AppRoutes.showroomsPath),
                )
              : ShowroomDetailView(showroom: showroom),
        ),
      ),
    );
  }
}

class ShowroomDetailView extends ConsumerWidget {
  const ShowroomDetailView({required this.showroom, super.key});

  final Showroom showroom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ShowroomAccess access = ShowroomAccess.of(ref, showroom.id!);
    final List<Tab> tabs = <Tab>[
      const Tab(text: 'Overview'),
      const Tab(text: 'Settings'),
      const Tab(text: 'Invoice'),
      const Tab(text: 'Bank'),
      if (access.canViewUsers) const Tab(text: 'Users'),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: context.pagePadding.copyWith(bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextButton.icon(
                  onPressed: () => context.go(AppRoutes.showroomsPath),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Showrooms'),
                ),
                Wrap(
                  spacing: AppDimensions.space12,
                  runSpacing: AppDimensions.space8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(showroom.name, style: Theme.of(context).textTheme.headlineSmall),
                    ShowroomStatusBadge(isActive: showroom.isActive),
                  ],
                ),
                TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: tabs),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                ShowroomOverviewTab(showroom: showroom, access: access),
                ShowroomSettingsTab(showroomId: showroom.id!, access: access),
                ShowroomInvoiceTab(showroom: showroom, access: access),
                ShowroomBankTab(showroomId: showroom.id!, access: access),
                if (access.canViewUsers) ShowroomUsersTab(showroom: showroom, access: access),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrollable tab body.
class TabPage extends StatelessWidget {
  const TabPage({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(padding: context.pagePadding, children: children);
}

class ShowroomOverviewTab extends ConsumerWidget {
  const ShowroomOverviewTab({required this.showroom, required this.access, super.key});

  final Showroom showroom;
  final ShowroomAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ShowroomAdminActions actions = ref.read(showroomAdminActionsProvider);
    return TabPage(
      children: <Widget>[
        AppSectionHeader(
          title: 'Profile',
          trailing: access.canEdit
              ? AppOutlinedButton(
                  text: 'Edit',
                  icon: Icons.edit_outlined,
                  onPressed: () => ShowroomFormDialog.show(context, showroom: showroom),
                )
              : null,
        ),
        AppCard(
          child: Column(
            children: <Widget>[
              AppInfoRow(label: 'Code', value: showroom.code),
              AppInfoRow(label: 'Legal name', value: showroom.legalName),
              AppInfoRow(label: 'Address', value: showroom.address),
              AppInfoRow(label: 'Phone', value: showroom.phone),
              AppInfoRow(label: 'Email', value: showroom.email),
              AppInfoRow(label: 'Opened on', value: showroom.openedOn),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.space24),
        const AppSectionHeader(title: 'GST'),
        AppCard(
          child: Column(
            children: <Widget>[
              AppInfoRow(label: 'GSTIN', value: showroom.gstin),
              AppInfoRow(label: 'PAN', value: showroom.pan),
              AppInfoRow(label: 'State code', value: showroom.stateCode),
            ],
          ),
        ),
        if (access.canEdit) ...<Widget>[
          const SizedBox(height: AppDimensions.space24),
          Align(
            alignment: Alignment.centerLeft,
            child: showroom.isActive
                ? AppButton(
                    text: 'Deactivate showroom',
                    icon: Icons.block,
                    variant: AppButtonVariant.danger,
                    onPressed: () async {
                      final bool ok = await AppConfirmDialog.show(
                        context: context,
                        title: 'Deactivate ${showroom.name}?',
                        message: 'Its staff can no longer work in it and it leaves the showroom switcher. '
                            'Its records stay. Only the Super Admin can reactivate it.',
                        confirmLabel: 'Deactivate',
                        isDestructive: true,
                      );
                      if (ok && context.mounted) {
                        final bool done = await AppFeedback.run(
                          context,
                          () => actions.setActive(showroom.id!, active: false),
                          success: 'Showroom deactivated.',
                        );
                        if (done && context.mounted) {
                          context.go(AppRoutes.showroomsPath);
                        }
                      }
                    },
                  )
                : AppButton(
                    text: 'Activate showroom',
                    icon: Icons.check_circle_outline,
                    onPressed: () => AppFeedback.run(
                      context,
                      () => actions.setActive(showroom.id!, active: true),
                      success: 'Showroom activated.',
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

class ShowroomSettingsTab extends ConsumerWidget {
  const ShowroomSettingsTab({required this.showroomId, required this.access, super.key});

  final String showroomId;
  final ShowroomAccess access;

  static String yesNo(bool value) => value ? 'Yes' : 'No';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppAsyncView<ShowroomSettings>(
      value: ref.watch(showroomSettingsProvider(showroomId)),
      onRetry: () => ref.invalidate(showroomSettingsProvider(showroomId)),
      data: (ShowroomSettings s) => TabPage(
        children: <Widget>[
          AppSectionHeader(
            title: 'Sales, stock and accounting',
            trailing: access.canEdit
                ? AppOutlinedButton(
                    text: 'Edit',
                    icon: Icons.tune,
                    onPressed: () => ShowroomSettingsDialog.show(context, s),
                  )
                : null,
          ),
          AppCard(
            child: Column(
              children: <Widget>[
                AppInfoRow(label: 'GST registered', value: yesNo(s.gstEnabled)),
                AppInfoRow(label: 'Round invoice totals', value: yesNo(s.roundOffEnabled)),
                AppInfoRow(label: 'Minimum booking amount', value: '₹ ${s.bookingMinAmount}'),
                AppInfoRow(label: 'Booking validity', value: '${s.bookingValidityDays} days'),
                AppInfoRow(
                  label: 'Discount approval above',
                  value: s.discountApprovalThreshold == null ? 'Not required' : '₹ ${s.discountApprovalThreshold}',
                ),
                AppInfoRow(label: 'Low stock alert at', value: '${s.lowStockThreshold} units'),
                AppInfoRow(label: 'Allow selling below zero stock', value: yesNo(s.allowNegativeStock)),
                AppInfoRow(label: 'Stock valuation', value: ValuationMethods.labels[s.valuationMethod] ?? s.valuationMethod),
                AppInfoRow(label: 'Post cost of goods with every sale', value: yesNo(s.postCogsOnSale)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShowroomInvoiceTab extends ConsumerWidget {
  const ShowroomInvoiceTab({required this.showroom, required this.access, super.key});

  final Showroom showroom;
  final ShowroomAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String id = showroom.id!;
    final AsyncValue<ShowroomSettings> settings = ref.watch(showroomSettingsProvider(id));
    final AsyncValue<List<NumberingSeries>> series = ref.watch(numberingSeriesProvider(id));
    return TabPage(
      children: <Widget>[
        AppSectionHeader(
          title: 'Invoice texts',
          subtitle: 'Invoice prefix: ${showroom.invoicePrefix} (change it under Overview → Edit, until the first number is issued).',
          trailing: access.canEdit && settings.hasValue
              ? AppOutlinedButton(
                  text: 'Edit',
                  icon: Icons.edit_note,
                  onPressed: () => InvoiceTextsDialog.show(context, settings.value!),
                )
              : null,
        ),
        AppAsyncView<ShowroomSettings>(
          value: settings,
          data: (ShowroomSettings s) => AppCard(
            child: Column(
              children: <Widget>[
                AppInfoRow(label: 'Invoice terms', value: s.invoiceTerms),
                AppInfoRow(label: 'Invoice footer', value: s.invoiceFooter),
                AppInfoRow(label: 'Receipt terms', value: s.receiptTerms),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.space24),
        const AppSectionHeader(
          title: 'Document numbering',
          subtitle: 'Next number per document type. Numbers are issued by the server and never reused.',
        ),
        AppAsyncView<List<NumberingSeries>>(
          value: series,
          onRetry: () => ref.invalidate(numberingSeriesProvider(id)),
          data: (List<NumberingSeries> list) => AppCard(
            child: Column(
              children: <Widget>[
                if (list.isEmpty) const Text('Numbering is created with the financial year.'),
                for (final NumberingSeries s in list) AppInfoRow(label: '${s.label} · ${s.financialYear}', value: s.preview),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ShowroomBankTab extends ConsumerWidget {
  const ShowroomBankTab({required this.showroomId, required this.access, super.key});

  final String showroomId;
  final ShowroomAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    return AppAsyncView<List<BankAccount>>(
      value: ref.watch(bankAccountsProvider(showroomId)),
      onRetry: () => ref.invalidate(bankAccountsProvider(showroomId)),
      data: (List<BankAccount> accounts) => TabPage(
        children: <Widget>[
          AppSectionHeader(
            title: 'Bank accounts',
            subtitle: 'The default account is printed on invoices.',
            trailing: access.canEdit
                ? AppOutlinedButton(
                    text: 'Add account',
                    icon: Icons.add_card,
                    onPressed: () => BankAccountDialog.show(context, showroomId: showroomId),
                  )
                : null,
          ),
          if (accounts.isEmpty) const AppEmptyState(title: 'No bank account yet', icon: Icons.account_balance_outlined),
          for (final BankAccount a in accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space8),
              child: AppCard(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: AppDimensions.space8,
                            children: <Widget>[
                              Text(a.bankName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (a.isDefault) const AppStatusBadge(label: 'On invoices', intent: AppStatusIntent.info),
                            ],
                          ),
                          Text(
                            '${a.accountName} · ${a.maskedNumber} · ${a.ifsc}${a.upiId == null ? '' : ' · ${a.upiId}'}',
                            style: TextStyle(color: palette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (access.canEdit) ...<Widget>[
                      IconButton(
                        tooltip: 'Edit account',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => BankAccountDialog.show(context, showroomId: showroomId, account: a),
                      ),
                      IconButton(
                        tooltip: 'Remove account',
                        icon: Icon(Icons.delete_outline, color: palette.danger),
                        onPressed: () async {
                          final bool ok = await AppConfirmDialog.show(
                            context: context,
                            title: 'Remove ${a.bankName} ${a.maskedNumber}?',
                            message: 'An account already used in payments cannot be removed.',
                            confirmLabel: 'Remove',
                            isDestructive: true,
                          );
                          if (ok && context.mounted) {
                            await AppFeedback.run(
                              context,
                              () => ref.read(showroomAdminActionsProvider).deleteBankAccount(a),
                              success: 'Bank account removed.',
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Staff of the showroom; roles are managed on each user's page.
class ShowroomUsersTab extends ConsumerWidget {
  const ShowroomUsersTab({required this.showroom, required this.access, super.key});

  final Showroom showroom;
  final ShowroomAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UsersQuery query = UsersQuery(showroomId: showroom.id, pageSize: 100);
    return AppAsyncView<UsersPage>(
      value: ref.watch(usersPageProvider(query)),
      onRetry: () => ref.invalidate(usersPageProvider(query)),
      data: (UsersPage page) => TabPage(
        children: <Widget>[
          AppSectionHeader(
            title: 'Staff',
            subtitle: '${page.total} user(s) work here. Open a user to change their roles.',
            trailing: access.canAssignUsers
                ? AppOutlinedButton(
                    text: 'Assign user',
                    icon: Icons.person_add_alt,
                    onPressed: () => AssignUserDialog.show(context, showroomId: showroom.id!, showroomName: showroom.name),
                  )
                : null,
          ),
          if (page.items.isEmpty) const AppEmptyState(title: 'Nobody is assigned yet', icon: Icons.groups_outlined),
          for (final ManagedUser user in page.items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space8),
              child: AppCard(
                onTap: () => context.go(AppRoutes.userDetailPath(user.id)),
                child: UserSummaryTile(user: user),
              ),
            ),
        ],
      ),
    );
  }
}
