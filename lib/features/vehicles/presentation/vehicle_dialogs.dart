import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/errors/app_failure.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/validators/validators.dart';
import 'package:mybike_showroom/features/vehicles/application/vehicles_controller.dart';
import 'package:mybike_showroom/features/vehicles/domain/vehicle_master.dart';

/// Small section title inside a form.
class FormGroupTitle extends StatelessWidget {
  const FormGroupTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppDimensions.space8),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      );
}

class BrandDialog extends ConsumerStatefulWidget {
  const BrandDialog({this.brand, super.key});

  final VehicleBrand? brand;

  static Future<bool?> show(BuildContext context, {VehicleBrand? brand}) =>
      showDialog<bool>(context: context, builder: (_) => BrandDialog(brand: brand));

  @override
  ConsumerState<BrandDialog> createState() => BrandDialogState();
}

class BrandDialogState extends ConsumerState<BrandDialog> {
  static final RegExp codePattern = RegExp(r'^[A-Z0-9][A-Z0-9-]{1,19}$');

  late final TextEditingController code = TextEditingController(text: widget.brand?.code);
  late final TextEditingController name = TextEditingController(text: widget.brand?.name);
  late final TextEditingController country = TextEditingController(text: widget.brand?.country);
  late bool isActive = widget.brand?.isActive ?? true;

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    country.dispose();
    super.dispose();
  }

  Future<bool> submit() async {
    await ref.read(vehicleAdminActionsProvider).saveBrand(
          VehicleBrand(id: widget.brand?.id, code: code.text, name: name.text, country: country.text, isActive: isActive),
        );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog<bool>(
      title: widget.brand == null ? 'New brand' : 'Edit brand',
      onSubmit: submit,
      children: <Widget>[
        AppTextField(controller: name, label: 'Name', validator: (String? v) => Validators.required(v, field: 'Name')),
        AppTextField(
          controller: code,
          label: 'Code',
          hint: 'HONDA',
          validator: (String? v) => codePattern.hasMatch((v ?? '').trim().toUpperCase())
              ? null
              : 'Use 2–20 capital letters, digits or dashes.',
        ),
        AppTextField(controller: country, label: 'Country (optional)'),
        if (widget.brand != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            subtitle: const Text('Inactive brands are hidden from new registrations.'),
            value: isActive,
            onChanged: (bool v) => setState(() => isActive = v),
          ),
      ],
    );
  }
}

class ModelDialog extends ConsumerStatefulWidget {
  const ModelDialog({required this.brandId, this.model, super.key});

  final String brandId;
  final VehicleModel? model;

  static Future<bool?> show(BuildContext context, {required String brandId, VehicleModel? model}) =>
      showDialog<bool>(context: context, builder: (_) => ModelDialog(brandId: brandId, model: model));

  @override
  ConsumerState<ModelDialog> createState() => ModelDialogState();
}

class ModelDialogState extends ConsumerState<ModelDialog> {
  late final TextEditingController name = TextEditingController(text: widget.model?.name);
  late String category = widget.model?.category ?? 'scooter';
  late bool isActive = widget.model?.isActive ?? true;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<bool> submit() async {
    await ref.read(vehicleAdminActionsProvider).saveModel(
          VehicleModel(id: widget.model?.id, brandId: widget.brandId, name: name.text, category: category, isActive: isActive),
        );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog<bool>(
      title: widget.model == null ? 'New model' : 'Edit model',
      onSubmit: submit,
      children: <Widget>[
        AppTextField(controller: name, label: 'Name', validator: (String? v) => Validators.required(v, field: 'Name')),
        AppDropdown<String>(
          label: 'Body type',
          value: category,
          items: <AppDropdownItem<String>>[
            for (final MapEntry<String, String> e in VehicleCategories.labels.entries)
              AppDropdownItem<String>(value: e.key, label: e.value),
          ],
          onChanged: (String? v) => setState(() => category = v ?? category),
        ),
        if (widget.model != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            value: isActive,
            onChanged: (bool v) => setState(() => isActive = v),
          ),
      ],
    );
  }
}

/// A numeric specification field: label, column and numeric(p, s) shape.
@immutable
class SpecField {
  const SpecField(this.column, this.label, {this.digits = 3, this.decimals = 0, this.required = false});

  final String column;
  final String label;
  final int digits;
  final int decimals;
  final bool required;
}

/// Creates or edits a variant. Engine fields show for petrol / CNG / hybrid,
/// motor and battery fields for electric / hybrid — the database enforces
/// the same rules.
class VariantDialog extends ConsumerStatefulWidget {
  const VariantDialog({required this.modelId, this.variant, super.key});

  final String modelId;
  final VehicleVariant? variant;

  static Future<String?> show(BuildContext context, {required String modelId, VehicleVariant? variant}) =>
      showDialog<String>(context: context, builder: (_) => VariantDialog(modelId: modelId, variant: variant));

  static const List<SpecField> common = <SpecField>[
    SpecField('top_speed_kmph', 'Top speed (km/h)'),
    SpecField('warranty_months', 'Warranty (months)'),
    SpecField('warranty_km', 'Warranty (km)', digits: 7),
  ];
  static const List<SpecField> engine = <SpecField>[
    SpecField('engine_cc', 'Engine (cc)', digits: 5, decimals: 1, required: true),
    SpecField('mileage_kmpl', 'Mileage (km/l)', digits: 4, decimals: 1),
    SpecField('fuel_tank_litres', 'Fuel tank (litres)', decimals: 1),
  ];
  static const List<SpecField> motor = <SpecField>[
    SpecField('motor_power_kw', 'Motor power (kW)', decimals: 2, required: true),
    SpecField('battery_capacity_kwh', 'Battery capacity (kWh)', decimals: 2, required: true),
    SpecField('range_km', 'Range (km)', digits: 4),
    SpecField('charging_time_hours', 'Charging time (hours)', decimals: 1),
    SpecField('battery_warranty_months', 'Battery warranty (months)'),
    SpecField('battery_warranty_km', 'Battery warranty (km)', digits: 7),
  ];
  static const List<String> texts = <String>['name', 'hsn_code', 'ex_showroom_price', 'transmission', 'battery_type', 'charging_type'];

  @override
  ConsumerState<VariantDialog> createState() => VariantDialogState();
}

class VariantDialogState extends ConsumerState<VariantDialog> {
  static final RegExp hsnPattern = RegExp(r'^[0-9]{4}([0-9]{2}){0,2}$');

  late final Map<String, Object?> initial = widget.variant?.toJson() ?? const <String, Object?>{};
  late final Map<String, TextEditingController> c = <String, TextEditingController>{
    for (final String key in <String>[
      ...VariantDialog.texts,
      for (final SpecField f in <SpecField>[...VariantDialog.common, ...VariantDialog.engine, ...VariantDialog.motor]) f.column,
    ])
      key: TextEditingController(text: initial[key]?.toString()),
  };
  late String fuelType = widget.variant?.fuelType ?? FuelTypes.petrol;
  late bool isActive = widget.variant?.isActive ?? true;

  @override
  void dispose() {
    for (final TextEditingController controller in c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<String> submit() {
    return ref.read(vehicleAdminActionsProvider).saveVariant(VehicleVariant.fromJson(<String, Object?>{
          for (final MapEntry<String, TextEditingController> e in c.entries) e.key: e.value.text.trim(),
          'id': widget.variant?.id,
          'model_id': widget.modelId,
          'fuel_type': fuelType,
          'is_active': isActive,
        }));
  }

  List<Widget> specFields(List<SpecField> fields) => <Widget>[
        for (final SpecField f in fields)
          AppTextField(
            controller: c[f.column],
            label: f.required ? f.label : '${f.label} (optional)',
            keyboardType: TextInputType.numberWithOptions(decimal: f.decimals > 0),
            validator: (String? v) =>
                (f.required ? Validators.required(v, field: f.label) : null) ??
                Validators.number(v, digits: f.digits, decimals: f.decimals),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    return AppFormDialog<String>(
      title: widget.variant == null ? 'New variant' : 'Edit variant',
      subtitle: 'Specifications follow the fuel type.',
      onSubmit: submit,
      children: <Widget>[
        AppTextField(controller: c['name'], label: 'Name', validator: (String? v) => Validators.required(v, field: 'Name')),
        AppDropdown<String>(
          label: 'Fuel type',
          value: fuelType,
          items: <AppDropdownItem<String>>[
            for (final MapEntry<String, String> e in FuelTypes.labels.entries) AppDropdownItem<String>(value: e.key, label: e.value),
          ],
          onChanged: (String? v) => setState(() => fuelType = v ?? fuelType),
        ),
        AppTextField(
          controller: c['ex_showroom_price'],
          label: 'Ex-showroom price (₹, optional)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: Validators.amount,
        ),
        AppTextField(
          controller: c['hsn_code'],
          label: 'HSN code (optional)',
          keyboardType: TextInputType.number,
          validator: (String? v) =>
              Validators.pattern(v, hsnPattern, 'Enter 4, 6 or 8 digits.', upperCase: false),
        ),
        AppTextField(controller: c['transmission'], label: 'Transmission (optional)', hint: 'Automatic (CVT)'),
        ...specFields(VariantDialog.common),
        if (FuelTypes.hasEngine(fuelType)) ...<Widget>[
          const FormGroupTitle('Engine'),
          ...specFields(VariantDialog.engine),
        ],
        if (FuelTypes.hasMotor(fuelType)) ...<Widget>[
          const FormGroupTitle('Motor and battery'),
          AppTextField(controller: c['battery_type'], label: 'Battery type (optional)', hint: 'Li-ion'),
          AppTextField(controller: c['charging_type'], label: 'Charging (optional)', hint: 'Portable 650 W'),
          ...specFields(VariantDialog.motor),
        ],
        if (widget.variant != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            subtitle: const Text('Inactive variants are hidden from new registrations.'),
            value: isActive,
            onChanged: (bool v) => setState(() => isActive = v),
          ),
      ],
    );
  }
}

/// Registers or edits a vehicle unit. The identifiers asked for follow the
/// variant's fuel type; duplicates are checked across every showroom before
/// saving, and the database checks again.
class VehicleUnitDialog extends ConsumerStatefulWidget {
  const VehicleUnitDialog({required this.showroomId, this.unit, super.key});

  final String showroomId;
  final VehicleUnit? unit;

  static Future<String?> show(BuildContext context, {required String showroomId, VehicleUnit? unit}) =>
      showDialog<String>(context: context, builder: (_) => VehicleUnitDialog(showroomId: showroomId, unit: unit));

  @override
  ConsumerState<VehicleUnitDialog> createState() => VehicleUnitDialogState();
}

class VehicleUnitDialogState extends ConsumerState<VehicleUnitDialog> {
  late final VehicleUnit? u = widget.unit;
  late String? variantId = u?.variantId;
  late final TextEditingController vin = TextEditingController(text: u?.vin);
  late final TextEditingController chassis = TextEditingController(text: u?.chassisNumber);
  late final TextEditingController engine = TextEditingController(text: u?.engineNumber);
  late final TextEditingController motor = TextEditingController(text: u?.motorNumber);
  late final TextEditingController battery = TextEditingController(text: u?.batteryNumber);
  late final TextEditingController color = TextEditingController(text: u?.color);
  late final TextEditingController mfgYear = TextEditingController(text: u?.manufacturingYear?.toString());
  late final TextEditingController modelYear = TextEditingController(text: u?.modelYear?.toString());
  late final TextEditingController remarks = TextEditingController(text: u?.remarks);
  late String ownership = u?.ownership ?? 'new';
  late DateTime? warrantyStart = DateTime.tryParse(u?.warrantyStart ?? '');
  late DateTime? warrantyEnd = DateTime.tryParse(u?.warrantyEnd ?? '');
  Map<String, String> fieldErrors = const <String, String>{};

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[vin, chassis, engine, motor, battery, color, mfgYear, modelYear, remarks]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? isoDate(DateTime? d) => d?.toIso8601String().substring(0, 10);

  String? validateYear(String? v) {
    if ((v ?? '').trim().isEmpty) {
      return null;
    }
    return Validators.wholeNumber(v, min: 1990, max: DateTime.now().year + 1);
  }

  Future<String> submit(List<VariantOption> options) async {
    final VariantOption? option = options.where((VariantOption o) => o.variant.id == variantId).firstOrNull;
    if (option == null) {
      throw const ValidationFailure(message: 'Choose the variant.');
    }
    if (warrantyEnd != null && (warrantyStart == null || warrantyEnd!.isBefore(warrantyStart!))) {
      throw const ValidationFailure(message: 'The warranty must start before it ends.');
    }
    setState(() => fieldErrors = const <String, String>{});
    try {
      return await ref.read(vehicleAdminActionsProvider).saveUnit(
            VehicleUnit(
              id: u?.id,
              showroomId: u?.showroomId ?? widget.showroomId,
              variantId: option.variant.id!,
              vin: vin.text,
              chassisNumber: chassis.text,
              engineNumber: engine.text,
              motorNumber: motor.text,
              batteryNumber: battery.text,
              color: color.text,
              manufacturingYear: int.tryParse(mfgYear.text.trim()),
              modelYear: int.tryParse(modelYear.text.trim()),
              ownership: ownership,
              warrantyStart: isoDate(warrantyStart),
              warrantyEnd: isoDate(warrantyEnd),
              remarks: remarks.text,
              isActive: u?.isActive ?? true,
            ),
            fuelType: option.variant.fuelType,
          );
    } on ValidationFailure catch (failure) {
      setState(() => fieldErrors = failure.fieldErrors);
      rethrow;
    } on ConflictFailure catch (failure) {
      if (failure.field != null) {
        setState(() => fieldErrors = <String, String>{failure.field!: failure.message});
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<VariantOption> options = ref.watch(variantOptionsProvider).value ?? const <VariantOption>[];
    final String? fuelType = options.where((VariantOption o) => o.variant.id == variantId).firstOrNull?.variant.fuelType;
    AppTextField identifier(TextEditingController controller, String column, String label, {bool required = false}) {
      return AppTextField(
        controller: controller,
        label: required ? label : '$label (optional)',
        errorText: fieldErrors[column],
        validator: (String? v) =>
            (required ? Validators.required(v, field: label) : null) ??
            (column == 'vin' ? Validators.vin(v) : Validators.vehicleIdentifier(v)),
      );
    }

    return AppFormDialog<String>(
      title: u == null ? 'Register vehicle' : 'Edit vehicle',
      subtitle: u == null ? 'The unit waits for stock receipt (Inventory) before it can be sold.' : u!.chassisNumber,
      submitLabel: u == null ? 'Register' : 'Save',
      onSubmit: () => submit(options),
      children: <Widget>[
        AppDropdown<String>(
          label: 'Variant',
          value: variantId,
          hint: options.isEmpty ? 'Add a variant in the catalogue first' : null,
          items: <AppDropdownItem<String>>[
            for (final VariantOption o in options) AppDropdownItem<String>(value: o.variant.id!, label: o.label),
          ],
          onChanged: (String? v) => setState(() => variantId = v),
        ),
        identifier(vin, 'vin', 'VIN'),
        identifier(chassis, 'chassis_number', 'Chassis number', required: true),
        if (fuelType != null && FuelTypes.hasEngine(fuelType)) identifier(engine, 'engine_number', 'Engine number', required: true),
        if (fuelType != null && FuelTypes.hasMotor(fuelType)) ...<Widget>[
          identifier(motor, 'motor_number', 'Motor number', required: true),
          identifier(battery, 'battery_number', 'Battery number', required: true),
        ],
        AppTextField(controller: color, label: 'Colour (optional)'),
        AppTextField(
          controller: mfgYear,
          label: 'Manufacturing year (optional)',
          keyboardType: TextInputType.number,
          validator: validateYear,
        ),
        AppTextField(
          controller: modelYear,
          label: 'Model year (optional)',
          keyboardType: TextInputType.number,
          validator: validateYear,
        ),
        AppDropdown<String>(
          label: 'Ownership',
          value: ownership,
          items: <AppDropdownItem<String>>[
            for (final MapEntry<String, String> e in Ownerships.labels.entries) AppDropdownItem<String>(value: e.key, label: e.value),
          ],
          onChanged: (String? v) => setState(() => ownership = v ?? ownership),
        ),
        AppDatePicker(
          label: 'Warranty starts (optional; set at delivery for new units)',
          selectedDate: warrantyStart,
          onDateSelected: (DateTime d) => setState(() => warrantyStart = d),
        ),
        AppDatePicker(
          label: 'Warranty ends (optional)',
          selectedDate: warrantyEnd,
          onDateSelected: (DateTime d) => setState(() => warrantyEnd = d),
        ),
        AppTextField(controller: remarks, label: 'Remarks (optional)', maxLines: 3),
      ],
    );
  }
}
