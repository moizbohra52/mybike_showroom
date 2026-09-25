import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/features/auth/application/session_controller.dart';
import 'package:mybike_showroom/features/inventory/application/inventory_controller.dart';
import 'package:mybike_showroom/features/inventory/domain/stock.dart';
import 'package:mybike_showroom/features/inventory/presentation/stock_action_dialogs.dart';
import 'package:mybike_showroom/features/vehicles/application/vehicles_controller.dart';
import 'package:mybike_showroom/features/vehicles/domain/vehicle_master.dart';
import 'package:mybike_showroom/features/vehicles/presentation/vehicle_dialogs.dart';
import 'package:mybike_showroom/features/vehicles/presentation/vehicles_screen.dart';

/// Back link + title block shared by the vehicle detail pages.
class DetailHeader extends StatelessWidget {
  const DetailHeader({required this.title, required this.badges, this.subtitle, this.action, super.key});

  final String title;
  final String? subtitle;
  final List<Widget> badges;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextButton.icon(
          onPressed: () => context.go(AppRoutes.vehiclesPath),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Vehicles'),
        ),
        Wrap(
          spacing: AppDimensions.space12,
          runSpacing: AppDimensions.space8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            ...badges,
            ?action,
          ],
        ),
        if (subtitle != null) Text(subtitle!, style: TextStyle(color: palette.textSecondary)),
        const SizedBox(height: AppDimensions.space16),
      ],
    );
  }
}

/// A card with a title and label / value rows.
class SpecCard extends StatelessWidget {
  const SpecCard({required this.title, required this.rows, super.key});

  final String title;
  final Map<String, String?> rows;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.space16),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppDimensions.space8),
              for (final MapEntry<String, String?> r in rows.entries) AppInfoRow(label: r.key, value: r.value),
            ],
          ),
        ),
      );
}

String? withUnit(String? value, String unit) => value == null ? null : '$value $unit';

/// A variant's specifications (petrol / EV sections by fuel type) and warranty.
class VariantDetailScreen extends ConsumerWidget {
  const VariantDetailScreen({required this.variantId, super.key});

  final String variantId;

  static const String editPermission = 'vehicles.edit';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: AppAsyncView<List<VariantOption>>(
          value: ref.watch(variantOptionsProvider),
          onRetry: () => ref.invalidate(vehicleCatalogueProvider),
          data: (List<VariantOption> _) {
            final VariantOption? option = findVariant(ref.watch(vehicleCatalogueProvider).value ?? const <VehicleBrand>[]);
            if (option == null) {
              return AppEmptyState(
                title: 'Variant not found',
                icon: Icons.two_wheeler_outlined,
                actionText: 'Back to vehicles',
                onAction: () => context.go(AppRoutes.vehiclesPath),
              );
            }
            final VehicleVariant v = option.variant;
            return ListView(
              padding: context.pagePadding,
              children: <Widget>[
                DetailHeader(
                  title: '${option.brandName} ${option.modelName} ${v.name}',
                  subtitle: v.exShowroomPrice == null ? null : 'Ex-showroom ₹ ${v.exShowroomPrice}',
                  badges: <Widget>[
                    FuelBadge(fuelType: v.fuelType),
                    if (!v.isActive) const AppStatusBadge(label: 'Inactive', intent: AppStatusIntent.warning),
                  ],
                  action: AppPermissionWidget(
                    permission: editPermission,
                    child: AppOutlinedButton(
                      text: 'Edit',
                      icon: Icons.edit_outlined,
                      onPressed: () => VariantDialog.show(context, modelId: v.modelId, variant: v),
                    ),
                  ),
                ),
                SpecCard(title: 'General', rows: <String, String?>{
                  'HSN code': v.hsnCode,
                  'Transmission': v.transmission,
                  'Top speed': withUnit(v.topSpeedKmph, 'km/h'),
                }),
                if (v.hasEngine)
                  SpecCard(title: 'Engine', rows: <String, String?>{
                    'Displacement': withUnit(v.engineCc, 'cc'),
                    'Mileage': withUnit(v.mileageKmpl, 'km/l'),
                    'Fuel tank': withUnit(v.fuelTankLitres, 'litres'),
                  }),
                if (v.hasMotor)
                  SpecCard(title: 'Motor and battery', rows: <String, String?>{
                    'Motor power': withUnit(v.motorPowerKw, 'kW'),
                    'Battery capacity': withUnit(v.batteryCapacityKwh, 'kWh'),
                    'Battery type': v.batteryType,
                    'Range': withUnit(v.rangeKm, 'km'),
                    'Charging time': withUnit(v.chargingTimeHours, 'hours'),
                    'Charging': v.chargingType,
                  }),
                SpecCard(title: 'Warranty', rows: <String, String?>{
                  'Vehicle': VehicleVariant.warrantyText(v.warrantyMonths, v.warrantyKm),
                  if (v.hasMotor) 'Battery': VehicleVariant.warrantyText(v.batteryWarrantyMonths, v.batteryWarrantyKm),
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  VariantOption? findVariant(List<VehicleBrand> brands) {
    for (final VehicleBrand b in brands) {
      for (final VehicleModel m in b.models) {
        for (final VehicleVariant v in m.variants) {
          if (v.id == variantId) {
            return VariantOption(variant: v, brandName: b.name, modelName: m.name);
          }
        }
      }
    }
    return null;
  }
}

/// One vehicle: identifiers, specifications of its variant and warranty.
class VehicleUnitScreen extends ConsumerWidget {
  const VehicleUnitScreen({required this.unitId, super.key});

  final String unitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    return Scaffold(
      body: SafeArea(
        child: AppAsyncView<VehicleUnit?>(
          value: ref.watch(vehicleUnitProvider(unitId)),
          onRetry: () => ref.invalidate(vehicleUnitProvider(unitId)),
          data: (VehicleUnit? u) {
            if (u == null) {
              return AppEmptyState(
                title: 'Vehicle not found',
                message: 'It does not exist or belongs to a showroom you cannot access.',
                icon: Icons.two_wheeler_outlined,
                actionText: 'Back to vehicles',
                onAction: () => context.go(AppRoutes.vehiclesPath),
              );
            }
            final bool canEdit = state is SignedIn && (state.session?.can('vehicles.edit', u.showroomId) ?? false);
            final VehicleVariant? variant = (ref.watch(variantOptionsProvider).value ?? const <VariantOption>[])
                .where((VariantOption o) => o.variant.id == u.variantId)
                .firstOrNull
                ?.variant;
            return ListView(
              padding: context.pagePadding,
              children: <Widget>[
                DetailHeader(
                  title: u.variantLabel ?? u.chassisNumber,
                  subtitle: u.chassisNumber,
                  badges: <Widget>[FuelBadge(fuelType: u.fuelType), VehicleStatusBadge(status: u.status)],
                  action: canEdit
                      ? AppOutlinedButton(
                          text: 'Edit',
                          icon: Icons.edit_outlined,
                          onPressed: () => VehicleUnitDialog.show(context, showroomId: u.showroomId, unit: u),
                        )
                      : null,
                ),
                SpecCard(title: 'Identification', rows: <String, String?>{
                  'VIN': u.vin,
                  'Chassis number': u.chassisNumber,
                  if (FuelTypes.hasEngine(u.fuelType)) 'Engine number': u.engineNumber,
                  if (FuelTypes.hasMotor(u.fuelType)) 'Motor number': u.motorNumber,
                  if (FuelTypes.hasMotor(u.fuelType)) 'Battery number': u.batteryNumber,
                }),
                SpecCard(title: 'Details', rows: <String, String?>{
                  'Colour': u.color,
                  'Manufacturing year': u.manufacturingYear?.toString(),
                  'Model year': u.modelYear?.toString(),
                  'Ownership': Ownerships.labels[u.ownership],
                  'Status': VehicleStatuses.label(u.status),
                  'Remarks': u.remarks,
                }),
                SpecCard(title: 'Warranty', rows: <String, String?>{
                  'Starts': u.warrantyStart ?? 'At delivery',
                  'Ends': u.warrantyEnd,
                  'Terms': variant == null ? null : VehicleVariant.warrantyText(variant.warrantyMonths, variant.warrantyKm),
                  if (variant != null && variant.hasMotor)
                    'Battery terms': VehicleVariant.warrantyText(variant.batteryWarrantyMonths, variant.batteryWarrantyKm),
                }),
                if (variant != null)
                  TextButton.icon(
                    onPressed: () => context.go(AppRoutes.vehicleVariantPath(variant.id!)),
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Specifications of this variant'),
                  ),
                const SizedBox(height: AppDimensions.space24),
                StockActionsCard(vehicle: u),
                const SizedBox(height: AppDimensions.space24),
                StockHistoryCard(vehicleId: u.id!),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Context-sensitive stock actions (receive / reserve / release / mark
/// damaged) and the active reservation, if any. RLS decides every write; the
/// buttons shown here follow the vehicle's current status and the caller's
/// inventory.* permission in its showroom (UI convenience only).
class StockActionsCard extends ConsumerWidget {
  const StockActionsCard({required this.vehicle, super.key});

  final VehicleUnit vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    bool can(String permission) => state is SignedIn && (state.session?.can(permission, vehicle.showroomId) ?? false);
    final bool canCreate = can('inventory.create');
    final bool canEdit = can('inventory.edit');

    final List<Widget> actions = <Widget>[
      if (vehicle.status == 'purchased' && canCreate)
        AppButton(
          text: 'Receive stock',
          icon: Icons.move_to_inbox_outlined,
          onPressed: () => ReceiveStockDialog.show(context, vehicle.id!),
        ),
      if (vehicle.status == 'in_stock' && canEdit)
        AppOutlinedButton(
          text: 'Reserve',
          icon: Icons.event_available_outlined,
          onPressed: () => ReserveVehicleDialog.show(context, vehicle.id!),
        ),
      if (vehicle.status == 'reserved' && canEdit)
        AppOutlinedButton(
          text: 'Release reservation',
          icon: Icons.event_busy_outlined,
          onPressed: () => ReasonRequiredDialog.show(
            context,
            title: 'Release reservation',
            submitLabel: 'Release',
            onSubmit: (String reason) => ref.read(inventoryActionsProvider).releaseReservation(vehicle.id!, reason),
          ),
        ),
      if ((vehicle.status == 'in_stock' || vehicle.status == 'reserved') && canEdit)
        AppButton(
          text: 'Mark damaged',
          icon: Icons.warning_amber_outlined,
          variant: AppButtonVariant.danger,
          onPressed: () => ReasonRequiredDialog.show(
            context,
            title: 'Mark vehicle damaged',
            submitLabel: 'Mark damaged',
            destructive: true,
            onSubmit: (String reason) => ref.read(inventoryActionsProvider).markDamaged(vehicle.id!, reason),
          ),
        ),
    ];

    if (actions.isEmpty && vehicle.status != 'reserved') {
      return const SizedBox.shrink();
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Stock', style: Theme.of(context).textTheme.titleMedium),
          if (vehicle.status == 'reserved')
            AppAsyncView<ActiveReservation?>(
              value: ref.watch(vehicleActiveReservationProvider(vehicle.id!)),
              data: (ActiveReservation? r) => r == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
                      child: Text('Reserved by ${r.reservedByName ?? 'a staff member'} on '
                          '${r.reservedAt.toLocal().toString().substring(0, 16)}'),
                    ),
            ),
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppDimensions.space8),
            Wrap(spacing: AppDimensions.space8, runSpacing: AppDimensions.space8, children: actions),
          ],
        ],
      ),
    );
  }
}

/// Status-change and stock-movement history of one vehicle.
class StockHistoryCard extends ConsumerWidget {
  const StockHistoryCard({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    return AppAsyncView<List<StatusChange>>(
      value: ref.watch(vehicleStatusHistoryProvider(vehicleId)),
      data: (List<StatusChange> history) {
        if (history.isEmpty) {
          return const SizedBox.shrink();
        }
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Status history', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppDimensions.space8),
              for (final StatusChange change in history)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.space4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${change.fromStatus == null ? 'Registered' : VehicleStatuses.label(change.fromStatus!)} '
                          '→ ${VehicleStatuses.label(change.toStatus)}'
                          '${change.reason == null ? '' : ' · ${change.reason}'}',
                        ),
                      ),
                      Text(
                        change.changedAt.toLocal().toString().substring(0, 16),
                        style: TextStyle(color: palette.textSecondary, fontSize: 12),
                      ),
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
