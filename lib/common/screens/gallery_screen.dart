import 'package:flutter/material.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/constants/module_keys.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';

/// Phase 2 component gallery — every widget in the MyBike design system
/// displayed in one scrollable screen.
///
/// This screen serves as:
/// - A visual regression baseline (render light + dark, mobile + desktop).
/// - An interactive playground for designers and developers.
/// - The Phase 2 exit-criteria artefact confirming all components render.
///
/// Route: `/gallery` (registered directly in [AppRouter], outside the shell
/// so the sidebar does not appear and the gallery fills the viewport).
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

// ── Sample invoice type used by the data-table section ──────────────────────

class _Invoice {
  const _Invoice({
    required this.number,
    required this.customer,
    required this.amount,
    required this.status,
  });
  final String number;
  final String customer;
  final int amount;
  final String status;
}

final List<_Invoice> _sampleInvoices = List<_Invoice>.generate(
  6,
  (int i) => _Invoice(
    number: 'INV-2024-${1000 + i}',
    customer: 'Customer ${i + 1}',
    amount: 45000 + i * 7500,
    status: i.isEven ? 'Paid' : 'Pending',
  ),
);

// ── Gallery state ────────────────────────────────────────────────────────────

class _GalleryScreenState extends State<GalleryScreen> {
  String _searchText = '';
  String? _dropdownValue;
  bool _loading = false;
  int _page = 1;

  static const List<AppDropdownItem<String>> _dropdownItems =
      <AppDropdownItem<String>>[
    AppDropdownItem(value: 'honda', label: 'Honda'),
    AppDropdownItem(value: 'yamaha', label: 'Yamaha'),
    AppDropdownItem(value: 'hero', label: 'Hero'),
    AppDropdownItem(value: 'tvs', label: 'TVS'),
    AppDropdownItem(
      value: 'royal_enfield',
      label: 'Royal Enfield',
      icon: Icons.two_wheeler_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phase 2 Design System Gallery'),
        backgroundColor: palette.headerBackground,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: palette.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Stat Cards ─────────────────────────────────────────────
            _GallerySection(
              title: 'AppStatCard',
              child: Wrap(
                spacing: AppDimensions.space16,
                runSpacing: AppDimensions.space16,
                children: <Widget>[
                  SizedBox(
                    width: 260,
                    child: AppStatCard(
                      label: "Today's Sales",
                      value: '₹ 4,85,000',
                      icon: Icons.payments_outlined,
                      deltaText: '+14.2%',
                      deltaPositive: true,
                      onTap: () {},
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: AppStatCard(
                      label: 'Stock Value',
                      value: '₹ 1.45 Cr',
                      icon: Icons.two_wheeler_outlined,
                      deltaText: '28 Units',
                      deltaPositive: true,
                      onTap: () {},
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: AppStatCard(
                      label: 'Pending Payables',
                      value: '₹ 2,10,000',
                      icon: Icons.account_balance_wallet_outlined,
                      deltaText: '-6.3%',
                      deltaPositive: false,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),

            // ── Dashboard Card ──────────────────────────────────────────
            _GallerySection(
              title: 'AppDashboardCard',
              child: Wrap(
                spacing: AppDimensions.space16,
                runSpacing: AppDimensions.space16,
                children: <Widget>[
                  SizedBox(
                    width: 300,
                    child: AppDashboardCard(
                      title: 'Monthly Revenue',
                      subtitle: 'September 2024',
                      icon: Icons.bar_chart_outlined,
                      onTap: () {},
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: AppDashboardCard(
                      title: 'Stock Status',
                      subtitle: '28 units in 3 showrooms',
                      icon: Icons.inventory_2_outlined,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),

            // ── Status Badges ───────────────────────────────────────────
            _GallerySection(
              title: 'AppStatusBadge',
              child: Wrap(
                spacing: AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: const <Widget>[
                  AppStatusBadge.fromKey(statusKey: 'Available'),
                  AppStatusBadge.fromKey(statusKey: 'In Stock'),
                  AppStatusBadge.fromKey(statusKey: 'Low Stock'),
                  AppStatusBadge.fromKey(statusKey: 'Out of Stock'),
                  AppStatusBadge.fromKey(statusKey: 'Delivered'),
                  AppStatusBadge.fromKey(statusKey: 'Pending'),
                  AppStatusBadge.fromKey(statusKey: 'Cancelled'),
                  AppStatusBadge.fromKey(statusKey: 'Draft'),
                  AppStatusBadge.fromKey(statusKey: 'Booked'),
                  AppStatusBadge.fromKey(statusKey: 'Sold'),
                  AppStatusBadge.fromKey(statusKey: 'Transferred'),
                  AppStatusBadge.fromKey(statusKey: 'Paid'),
                  AppStatusBadge.fromKey(statusKey: 'Unpaid'),
                  AppStatusBadge.fromKey(statusKey: 'Overdue'),
                  AppStatusBadge.fromKey(statusKey: 'Approved'),
                  AppStatusBadge.fromKey(statusKey: 'Rejected'),
                ],
              ),
            ),

            // ── Buttons ─────────────────────────────────────────────────
            _GallerySection(
              title: 'AppButton & AppOutlinedButton',
              child: Wrap(
                spacing: AppDimensions.space12,
                runSpacing: AppDimensions.space12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  AppButton(
                    text: 'Primary',
                    icon: Icons.add,
                    onPressed: () {},
                  ),
                  AppButton(
                    text: 'Primary Lg',
                    size: AppButtonSize.lg,
                    icon: Icons.arrow_forward,
                    onPressed: () {},
                  ),
                  AppButton(
                    text: 'Primary Sm',
                    size: AppButtonSize.sm,
                    onPressed: () {},
                  ),
                  AppButton(
                    text: 'Danger',
                    variant: AppButtonVariant.danger,
                    icon: Icons.delete_outline,
                    onPressed: () {},
                  ),
                  AppButton(
                    text: _loading ? 'Saving…' : 'Toggle Loading',
                    loading: _loading,
                    onPressed: () => setState(() => _loading = !_loading),
                  ),
                  const AppButton(
                    text: 'Disabled',
                  ),
                  AppOutlinedButton(
                    text: 'Outlined',
                    icon: Icons.tune,
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // ── Currency Text ───────────────────────────────────────────
            _GallerySection(
              title: 'AppCurrencyText',
              child: const Wrap(
                spacing: AppDimensions.space24,
                runSpacing: AppDimensions.space8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  AppCurrencyText(1234567.89),
                  AppCurrencyText(1234567.89, large: true),
                  AppCurrencyText(0),
                  AppCurrencyText(-49999),
                ],
              ),
            ),

            // ── Cards ───────────────────────────────────────────────────
            _GallerySection(
              title: 'AppCard',
              child: Wrap(
                spacing: AppDimensions.space16,
                runSpacing: AppDimensions.space16,
                children: <Widget>[
                  SizedBox(
                    width: 260,
                    child: AppCard(
                      onTap: () {},
                      child: const Padding(
                        padding: EdgeInsets.all(AppDimensions.space16),
                        child: Text('Tappable card content'),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 260,
                    child: AppCard(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.space16),
                        child: Text('Non-tappable card'),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Text Fields ─────────────────────────────────────────────
            _GallerySection(
              title: 'AppTextField',
              child: const Wrap(
                spacing: AppDimensions.space16,
                runSpacing: AppDimensions.space16,
                children: <Widget>[
                  SizedBox(
                    width: 300,
                    child: AppTextField(
                      label: 'Customer Name',
                      hint: 'Enter full name',
                      prefixIcon: Icons.person_outline,
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: AppTextField(
                      label: 'Mobile Number',
                      hint: '10-digit number',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: AppTextField(
                      label: 'Password',
                      hint: 'Enter password',
                      prefixIcon: Icons.lock_outline,
                      obscureText: true,
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: AppTextField(
                      label: 'Disabled Field',
                      hint: 'Cannot edit',
                      enabled: false,
                    ),
                  ),
                ],
              ),
            ),

            // ── Search Field ────────────────────────────────────────────
            _GallerySection(
              title: 'AppSearchField',
              child: SizedBox(
                width: 380,
                child: AppSearchField(
                  hint: 'Search vehicles, VIN, customer…',
                  onChanged: (String v) => setState(() => _searchText = v),
                ),
              ),
            ),
            if (_searchText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: AppDimensions.space16,
                  left: AppDimensions.space4,
                ),
                child: Text('Searching: "$_searchText"'),
              ),

            // ── Dropdown ────────────────────────────────────────────────
            _GallerySection(
              title: 'AppDropdown',
              child: SizedBox(
                width: 300,
                child: AppDropdown<String>(
                  label: 'Brand',
                  hint: 'Select brand',
                  value: _dropdownValue,
                  items: _dropdownItems,
                  onChanged: (String? v) => setState(() => _dropdownValue = v),
                ),
              ),
            ),

            // ── Data Table ──────────────────────────────────────────────
            _GallerySection(
              title: 'AppDataTable',
              child: AppDataTable<_Invoice>(
                columns: <AppDataTableColumn<_Invoice>>[
                  AppDataTableColumn<_Invoice>(
                    title: 'Invoice',
                    flex: 2,
                    cellBuilder: (_, _Invoice i) => Text(i.number),
                  ),
                  AppDataTableColumn<_Invoice>(
                    title: 'Customer',
                    flex: 2,
                    cellBuilder: (_, _Invoice i) => Text(i.customer),
                  ),
                  AppDataTableColumn<_Invoice>(
                    title: 'Amount',
                    flex: 2,
                    isNumeric: true,
                    cellBuilder: (_, _Invoice i) =>
                        AppCurrencyText(i.amount.toDouble()),
                  ),
                  AppDataTableColumn<_Invoice>(
                    title: 'Status',
                    flex: 1,
                    cellBuilder: (_, _Invoice i) =>
                        AppStatusBadge.fromKey(statusKey: i.status),
                  ),
                ],
                items: _sampleInvoices,
                onRowTap: (_) {},
              ),
            ),

            // ── Pagination ──────────────────────────────────────────────
            _GallerySection(
              title: 'AppPagination',
              child: AppPagination(
                currentPage: _page,
                totalPages: 8,
                onPageChanged: (int p) => setState(() => _page = p),
              ),
            ),

            // ── Loading / Shimmer ───────────────────────────────────────
            _GallerySection(
              title: 'AppLoading & AppShimmer',
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppLoading(),
                  SizedBox(height: AppDimensions.space16),
                  AppShimmer.line(width: 280),
                  SizedBox(height: AppDimensions.space8),
                  AppShimmer.line(width: 180),
                  SizedBox(height: AppDimensions.space8),
                  AppShimmer.card(width: 280, height: 80),
                ],
              ),
            ),

            // ── Empty / Error States ────────────────────────────────────
            _GallerySection(
              title: 'AppEmptyState & AppErrorState',
              child: Column(
                children: <Widget>[
                  AppEmptyState(
                    title: 'No Vehicles Found',
                    message: 'Add stock to get started.',
                    actionText: 'Add Vehicle',
                    onAction: () {},
                  ),
                  const SizedBox(height: AppDimensions.space24),
                  AppErrorState(
                    title: 'Something went wrong',
                    message: 'Could not load invoices. Check your connection.',
                    onRetry: () {},
                  ),
                ],
              ),
            ),

            // ── Form Section / Section Header ────────────────────────────
            const _GallerySection(
              title: 'AppFormSection & AppSectionHeader',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppSectionHeader(
                    title: 'Customer Details',
                    subtitle: 'Contact and identification information',
                  ),
                  SizedBox(height: AppDimensions.space12),
                  AppFormSection(
                    title: 'Personal Information',
                    children: <Widget>[
                      AppTextField(
                        label: 'Full Name',
                        hint: 'Enter full name',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── AppPermissionWidget ─────────────────────────────────────
            _GallerySection(
              title: 'AppPermissionWidget',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // null permissions → permissive (Phase 2 default)
                  AppPermissionWidget(
                    permission: ModuleKeys.sales,
                    child: AppButton(
                      text: 'Visible (null permissions — permissive)',
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  // has permission
                  AppPermissionWidget(
                    permission: ModuleKeys.sales,
                    permissions: const <String>{ModuleKeys.sales},
                    child: AppButton(
                      text: 'Visible (has permission)',
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  // no permission → fallback
                  AppPermissionWidget(
                    permission: ModuleKeys.sales,
                    permissions: const <String>{ModuleKeys.inventory},
                    fallback: Builder(
                      builder: (BuildContext ctx) {
                        final AppPalette p = AppPalette.of(ctx);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.space12,
                            vertical: AppDimensions.space8,
                          ),
                          decoration: BoxDecoration(
                            color: p.dangerSoft,
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                          child: Text(
                            'Hidden (no permission) — fallback shown',
                            style: TextStyle(color: p.danger),
                          ),
                        );
                      },
                    ),
                    child: const SizedBox.shrink(),
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  // no permission + no fallback → invisible
                  const AppPermissionWidget(
                    permission: ModuleKeys.accounting,
                    permissions: <String>{ModuleKeys.inventory},
                    child: SizedBox(
                      height: 40,
                      child: Center(child: Text('Never seen')),
                    ),
                  ),
                  Builder(
                    builder: (BuildContext ctx) => Text(
                      '↑ Nothing rendered above (no permission, no fallback)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppPalette.of(ctx).textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.space40),
          ],
        ),
      ),
    );
  }
}

/// Section wrapper with a title divider above each gallery group.
class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(child: Divider(color: palette.border)),
          ],
        ),
        const SizedBox(height: AppDimensions.space16),
        child,
        const SizedBox(height: AppDimensions.space32),
      ],
    );
  }
}
