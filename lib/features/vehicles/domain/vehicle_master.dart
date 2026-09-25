import 'package:flutter/foundation.dart';
import 'package:mybike_showroom/core/utils/text_utils.dart';

/// Fuel types (`fuel_type` enum) and which specifications each one uses —
/// the same rules as the database CHECKs.
abstract final class FuelTypes {
  static const String petrol = 'petrol';
  static const String electric = 'electric';
  static const String cng = 'cng';
  static const String hybrid = 'hybrid';

  static const Map<String, String> labels = <String, String>{
    petrol: 'Petrol',
    electric: 'Electric',
    cng: 'CNG',
    hybrid: 'Hybrid',
  };

  /// Engine specifications / engine number (everything but electric).
  static bool hasEngine(String fuelType) => fuelType != electric;

  /// Motor + battery specifications / numbers (electric and hybrid).
  static bool hasMotor(String fuelType) => fuelType == electric || fuelType == hybrid;
}

abstract final class VehicleCategories {
  static const Map<String, String> labels = <String, String>{
    'motorcycle': 'Motorcycle',
    'scooter': 'Scooter',
    'moped': 'Moped',
    'bicycle': 'Bicycle',
  };
}

abstract final class VehicleStatuses {
  static const Map<String, String> labels = <String, String>{
    'purchased': 'Awaiting receipt',
    'in_transit': 'In transit',
    'received': 'Received',
    'in_stock': 'In stock',
    'reserved': 'Reserved',
    'transferred': 'Transferred',
    'sold': 'Sold',
    'delivered': 'Delivered',
    'damaged': 'Damaged',
    'returned_to_supplier': 'Returned to supplier',
  };

  static String label(String status) => labels[status] ?? status;
}

abstract final class Ownerships {
  static const Map<String, String> labels = <String, String>{'new': 'New', 'used': 'Used', 'demo': 'Demo'};
}

@immutable
class VehicleBrand {
  const VehicleBrand({
    required this.code,
    required this.name,
    this.id,
    this.country,
    this.isActive = true,
    this.models = const <VehicleModel>[],
  });

  factory VehicleBrand.fromJson(Map<String, Object?> json) => VehicleBrand(
        id: json['id'] as String?,
        code: json['code']! as String,
        name: json['name']! as String,
        country: json['country'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        models: <VehicleModel>[
          for (final Object? row in (json['vehicle_models'] as List<Object?>?) ?? const <Object?>[])
            VehicleModel.fromJson((row! as Map<Object?, Object?>).cast<String, Object?>()),
        ]..sort((VehicleModel a, VehicleModel b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      );

  final String? id;
  final String code;
  final String name;
  final String? country;
  final bool isActive;
  final List<VehicleModel> models;

  Map<String, Object?> toJson() => <String, Object?>{
        'code': code.trim().toUpperCase(),
        'name': name.trim(),
        'country': blankToNull(country),
        'is_active': isActive,
      };
}

@immutable
class VehicleModel {
  const VehicleModel({
    required this.brandId,
    required this.name,
    required this.category,
    this.id,
    this.isActive = true,
    this.variants = const <VehicleVariant>[],
  });

  factory VehicleModel.fromJson(Map<String, Object?> json) => VehicleModel(
        id: json['id'] as String?,
        brandId: json['brand_id']! as String,
        name: json['name']! as String,
        category: json['category']! as String,
        isActive: json['is_active'] as bool? ?? true,
        variants: <VehicleVariant>[
          for (final Object? row in (json['vehicle_variants'] as List<Object?>?) ?? const <Object?>[])
            VehicleVariant.fromJson((row! as Map<Object?, Object?>).cast<String, Object?>()),
        ]..sort((VehicleVariant a, VehicleVariant b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      );

  final String? id;
  final String brandId;
  final String name;
  final String category;
  final bool isActive;
  final List<VehicleVariant> variants;

  Map<String, Object?> toJson() => <String, Object?>{
        'brand_id': brandId,
        'name': name.trim(),
        'category': category,
        'is_active': isActive,
      };
}

/// A variant with its specifications. Numbers are kept as the database text
/// (selected with ::text): exact for money (G5), and edited as typed.
@immutable
class VehicleVariant {
  const VehicleVariant({
    required this.modelId,
    required this.name,
    required this.fuelType,
    this.id,
    this.hsnCode,
    this.exShowroomPrice,
    this.transmission,
    this.topSpeedKmph,
    this.engineCc,
    this.mileageKmpl,
    this.fuelTankLitres,
    this.motorPowerKw,
    this.batteryCapacityKwh,
    this.batteryType,
    this.rangeKm,
    this.chargingTimeHours,
    this.chargingType,
    this.warrantyMonths,
    this.warrantyKm,
    this.batteryWarrantyMonths,
    this.batteryWarrantyKm,
    this.isActive = true,
  });

  factory VehicleVariant.fromJson(Map<String, Object?> json) => VehicleVariant(
        id: json['id'] as String?,
        modelId: json['model_id']! as String,
        name: json['name']! as String,
        fuelType: json['fuel_type']! as String,
        hsnCode: json['hsn_code'] as String?,
        exShowroomPrice: json['ex_showroom_price'] as String?,
        transmission: json['transmission'] as String?,
        topSpeedKmph: json['top_speed_kmph'] as String?,
        engineCc: json['engine_cc'] as String?,
        mileageKmpl: json['mileage_kmpl'] as String?,
        fuelTankLitres: json['fuel_tank_litres'] as String?,
        motorPowerKw: json['motor_power_kw'] as String?,
        batteryCapacityKwh: json['battery_capacity_kwh'] as String?,
        batteryType: json['battery_type'] as String?,
        rangeKm: json['range_km'] as String?,
        chargingTimeHours: json['charging_time_hours'] as String?,
        chargingType: json['charging_type'] as String?,
        warrantyMonths: json['warranty_months'] as String?,
        warrantyKm: json['warranty_km'] as String?,
        batteryWarrantyMonths: json['battery_warranty_months'] as String?,
        batteryWarrantyKm: json['battery_warranty_km'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  /// Numeric columns as text so no value passes through a double.
  static const String columns = 'id, model_id, name, fuel_type, hsn_code, ex_showroom_price::text, transmission, '
      'top_speed_kmph::text, engine_cc::text, mileage_kmpl::text, fuel_tank_litres::text, motor_power_kw::text, '
      'battery_capacity_kwh::text, battery_type, range_km::text, charging_time_hours::text, charging_type, '
      'warranty_months::text, warranty_km::text, battery_warranty_months::text, battery_warranty_km::text, is_active';

  final String? id;
  final String modelId;
  final String name;
  final String fuelType;
  final String? hsnCode;
  final String? exShowroomPrice;
  final String? transmission;
  final String? topSpeedKmph;
  final String? engineCc;
  final String? mileageKmpl;
  final String? fuelTankLitres;
  final String? motorPowerKw;
  final String? batteryCapacityKwh;
  final String? batteryType;
  final String? rangeKm;
  final String? chargingTimeHours;
  final String? chargingType;
  final String? warrantyMonths;
  final String? warrantyKm;
  final String? batteryWarrantyMonths;
  final String? batteryWarrantyKm;
  final bool isActive;

  bool get hasEngine => FuelTypes.hasEngine(fuelType);
  bool get hasMotor => FuelTypes.hasMotor(fuelType);

  /// Specifications that do not apply to the fuel type are sent as NULL, so a
  /// variant switched from petrol to electric does not keep its engine data.
  Map<String, Object?> toJson() {
    String? engine(String? v) => hasEngine ? blankToNull(v) : null;
    String? motor(String? v) => hasMotor ? blankToNull(v) : null;
    return <String, Object?>{
      'model_id': modelId,
      'name': name.trim(),
      'fuel_type': fuelType,
      'hsn_code': blankToNull(hsnCode),
      'ex_showroom_price': blankToNull(exShowroomPrice),
      'transmission': blankToNull(transmission),
      'top_speed_kmph': blankToNull(topSpeedKmph),
      'engine_cc': engine(engineCc),
      'mileage_kmpl': engine(mileageKmpl),
      'fuel_tank_litres': engine(fuelTankLitres),
      'motor_power_kw': motor(motorPowerKw),
      'battery_capacity_kwh': motor(batteryCapacityKwh),
      'battery_type': motor(batteryType),
      'range_km': motor(rangeKm),
      'charging_time_hours': motor(chargingTimeHours),
      'charging_type': motor(chargingType),
      'warranty_months': blankToNull(warrantyMonths),
      'warranty_km': blankToNull(warrantyKm),
      'battery_warranty_months': motor(batteryWarrantyMonths),
      'battery_warranty_km': motor(batteryWarrantyKm),
      'is_active': isActive,
    };
  }

  /// "36 months / 42000 km" style text, or null.
  static String? warrantyText(String? months, String? km) {
    final List<String> parts = <String>[
      if (months != null) '$months months',
      if (km != null) '$km km',
    ];
    return parts.isEmpty ? null : parts.join(' / ');
  }
}

/// A variant with its brand and model names, for pickers and lists.
@immutable
class VariantOption {
  const VariantOption({required this.variant, required this.brandName, required this.modelName});

  final VehicleVariant variant;
  final String brandName;
  final String modelName;

  String get label => '$brandName $modelName ${variant.name} · ${FuelTypes.labels[variant.fuelType]}';
}

/// A physical vehicle of a showroom.
@immutable
class VehicleUnit {
  const VehicleUnit({
    required this.showroomId,
    required this.variantId,
    required this.chassisNumber,
    this.id,
    this.fuelType = FuelTypes.petrol,
    this.vin,
    this.engineNumber,
    this.motorNumber,
    this.batteryNumber,
    this.color,
    this.manufacturingYear,
    this.modelYear,
    this.ownership = 'new',
    this.status = 'purchased',
    this.warrantyStart,
    this.warrantyEnd,
    this.remarks,
    this.isActive = true,
    this.variantLabel,
  });

  factory VehicleUnit.fromJson(Map<String, Object?> json) {
    final Map<Object?, Object?>? variant = json['vehicle_variants'] as Map<Object?, Object?>?;
    final Map<Object?, Object?>? model = variant?['vehicle_models'] as Map<Object?, Object?>?;
    final Map<Object?, Object?>? brand = model?['vehicle_brands'] as Map<Object?, Object?>?;
    return VehicleUnit(
      id: json['id'] as String?,
      showroomId: json['showroom_id']! as String,
      variantId: json['variant_id']! as String,
      fuelType: json['fuel_type'] as String? ?? FuelTypes.petrol,
      vin: json['vin'] as String?,
      chassisNumber: json['chassis_number']! as String,
      engineNumber: json['engine_number'] as String?,
      motorNumber: json['motor_number'] as String?,
      batteryNumber: json['battery_number'] as String?,
      color: json['color'] as String?,
      manufacturingYear: json['manufacturing_year'] as int?,
      modelYear: json['model_year'] as int?,
      ownership: json['ownership'] as String? ?? 'new',
      status: json['status'] as String? ?? 'purchased',
      warrantyStart: json['warranty_start'] as String?,
      warrantyEnd: json['warranty_end'] as String?,
      remarks: json['remarks'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      variantLabel: variant == null ? null : '${brand?['name'] ?? ''} ${model?['name'] ?? ''} ${variant['name']}'.trim(),
    );
  }

  static const String columns = 'id, showroom_id, variant_id, fuel_type, vin, chassis_number, engine_number, '
      'motor_number, battery_number, color, manufacturing_year, model_year, ownership, status, warranty_start, '
      'warranty_end, remarks, is_active, vehicle_variants(name, vehicle_models(name, vehicle_brands(name)))';

  final String? id;
  final String showroomId;
  final String variantId;

  /// From the variant (set by the database).
  final String fuelType;
  final String? vin;
  final String chassisNumber;
  final String? engineNumber;
  final String? motorNumber;
  final String? batteryNumber;
  final String? color;
  final int? manufacturingYear;
  final int? modelYear;
  final String ownership;
  final String status;
  final String? warrantyStart;
  final String? warrantyEnd;
  final String? remarks;
  final bool isActive;
  final String? variantLabel;

  /// Columns a client may write; fuel type, status and showroom (on update)
  /// are the database's. Identifiers that do not apply to [forFuelType] are
  /// sent as NULL.
  Map<String, Object?> toJson({required String forFuelType, required bool insert}) {
    final bool engine = FuelTypes.hasEngine(forFuelType);
    final bool motor = FuelTypes.hasMotor(forFuelType);
    return <String, Object?>{
      if (insert) 'showroom_id': showroomId,
      'variant_id': variantId,
      'vin': blankToNull(vin),
      'chassis_number': chassisNumber.trim(),
      'engine_number': engine ? blankToNull(engineNumber) : null,
      'motor_number': motor ? blankToNull(motorNumber) : null,
      'battery_number': motor ? blankToNull(batteryNumber) : null,
      'color': blankToNull(color),
      'manufacturing_year': manufacturingYear,
      'model_year': modelYear,
      'ownership': ownership,
      'warranty_start': warrantyStart,
      'warranty_end': warrantyEnd,
      'remarks': blankToNull(remarks),
      if (!insert) 'is_active': isActive,
    };
  }
}

/// Vehicle register filter; `showroomId == null` = every accessible showroom.
@immutable
class UnitsQuery {
  const UnitsQuery({this.showroomId, this.search = '', this.page = 1, this.pageSize = 25});

  final String? showroomId;
  final String search;
  final int page;
  final int pageSize;

  UnitsQuery copyWith({String? Function()? showroomId, String? search, int? page}) => UnitsQuery(
        showroomId: showroomId == null ? this.showroomId : showroomId(),
        search: search ?? this.search,
        page: page ?? this.page,
        pageSize: pageSize,
      );

  @override
  bool operator ==(Object other) =>
      other is UnitsQuery &&
      other.showroomId == showroomId &&
      other.search == search &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(showroomId, search, page, pageSize);
}

@immutable
class UnitsPage {
  const UnitsPage({required this.items, required this.total});

  final List<VehicleUnit> items;
  final int total;
}
