import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/features/auth/application/session_controller.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';
import 'package:mybike_showroom/features/inventory/application/inventory_controller.dart';
import 'package:mybike_showroom/features/inventory/domain/stock.dart';
import 'package:mybike_showroom/features/inventory/presentation/stock_transfer_dialogs.dart';

/// Stock summary, transfers and adjustments across the showrooms the caller
/// can access.
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: context.pagePadding.copyWith(bottom: 0),
                child: const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: <Tab>[Tab(text: 'Overview'), Tab(text: 'Transfers'), Tab(text: 'Adjustments')],
                ),
              ),
              const Expanded(
                child: TabBarView(children: <Widget>[InventoryOverviewTab(), TransfersTab(), AdjustmentsTab()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InventoryOverviewTab extends ConsumerWidget {
  const InventoryOverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppAsyncView<List<StockSummary>>(
      value: ref.watch(currentStockSummaryProvider),
      onRetry: () => ref.invalidate(currentStockSummaryProvider),
      data: (List<StockSummary> summaries) => ListView(
        padding: context.pagePadding,
        children: <Widget>[
          const AppSectionHeader(title: 'Stock summary', subtitle: 'Available value excludes reserved, in-transit and damaged units.'),
          if (summaries.isEmpty) const AppEmptyState(title: 'No stock yet', icon: Icons.inventory_2_outlined),
          Wrap(
            spacing: AppDimensions.space12,
            runSpacing: AppDimensions.space12,
            children: <Widget>[for (final StockSummary s in summaries) StockSummaryCard(summary: s)],
          ),
          const SizedBox(height: AppDimensions.space24),
          const AppSectionHeader(title: 'Ageing', subtitle: 'Days since last receipt, for units currently in stock or reserved.'),
          AppAsyncView<List<AgeingRow>>(
            value: ref.watch(stockAgeingProvider(null)),
            data: (List<AgeingRow> rows) => rows.isEmpty
                ? const AppEmptyState(title: 'Nothing in stock', icon: Icons.timelapse_outlined)
                : AppDataTable<AgeingRow>(
                    items: rows,
                    columns: <AppDataTableColumn<AgeingRow>>[
                      AppDataTableColumn<AgeingRow>(
                        title: 'Vehicle',
                        flex: 3,
                        cellBuilder: (_, AgeingRow r) => Text(r.variantLabel ?? r.chassisNumber, overflow: TextOverflow.ellipsis),
                      ),
                      AppDataTableColumn<AgeingRow>(title: 'Chassis', flex: 2, cellBuilder: (_, AgeingRow r) => Text(r.chassisNumber)),
                      AppDataTableColumn<AgeingRow>(title: 'Days', cellBuilder: (_, AgeingRow r) => Text('${r.daysInStock}')),
                      AppDataTableColumn<AgeingRow>(
                        title: 'Ageing',
                        cellBuilder: (_, AgeingRow r) => AppStatusBadge(
                          label: r.ageingBucket,
                          intent: r.ageingBucket == '90+'
                              ? AppStatusIntent.danger
                              : r.ageingBucket == '61-90'
                                  ? AppStatusIntent.warning
                                  : AppStatusIntent.neutral,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class StockSummaryCard extends StatelessWidget {
  const StockSummaryCard({required this.summary, super.key});

  final StockSummary summary;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SizedBox(
      width: 260,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(summary.showroomCode, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppDimensions.space8),
            Text('₹ ${summary.availableValue}', style: Theme.of(context).textTheme.headlineSmall),
            Text('available value', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
            const SizedBox(height: AppDimensions.space12),
            Wrap(
              spacing: AppDimensions.space8,
              runSpacing: AppDimensions.space4,
              children: <Widget>[
                _SummaryStat(label: 'Available', value: summary.availableCount, intent: AppStatusIntent.success),
                _SummaryStat(label: 'Reserved', value: summary.reservedCount, intent: AppStatusIntent.warning),
                _SummaryStat(label: 'In transit', value: summary.inTransitCount, intent: AppStatusIntent.info),
                _SummaryStat(label: 'Damaged', value: summary.damagedCount, intent: AppStatusIntent.danger),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value, required this.intent});

  final String label;
  final int value;
  final AppStatusIntent intent;

  @override
  Widget build(BuildContext context) => AppStatusBadge(label: '$label: $value', intent: intent);
}

class TransfersTab extends ConsumerWidget {
  const TransfersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    final bool canCreate = state is SignedIn &&
        ((state.session?.globalPermissions.contains('inventory.create') ?? false) ||
            (state.session?.showrooms.any((s) => s.permissions.contains('inventory.create')) ?? false));
    return AppAsyncView<List<StockTransfer>>(
      value: ref.watch(stockTransfersProvider(null)),
      onRetry: () => ref.invalidate(stockTransfersProvider(null)),
      data: (List<StockTransfer> transfers) => ListView(
        padding: context.pagePadding,
        children: <Widget>[
          AppSectionHeader(
            title: 'Stock transfers',
            subtitle: 'Vehicles moved between showrooms. No income or expense is posted (Phase 12/13).',
            trailing: canCreate
                ? AppButton(text: 'New transfer', icon: Icons.local_shipping_outlined, onPressed: () => CreateTransferDialog.show(context))
                : null,
          ),
          if (transfers.isEmpty) const AppEmptyState(title: 'No transfers yet', icon: Icons.local_shipping_outlined),
          for (final StockTransfer t in transfers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space8),
              child: TransferCard(transfer: t),
            ),
        ],
      ),
    );
  }
}

class TransferCard extends ConsumerWidget {
  const TransferCard({required this.transfer, super.key});

  final StockTransfer transfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    final bool canReceive = transfer.status == 'in_transit' &&
        state is SignedIn &&
        (state.session?.can('inventory.create', transfer.destinationShowroomId) ?? false);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('${transfer.transferNo} · ${transfer.sourceShowroomName ?? ''} → ${transfer.destinationShowroomName ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              AppStatusBadge(
                label: transfer.status == 'in_transit' ? 'In transit' : transfer.status == 'received' ? 'Received' : 'Cancelled',
                intent: transfer.status == 'received' ? AppStatusIntent.success : AppStatusIntent.warning,
              ),
            ],
          ),
          Text('${transfer.transferDate} · ${transfer.items.length} vehicle(s)', style: TextStyle(color: palette.textSecondary)),
          for (final TransferLine line in transfer.items)
            Text('• ${line.variantLabel ?? line.chassisNumber ?? line.vehicleId}', overflow: TextOverflow.ellipsis),
          if (canReceive) ...<Widget>[
            const SizedBox(height: AppDimensions.space8),
            AppButton(
              text: 'Receive',
              icon: Icons.move_to_inbox_outlined,
              onPressed: () => AppFeedback.run(
                context,
                () => ref
                    .read(inventoryActionsProvider)
                    .receiveTransfer(transfer.id, <String>[for (final TransferLine l in transfer.items) l.vehicleId]),
                success: 'Transfer received.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AdjustmentsTab extends ConsumerWidget {
  const AdjustmentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    final List<SessionShowroom> creatableShowrooms = state is SignedIn
        ? (state.session?.showrooms.where((s) => s.permissions.contains('inventory.create')).toList() ?? const <SessionShowroom>[])
        : const <SessionShowroom>[];
    return ListView(
      padding: context.pagePadding,
      children: <Widget>[
        AppSectionHeader(
          title: 'Stock adjustments',
          subtitle: 'Physical counts, damage, theft, expiry, correction and opening balances.',
          trailing: creatableShowrooms.isEmpty
              ? null
              : AppButton(
                  text: 'New adjustment',
                  icon: Icons.rule_outlined,
                  onPressed: () => CreateAdjustmentDialog.show(context, showrooms: creatableShowrooms),
                ),
        ),
        for (final SessionShowroom s in creatableShowrooms.isEmpty
            ? (state is SignedIn ? state.session?.showrooms ?? const <SessionShowroom>[] : const <SessionShowroom>[])
            : creatableShowrooms)
          AdjustmentsList(showroomId: s.id, showroomName: s.name),
      ],
    );
  }
}

class AdjustmentsList extends ConsumerWidget {
  const AdjustmentsList({required this.showroomId, required this.showroomName, super.key});

  final String showroomId;
  final String showroomName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppAsyncView<List<StockAdjustment>>(
      value: ref.watch(stockAdjustmentsProvider(showroomId)),
      data: (List<StockAdjustment> adjustments) {
        if (adjustments.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(showroomName, style: Theme.of(context).textTheme.titleSmall),
              for (final StockAdjustment a in adjustments)
                AppCard(
                  margin: const EdgeInsets.only(top: AppDimensions.space8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(child: Text('${a.adjustmentNo} · ${AdjustmentReasons.labels[a.reasonCode] ?? a.reasonCode}')),
                          Text('₹ ${a.totalValue}'),
                        ],
                      ),
                      Text('${a.adjustmentDate} · ${a.items.length} vehicle(s)'),
                      for (final AdjustmentLine line in a.items)
                        Text('• ${line.direction == 'in' ? '+' : '-'} ${line.chassisNumber ?? line.vehicleId}'),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
