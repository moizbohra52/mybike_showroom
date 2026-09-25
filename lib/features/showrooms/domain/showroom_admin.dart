import 'package:flutter/foundation.dart';

/// Text form of a nullable column ('' for null) for form fields.
String textOf(Object? value) => value?.toString() ?? '';

/// A showroom (`showrooms` row).
@immutable
class Showroom {
  const Showroom({
    required this.code,
    required this.name,
    required this.invoicePrefix,
    this.id,
    this.legalName,
    this.gstin,
    this.pan,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.stateCode,
    this.pincode,
    this.phone,
    this.email,
    this.openedOn,
    this.isActive = true,
  });

  factory Showroom.fromJson(Map<String, Object?> json) => Showroom(
        id: json['id'] as String?,
        code: json['code']! as String,
        name: json['name']! as String,
        invoicePrefix: json['invoice_prefix']! as String,
        legalName: json['legal_name'] as String?,
        gstin: json['gstin'] as String?,
        pan: json['pan'] as String?,
        addressLine1: json['address_line1'] as String?,
        addressLine2: json['address_line2'] as String?,
        city: json['city'] as String?,
        stateCode: json['state_code'] as String?,
        pincode: json['pincode'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        openedOn: json['opened_on'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  static const String columns = 'id, code, name, legal_name, gstin, pan, address_line1, address_line2, city, '
      'state_code, pincode, phone, email, invoice_prefix, opened_on, is_active';

  /// `null` until created.
  final String? id;
  final String code;
  final String name;
  final String invoicePrefix;
  final String? legalName;
  final String? gstin;
  final String? pan;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? stateCode;
  final String? pincode;
  final String? phone;
  final String? email;

  /// ISO date (yyyy-mm-dd).
  final String? openedOn;
  final bool isActive;

  String get address => <String?>[addressLine1, addressLine2, city, pincode]
      .whereType<String>()
      .where((String s) => s.isNotEmpty)
      .join(', ');

  /// Editable columns (the database normalises case and blanks as well).
  Map<String, Object?> toJson() => <String, Object?>{
        'code': code.trim().toUpperCase(),
        'name': name.trim(),
        'invoice_prefix': invoicePrefix.trim().toUpperCase(),
        'legal_name': legalName,
        'gstin': gstin?.toUpperCase(),
        'pan': pan?.toUpperCase(),
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'city': city,
        'state_code': stateCode,
        'pincode': pincode,
        'phone': phone,
        'email': email,
        'opened_on': openedOn,
      };
}

/// Stock valuation methods (`stock_valuation_method` enum).
abstract final class ValuationMethods {
  static const Map<String, String> labels = <String, String>{
    'specific_id': 'Specific identification (vehicles)',
    'weighted_avg': 'Weighted average',
  };
}

/// `showroom_settings` row. Money stays text end to end (G5).
@immutable
class ShowroomSettings {
  const ShowroomSettings({
    required this.showroomId,
    required this.gstEnabled,
    required this.roundOffEnabled,
    required this.postCogsOnSale,
    required this.allowNegativeStock,
    required this.valuationMethod,
    required this.lowStockThreshold,
    required this.bookingMinAmount,
    required this.bookingValidityDays,
    this.discountApprovalThreshold,
    this.invoiceTerms,
    this.invoiceFooter,
    this.receiptTerms,
  });

  factory ShowroomSettings.fromJson(Map<String, Object?> json) => ShowroomSettings(
        showroomId: json['showroom_id']! as String,
        gstEnabled: json['gst_enabled'] as bool? ?? true,
        roundOffEnabled: json['round_off_enabled'] as bool? ?? true,
        postCogsOnSale: json['post_cogs_on_sale'] as bool? ?? true,
        allowNegativeStock: json['allow_negative_stock'] as bool? ?? false,
        valuationMethod: json['valuation_method'] as String? ?? 'specific_id',
        lowStockThreshold: json['low_stock_threshold'] as int? ?? 0,
        bookingMinAmount: textOf(json['booking_min_amount']),
        bookingValidityDays: json['booking_validity_days'] as int? ?? 30,
        discountApprovalThreshold: json['discount_approval_threshold']?.toString(),
        invoiceTerms: json['invoice_terms'] as String?,
        invoiceFooter: json['invoice_footer'] as String?,
        receiptTerms: json['receipt_terms'] as String?,
      );

  /// Money columns are cast to text so they never pass through a double (G5).
  static const String columns = 'showroom_id, gst_enabled, round_off_enabled, post_cogs_on_sale, allow_negative_stock, '
      'valuation_method, low_stock_threshold, booking_min_amount::text, booking_validity_days, '
      'discount_approval_threshold::text, invoice_terms, invoice_footer, receipt_terms';

  final String showroomId;
  final bool gstEnabled;
  final bool roundOffEnabled;
  final bool postCogsOnSale;
  final bool allowNegativeStock;
  final String valuationMethod;
  final int lowStockThreshold;
  final String bookingMinAmount;
  final int bookingValidityDays;
  final String? discountApprovalThreshold;
  final String? invoiceTerms;
  final String? invoiceFooter;
  final String? receiptTerms;

  /// Same settings with new invoice / receipt texts.
  ShowroomSettings withTexts({String? invoiceTerms, String? invoiceFooter, String? receiptTerms}) => ShowroomSettings(
        showroomId: showroomId,
        gstEnabled: gstEnabled,
        roundOffEnabled: roundOffEnabled,
        postCogsOnSale: postCogsOnSale,
        allowNegativeStock: allowNegativeStock,
        valuationMethod: valuationMethod,
        lowStockThreshold: lowStockThreshold,
        bookingMinAmount: bookingMinAmount,
        bookingValidityDays: bookingValidityDays,
        discountApprovalThreshold: discountApprovalThreshold,
        invoiceTerms: invoiceTerms,
        invoiceFooter: invoiceFooter,
        receiptTerms: receiptTerms,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'gst_enabled': gstEnabled,
        'round_off_enabled': roundOffEnabled,
        'post_cogs_on_sale': postCogsOnSale,
        'allow_negative_stock': allowNegativeStock,
        'valuation_method': valuationMethod,
        'low_stock_threshold': lowStockThreshold,
        // PostgREST casts the JSON string to numeric: no floating point on the way.
        'booking_min_amount': bookingMinAmount,
        'booking_validity_days': bookingValidityDays,
        'discount_approval_threshold': discountApprovalThreshold,
        'invoice_terms': invoiceTerms,
        'invoice_footer': invoiceFooter,
        'receipt_terms': receiptTerms,
      };
}

/// A showroom bank account.
@immutable
class BankAccount {
  const BankAccount({
    required this.showroomId,
    required this.accountName,
    required this.bankName,
    required this.accountNumber,
    required this.ifsc,
    this.id,
    this.branch,
    this.upiId,
    this.isDefault = false,
  });

  factory BankAccount.fromJson(Map<String, Object?> json) => BankAccount(
        id: json['id'] as String?,
        showroomId: json['showroom_id']! as String,
        accountName: json['account_name']! as String,
        bankName: json['bank_name']! as String,
        accountNumber: json['account_number']! as String,
        ifsc: json['ifsc']! as String,
        branch: json['branch'] as String?,
        upiId: json['upi_id'] as String?,
        isDefault: json['is_default'] as bool? ?? false,
      );

  static const String columns = 'id, showroom_id, account_name, bank_name, account_number, ifsc, branch, upi_id, is_default';

  final String? id;
  final String showroomId;
  final String accountName;
  final String bankName;
  final String accountNumber;
  final String ifsc;
  final String? branch;
  final String? upiId;
  final bool isDefault;

  /// Last four digits, for lists.
  String get maskedNumber =>
      accountNumber.length <= 4 ? accountNumber : '•••• ${accountNumber.substring(accountNumber.length - 4)}';

  Map<String, Object?> toJson() => <String, Object?>{
        'showroom_id': showroomId,
        'account_name': accountName.trim(),
        'bank_name': bankName.trim(),
        'account_number': accountNumber.trim(),
        'ifsc': ifsc.trim().toUpperCase(),
        'branch': branch,
        'upi_id': upiId,
        'is_default': isDefault,
      };
}

/// A numbering series of the showroom in an open financial year.
@immutable
class NumberingSeries {
  const NumberingSeries({
    required this.docType,
    required this.prefix,
    required this.nextNumber,
    required this.padding,
    required this.financialYear,
    this.suffix,
  });

  factory NumberingSeries.fromJson(Map<String, Object?> json) => NumberingSeries(
        docType: json['doc_type']! as String,
        prefix: json['prefix']! as String,
        suffix: json['suffix'] as String?,
        nextNumber: json['next_number']! as int,
        padding: json['padding']! as int,
        financialYear: ((json['financial_years']! as Map<Object?, Object?>)['code']) as String,
      );

  final String docType;
  final String prefix;
  final String? suffix;
  final int nextNumber;
  final int padding;

  /// e.g. 2026-27.
  final String financialYear;

  /// The next number as fn_next_document_number() will issue it,
  /// e.g. IND/26-27/00001.
  String get preview =>
      '$prefix/${financialYear.substring(2)}/${nextNumber.toString().padLeft(padding, '0')}${suffix ?? ''}';

  String get label => docType
      .split('_')
      .map((String w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// GST state / union territory.
@immutable
class IndianState {
  const IndianState({required this.code, required this.name});

  factory IndianState.fromJson(Map<String, Object?> json) =>
      IndianState(code: json['code']! as String, name: json['name']! as String);

  final String code;
  final String name;
}
