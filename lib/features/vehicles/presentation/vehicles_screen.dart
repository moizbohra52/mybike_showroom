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
import 'package:mybike_showroom/features/vehicles/application/vehicles_controller.dart';
import 'package:mybike_showroom/features/vehicles/domain/vehicle_master.dart';
import 'package:mybike_showroom/features/vehicles/presentation/vehicle_dialogs.dart';

/// Vehicle register of the current showroom and the company catalogue.
class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: context.pagePadding.copyWith(bottom: 0),
                child: const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: <Tab>[
                    Tab(text: 'Vehicles'),
                    Tab(text: 'Catalogue'),
                  ],
                ),
              ),
              const Expanded(
                child: TabBarView(
                  children: <Widget>[UnitsTab(), CatalogueTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status badge colour of a unit.
class VehicleStatusBadge extends StatelessWidget {
  const VehicleStatusBadge({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) => AppStatusBadge(
    label: VehicleStatuses.label(status),
    intent: switch (status) {
      'in_stock' || 'received' => AppStatusIntent.success,
      'reserved' || 'in_transit' || 'purchased' => AppStatusIntent.warning,
      'damaged' || 'returned_to_supplier' => AppStatusIntent.danger,
      'sold' || 'delivered' => AppStatusIntent.info,
      _ => AppStatusIntent.neutral,
    },
  );
}

class FuelBadge extends StatelessWidget {
  const FuelBadge({required this.fuelType, super.key});

  final String fuelType;

  @override
  Widget build(BuildContext context) => AppStatusBadge(
    label: FuelTypes.labels[fuelType] ?? fuelType,
    intent: FuelTypes.hasMotor(fuelType)
        ? AppStatusIntent.success
        : AppStatusIntent.neutral,
  );
}

/// Units of the current showroom (every accessible one in ALL SHOWROOMS).
class UnitsTab extends ConsumerStatefulWidget {
  const UnitsTab({super.key});

  static const String createPermission = 'vehicles.create';

  @override
  ConsumerState<UnitsTab> createState() => UnitsTabState();
}

class UnitsTabState extends ConsumerState<UnitsTab> {
  late UnitsQuery query = UnitsQuery(
    showroomId: ref.read(currentSelectionProvider)?.showroomId,
  );

  void update(UnitsQuery next) => setState(() => query = next);

  @override
  Widget build(BuildContext context) {
    ref.listen<ShowroomSelection?>(
      currentSelectionProvider,
      (_, ShowroomSelection? next) =>
          update(query.copyWith(showroomId: () => next?.showroomId, page: 1)),
    );
    final String? showroomId = query.showroomId;
    final AsyncValue<UnitsPage> page = ref.watch(vehicleUnitsProvider(query));
    void open(VehicleUnit u) => context.go(AppRoutes.vehicleUnitPath(u.id!));

    return ListView(
      padding: context.pagePadding,
      children: <Widget>[
        AppSectionHeader(
          title: 'Vehicle register',
          subtitle: showroomId == null
              ? 'All showrooms. Pick a showroom to register a vehicle.'
              : 'Every unit of this showroom, by VIN, chassis, engine, motor or battery number.',
          trailing: showroomId == null
              ? null
              : AppPermissionWidget(
                  permission: UnitsTab.createPermission,
                  child: AppButton(
                    text: 'Register vehicle',
                    icon: Icons.add,
                    onPressed: () async {
                      final String? id = await VehicleUnitDialog.show(
                        context,
                        showroomId: showroomId,
                      );
                      if (id != null && context.mounted) {
                        context.go(AppRoutes.vehicleUnitPath(id));
                      }
                    },
                  ),
                ),
        ),
        SizedBox(
          width: 360,
          child: AppSearchField(
            hint: 'VIN, chassis, engine, motor or battery no.',
            onSubmitted: (String v) =>
                update(query.copyWith(search: v, page: 1)),
            onClear: () => update(query.copyWith(search: '', page: 1)),
          ),
        ),
        const SizedBox(height: AppDimensions.space16),
        AppAsyncView<UnitsPage>(
          value: page,
          onRetry: () => ref.invalidate(vehicleUnitsProvider(query)),
          data: (UnitsPage data) {
            final int pages = (data.total / query.pageSize).ceil();
            final Widget pagination = AppPagination(
              currentPage: query.page,
              totalPages: pages < 1 ? 1 : pages,
              totalItems: data.total,
              itemsPerPage: query.pageSize,
              onPageChanged: (int p) => update(query.copyWith(page: p)),
            );
            if (data.items.isEmpty) {
              return const AppEmptyState(
                title: 'No vehicles found',
                icon: Icons.two_wheeler_outlined,
              );
            }
            if (context.isCompactLayout) {
              return Column(
                children: <Widget>[
                  for (final VehicleUnit u in data.items)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppDimensions.space8,
                      ),
                      child: AppCard(
                        onTap: () => open(u),
                        child: UnitSummary(unit: u),
                      ),
                    ),
                  pagination,
                ],
              );
            }
            return AppDataTable<VehicleUnit>(
              items: data.items,
              onRowTap: open,
              pagination: pagination,
              columns: <AppDataTableColumn<VehicleUnit>>[
                AppDataTableColumn<VehicleUnit>(
                  title: 'Vehicle',
                  flex: 3,
                  cellBuilder: (_, VehicleUnit u) => UnitSummary(unit: u),
                ),
                AppDataTableColumn<VehicleUnit>(
                  title: 'Engine / motor',
                  flex: 2,
                  cellBuilder: (_, VehicleUnit u) => Text(
                    u.engineNumber ?? u.motorNumber ?? '—',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppDataTableColumn<VehicleUnit>(
                  title: 'Colour',
                  flex: 2,
                  cellBuilder: (_, VehicleUnit u) => Text(u.color ?? '—'),
                ),
                AppDataTableColumn<VehicleUnit>(
                  title: 'Fuel',
                  cellBuilder: (_, VehicleUnit u) =>
                      FuelBadge(fuelType: u.fuelType),
                ),
                AppDataTableColumn<VehicleUnit>(
                  title: 'Status',
                  flex: 2,
                  cellBuilder: (_, VehicleUnit u) =>
                      VehicleStatusBadge(status: u.status),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class UnitSummary extends StatelessWidget {
  const UnitSummary({required this.unit, super.key});

  final VehicleUnit unit;

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
              Text(
                unit.variantLabel ?? unit.chassisNumber,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                unit.chassisNumber,
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (compact) VehicleStatusBadge(status: unit.status),
      ],
    );
  }
}

/// Brands → models → variants. Maintained with vehicles.create / edit.
class CatalogueTab extends ConsumerWidget {
  const CatalogueTab({super.key});

  static const String createPermission = 'vehicles.create';
  static const String editPermission = 'vehicles.edit';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = AppPalette.of(context);
    return AppAsyncView<List<VehicleBrand>>(
      value: ref.watch(vehicleCatalogueProvider),
      onRetry: () => ref.invalidate(vehicleCatalogueProvider),
      data: (List<VehicleBrand> brands) => ListView(
        padding: context.pagePadding,
        children: <Widget>[
          AppSectionHeader(
            title: 'Catalogue',
            subtitle: 'Brands, models and variants shared by every showroom.',
            trailing: AppPermissionWidget(
              permission: createPermission,
              child: AppOutlinedButton(
                text: 'Add brand',
                icon: Icons.add,
                onPressed: () => BrandDialog.show(context),
              ),
            ),
          ),
          if (brands.isEmpty)
            const AppEmptyState(
              title: 'No brands yet',
              icon: Icons.category_outlined,
            ),
          for (final VehicleBrand brand in brands)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space12),
              child: AppCard(
                padding: EdgeInsets.zero,
                // Own ink surface: the ExpansionTile's ListTile would otherwise
                // paint its ripple/background behind AppCard's decoration.
                child: Material(
                  type: MaterialType.transparency,
                  child: ExpansionTile(
                    title: Text(
                      brand.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${brand.code} · ${brand.models.length} model(s)${brand.isActive ? '' : ' · inactive'}',
                      style: TextStyle(color: palette.textSecondary),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(
                      AppDimensions.space16,
                      0,
                      AppDimensions.space16,
                      AppDimensions.space16,
                    ),
                    children: <Widget>[
                      Wrap(
                        spacing: AppDimensions.space8,
                        children: <Widget>[
                          AppPermissionWidget(
                            permission: createPermission,
                            child: TextButton.icon(
                              onPressed: () =>
                                  ModelDialog.show(context, brandId: brand.id!),
                              icon: const Icon(Icons.add),
                              label: const Text('Add model'),
                            ),
                          ),
                          AppPermissionWidget(
                            permission: editPermission,
                            child: TextButton.icon(
                              onPressed: () =>
                                  BrandDialog.show(context, brand: brand),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit brand'),
                            ),
                          ),
                        ],
                      ),
                      for (final VehicleModel model in brand.models)
                        ModelTile(model: model),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ModelTile extends StatelessWidget {
  const ModelTile({required this.model, super.key});

  final VehicleModel model;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppDimensions.space8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(model.name, style: Theme.of(context).textTheme.titleSmall),
              Text(
                VehicleCategories.labels[model.category] ?? model.category,
                style: TextStyle(color: palette.textSecondary),
              ),
              if (!model.isActive)
                const AppStatusBadge(
                  label: 'Inactive',
                  intent: AppStatusIntent.warning,
                ),
              AppPermissionWidget(
                permission: CatalogueTab.editPermission,
                child: IconButton(
                  tooltip: 'Edit model',
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: AppDimensions.iconSm,
                  ),
                  onPressed: () => ModelDialog.show(
                    context,
                    brandId: model.brandId,
                    model: model,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: AppDimensions.space8,
            runSpacing: AppDimensions.space8,
            children: <Widget>[
              for (final VehicleVariant v in model.variants)
                ActionChip(
                  avatar: Icon(
                    v.hasMotor
                        ? Icons.electric_bolt
                        : Icons.local_gas_station_outlined,
                    size: AppDimensions.iconSm,
                  ),
                  label: Text(v.isActive ? v.name : '${v.name} (inactive)'),
                  onPressed: () =>
                      context.go(AppRoutes.vehicleVariantPath(v.id!)),
                ),
              AppPermissionWidget(
                permission: CatalogueTab.createPermission,
                child: ActionChip(
                  avatar: const Icon(Icons.add, size: AppDimensions.iconSm),
                  label: const Text('Add variant'),
                  onPressed: () async {
                    final String? id = await VariantDialog.show(
                      context,
                      modelId: model.id!,
                    );
                    if (id != null && context.mounted) {
                      context.go(AppRoutes.vehicleVariantPath(id));
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
