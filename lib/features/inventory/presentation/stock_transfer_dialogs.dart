import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/errors/app_failure.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/validators/validators.dart';
import 'package:mybike_showroom/features/auth/application/session_controller.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';
import 'package:mybike_showroom/features/inventory/application/inventory_controller.dart';
import 'package:mybike_showroom/features/inventory/domain/stock.dart';
import 'package:mybike_showroom/features/showrooms/application/showrooms_controller.dart';
import 'package:mybike_showroom/features/showrooms/domain/showroom_admin.dart';
import 'package:mybike_showroom/features/vehicles/application/vehicles_controller.dart';
import 'package:mybike_showroom/features/vehicles/domain/vehicle_master.dart';

/// Dispatches one or more in-stock vehicles from a source showroom (needs
/// inventory.create there) to a destination (needs inventory.view there).
class CreateTransferDialog extends ConsumerStatefulWidget {
  const CreateTransferDialog({super.key});

  static Future<String?> show(BuildContext context) =>
      showDialog<String>(context: context, builder: (_) => const CreateTransferDialog());

  @override
  ConsumerState<CreateTransferDialog> createState() => CreateTransferDialogState();
}

class CreateTransferDialogState extends ConsumerState<CreateTransferDialog> {
  String? sourceShowroomId;
  String? destinationShowroomId;
  DateTime transferDate = DateTime.now();
  final Set<String> selectedVehicleIds = <String>{};
  final TextEditingController remarks = TextEditingController();

  @override
  void initState() {
    super.initState();
    final SessionState? state = ref.read(sessionControllerProvider).value;
    sourceShowroomId = state is SignedIn ? state.selection?.showroomId : null;
  }

  @override
  void dispose() {
    remarks.dispose();
    super.dispose();
  }

  List<SessionShowroom> get sourceOptions {
    final SessionState? state = ref.read(sessionControllerProvider).value;
    final List<SessionShowroom> all = state is SignedIn ? state.session?.showrooms ?? const <SessionShowroom>[] : const <SessionShowroom>[];
    return <SessionShowroom>[for (final SessionShowroom s in all) if (s.permissions.contains('inventory.create')) s];
  }

  Future<String> submit() async {
    if (sourceShowroomId == null || destinationShowroomId == null) {
      throw const ValidationFailure(message: 'Choose the source and destination showrooms.');
    }
    if (selectedVehicleIds.isEmpty) {
      throw const ValidationFailure(message: 'Choose at least one vehicle.');
    }
    return ref.read(inventoryActionsProvider).createTransfer(
          sourceShowroomId: sourceShowroomId!,
          destinationShowroomId: destinationShowroomId!,
          transferDate: transferDate.toIso8601String().substring(0, 10),
          vehicleIds: selectedVehicleIds.toList(),
          remarks: remarks.text.trim().isEmpty ? null : remarks.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final List<Showroom> allShowrooms = ref.watch(showroomListProvider).value ?? const <Showroom>[];
    final List<VehicleUnit> inStock = sourceShowroomId == null
        ? const <VehicleUnit>[]
        : (ref.watch(vehicleUnitsProvider(UnitsQuery(showroomId: sourceShowroomId, pageSize: 100))).value?.items ??
                const <VehicleUnit>[])
            .where((VehicleUnit v) => v.status == 'in_stock')
            .toList();

    return AppFormDialog<String>(
      title: 'New stock transfer',
      subtitle: 'No income or expense is recorded; only the showroom changes.',
      submitLabel: 'Dispatch',
      onSubmit: submit,
      children: <Widget>[
        AppDropdown<String>(
          label: 'Source showroom',
          value: sourceShowroomId,
          items: <AppDropdownItem<String>>[
            for (final SessionShowroom s in sourceOptions) AppDropdownItem<String>(value: s.id, label: s.name),
          ],
          onChanged: (String? v) => setState(() {
            sourceShowroomId = v;
            selectedVehicleIds.clear();
          }),
        ),
        AppDropdown<String>(
          label: 'Destination showroom',
          value: destinationShowroomId,
          items: <AppDropdownItem<String>>[
            for (final Showroom s in allShowrooms)
              if (s.id != sourceShowroomId) AppDropdownItem<String>(value: s.id!, label: s.name),
          ],
          onChanged: (String? v) => setState(() => destinationShowroomId = v),
        ),
        AppDatePicker(
          label: 'Transfer date',
          selectedDate: transferDate,
          lastDate: DateTime.now(),
          onDateSelected: (DateTime d) => setState(() => transferDate = d),
        ),
        if (sourceShowroomId != null) VehiclePickerList(vehicles: inStock, selected: selectedVehicleIds, onChanged: setState),
        AppTextField(controller: remarks, label: 'Remarks (optional)', maxLines: 2),
      ],
    );
  }
}

/// Checkbox list of vehicles for a transfer or adjustment form.
class VehiclePickerList extends StatelessWidget {
  const VehiclePickerList({required this.vehicles, required this.selected, required this.onChanged, super.key});

  final List<VehicleUnit> vehicles;
  final Set<String> selected;
  final void Function(VoidCallback fn) onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    if (vehicles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
        child: Text('No eligible vehicle in this showroom.', style: TextStyle(color: palette.textSecondary)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Vehicles', style: TextStyle(color: palette.textSecondary)),
        for (final VehicleUnit v in vehicles)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(v.variantLabel ?? v.chassisNumber, overflow: TextOverflow.ellipsis),
            subtitle: Text(v.chassisNumber),
            value: selected.contains(v.id),
            onChanged: (bool? checked) => onChanged(() {
              if (checked ?? false) {
                selected.add(v.id!);
              } else {
                selected.remove(v.id);
              }
            }),
          ),
      ],
    );
  }
}

/// Posts a batch stock adjustment for one showroom: a reason code and a set
/// of vehicles, each in or out.
class CreateAdjustmentDialog extends ConsumerStatefulWidget {
  const CreateAdjustmentDialog({required this.showrooms, super.key});

  final List<SessionShowroom> showrooms;

  static Future<String?> show(BuildContext context, {required List<SessionShowroom> showrooms}) =>
      showDialog<String>(context: context, builder: (_) => CreateAdjustmentDialog(showrooms: showrooms));

  @override
  ConsumerState<CreateAdjustmentDialog> createState() => CreateAdjustmentDialogState();
}

class CreateAdjustmentDialogState extends ConsumerState<CreateAdjustmentDialog> {
  late String? showroomId = widget.showrooms.firstOrNull?.id;
  String reasonCode = 'physical_count';
  DateTime adjustmentDate = DateTime.now();
  final Set<String> outVehicleIds = <String>{};
  String? inVehicleId;
  final TextEditingController inUnitCost = TextEditingController();
  final TextEditingController notes = TextEditingController();

  bool get isInDirection => reasonCode == 'opening' || reasonCode == 'correction';

  @override
  void dispose() {
    inUnitCost.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<String> submit() async {
    if (showroomId == null) {
      throw const ValidationFailure(message: 'Choose a showroom.');
    }
    final List<Map<String, Object?>> items;
    if (isInDirection) {
      if (inVehicleId == null) {
        throw const ValidationFailure(message: 'Choose a vehicle.');
      }
      items = <Map<String, Object?>>[
        <String, Object?>{'vehicle_id': inVehicleId, 'direction': 'in', 'unit_cost': inUnitCost.text.trim()},
      ];
    } else {
      if (outVehicleIds.isEmpty) {
        throw const ValidationFailure(message: 'Choose at least one vehicle.');
      }
      items = <Map<String, Object?>>[
        for (final String id in outVehicleIds) <String, Object?>{'vehicle_id': id, 'direction': 'out'},
      ];
    }
    return ref.read(inventoryActionsProvider).createAdjustment(
          showroomId: showroomId!,
          adjustmentDate: adjustmentDate.toIso8601String().substring(0, 10),
          reasonCode: reasonCode,
          items: items,
          notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final UnitsQuery query = UnitsQuery(showroomId: showroomId, pageSize: 100);
    final List<VehicleUnit> units = ref.watch(vehicleUnitsProvider(query)).value?.items ?? const <VehicleUnit>[];
    final List<VehicleUnit> inStock = units.where((VehicleUnit v) => v.status == 'in_stock').toList();
    final List<VehicleUnit> notInStock = units.where((VehicleUnit v) => v.status != 'in_stock').toList();
    final List<VariantOption> variantOptions = ref.watch(variantOptionsProvider).value ?? const <VariantOption>[];

    return AppFormDialog<String>(
      title: 'New stock adjustment',
      submitLabel: 'Post',
      onSubmit: submit,
      children: <Widget>[
        AppDropdown<String>(
          label: 'Showroom',
          value: showroomId,
          items: <AppDropdownItem<String>>[for (final SessionShowroom s in widget.showrooms) AppDropdownItem<String>(value: s.id, label: s.name)],
          onChanged: (String? v) => setState(() {
            showroomId = v;
            outVehicleIds.clear();
            inVehicleId = null;
          }),
        ),
        AppDropdown<String>(
          label: 'Reason',
          value: reasonCode,
          items: <AppDropdownItem<String>>[
            for (final MapEntry<String, String> e in AdjustmentReasons.labels.entries) AppDropdownItem<String>(value: e.key, label: e.value),
          ],
          onChanged: (String? v) => setState(() => reasonCode = v ?? reasonCode),
        ),
        AppDatePicker(
          label: 'Adjustment date',
          selectedDate: adjustmentDate,
          lastDate: DateTime.now(),
          onDateSelected: (DateTime d) => setState(() => adjustmentDate = d),
        ),
        if (isInDirection) ...<Widget>[
          AppDropdown<String>(
            label: 'Vehicle (not currently in stock)',
            value: inVehicleId,
            hint: notInStock.isEmpty ? 'No eligible vehicle' : null,
            items: <AppDropdownItem<String>>[
              for (final VehicleUnit v in notInStock)
                AppDropdownItem<String>(value: v.id!, label: '${v.variantLabel ?? v.chassisNumber} · ${v.chassisNumber}'),
            ],
            onChanged: (String? v) => setState(() => inVehicleId = v),
          ),
          AppTextField(
            controller: inUnitCost,
            label: 'Unit cost (₹)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: Validators.amount,
          ),
        ] else
          VehiclePickerList(vehicles: inStock, selected: outVehicleIds, onChanged: setState),
        AppTextField(controller: notes, label: 'Notes (optional)', maxLines: 2),
        if (variantOptions.isEmpty && isInDirection)
          const Text('Register the vehicle in the catalogue first (Vehicles → Register vehicle).'),
      ],
    );
  }
}
