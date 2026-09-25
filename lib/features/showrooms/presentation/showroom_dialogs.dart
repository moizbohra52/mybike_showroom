import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/errors/app_failure.dart';
import 'package:mybike_showroom/core/utils/text_utils.dart';
import 'package:mybike_showroom/core/validators/validators.dart';
import 'package:mybike_showroom/features/showrooms/application/showrooms_controller.dart';
import 'package:mybike_showroom/features/showrooms/domain/showroom_admin.dart';
import 'package:mybike_showroom/features/users/application/users_controller.dart';
import 'package:mybike_showroom/features/users/domain/user_admin.dart';

/// Creates a showroom (returns its id) or edits [showroom] (returns its id).
/// GST rules mirror the database constraints: the GSTIN starts with the state
/// code and embeds the PAN.
class ShowroomFormDialog extends ConsumerStatefulWidget {
  const ShowroomFormDialog({this.showroom, super.key});

  final Showroom? showroom;

  static Future<String?> show(BuildContext context, {Showroom? showroom}) =>
      showDialog<String>(context: context, builder: (_) => ShowroomFormDialog(showroom: showroom));

  @override
  ConsumerState<ShowroomFormDialog> createState() => ShowroomFormDialogState();
}

class ShowroomFormDialogState extends ConsumerState<ShowroomFormDialog> {
  static final RegExp codePattern = RegExp(r'^[A-Z0-9][A-Z0-9-]{1,19}$');
  static final RegExp prefixPattern = RegExp(r'^[A-Z0-9]{2,3}$');

  late final Showroom? initial = widget.showroom;
  late final TextEditingController name = TextEditingController(text: initial?.name);
  late final TextEditingController code = TextEditingController(text: initial?.code);
  late final TextEditingController prefix = TextEditingController(text: initial?.invoicePrefix);
  late final TextEditingController legalName = TextEditingController(text: initial?.legalName);
  late final TextEditingController gstin = TextEditingController(text: initial?.gstin);
  late final TextEditingController pan = TextEditingController(text: initial?.pan);
  late final TextEditingController address1 = TextEditingController(text: initial?.addressLine1);
  late final TextEditingController address2 = TextEditingController(text: initial?.addressLine2);
  late final TextEditingController city = TextEditingController(text: initial?.city);
  late final TextEditingController pincode = TextEditingController(text: initial?.pincode);
  late final TextEditingController phone = TextEditingController(text: initial?.phone);
  late final TextEditingController email = TextEditingController(text: initial?.email);
  late String? stateCode = initial?.stateCode;
  late DateTime? openedOn = DateTime.tryParse(initial?.openedOn ?? '');

  List<TextEditingController> get controllers =>
      <TextEditingController>[name, code, prefix, legalName, gstin, pan, address1, address2, city, pincode, phone, email];

  @override
  void dispose() {
    for (final TextEditingController c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  String? validateGstin(String? value) {
    final String? format = Validators.gstin(value);
    final String v = (value ?? '').trim().toUpperCase();
    if (format != null || v.isEmpty) {
      return format;
    }
    if (stateCode != null && !v.startsWith(stateCode!)) {
      return 'A GSTIN starts with its state code ($stateCode).';
    }
    final String p = pan.text.trim().toUpperCase();
    if (p.isNotEmpty && v.substring(2, 12) != p) {
      return 'Characters 3–12 of the GSTIN are the PAN ($p).';
    }
    return null;
  }

  Future<String> submit() async {
    final Showroom draft = Showroom(
      code: code.text,
      name: name.text,
      invoicePrefix: prefix.text,
      legalName: blankToNull(legalName.text),
      gstin: blankToNull(gstin.text),
      pan: blankToNull(pan.text),
      addressLine1: blankToNull(address1.text),
      addressLine2: blankToNull(address2.text),
      city: blankToNull(city.text),
      stateCode: stateCode,
      pincode: blankToNull(pincode.text),
      phone: blankToNull(phone.text),
      email: blankToNull(email.text),
      openedOn: openedOn?.toIso8601String().substring(0, 10),
    );
    final ShowroomAdminActions actions = ref.read(showroomAdminActionsProvider);
    if (initial == null) {
      return actions.create(draft);
    }
    await actions.update(initial!.id!, draft);
    return initial!.id!;
  }

  @override
  Widget build(BuildContext context) {
    final List<IndianState> states = ref.watch(indianStatesProvider).value ?? const <IndianState>[];
    return AppFormDialog<String>(
      title: initial == null ? 'New showroom' : 'Edit showroom',
      subtitle: initial == null ? 'Settings and document numbering are created automatically.' : initial!.code,
      submitLabel: initial == null ? 'Create showroom' : 'Save',
      onSubmit: submit,
      children: <Widget>[
        AppTextField(controller: name, label: 'Name', validator: (String? v) => Validators.required(v, field: 'Name')),
        AppTextField(
          controller: code,
          label: 'Code',
          hint: 'DEWAS',
          validator: (String? v) => codePattern.hasMatch((v ?? '').trim().toUpperCase())
              ? null
              : 'Use 2–20 capital letters, digits or dashes.',
        ),
        AppTextField(
          controller: prefix,
          label: 'Invoice prefix',
          hint: 'DWS',
          helperText: 'Starts every document number (DWS/26-27/00001). Frozen once a number is issued.',
          validator: (String? v) =>
              prefixPattern.hasMatch((v ?? '').trim().toUpperCase()) ? null : 'Use 2–3 capital letters or digits.',
        ),
        AppTextField(controller: legalName, label: 'Legal name (printed on invoices)'),
        AppDropdown<String?>(
          label: 'State',
          value: stateCode,
          items: <AppDropdownItem<String?>>[
            const AppDropdownItem<String?>(value: null, label: 'Not set'),
            for (final IndianState s in states) AppDropdownItem<String?>(value: s.code, label: '${s.code} · ${s.name}'),
          ],
          onChanged: (String? v) => setState(() => stateCode = v),
        ),
        AppTextField(controller: gstin, label: 'GSTIN', validator: validateGstin),
        AppTextField(controller: pan, label: 'PAN', validator: Validators.pan),
        AppTextField(controller: address1, label: 'Address line 1'),
        AppTextField(controller: address2, label: 'Address line 2'),
        AppTextField(controller: city, label: 'City'),
        AppTextField(controller: pincode, label: 'PIN code', keyboardType: TextInputType.number, validator: Validators.pincode),
        AppTextField(controller: phone, label: 'Phone', keyboardType: TextInputType.phone, validator: Validators.phone),
        AppTextField(
          controller: email,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
          validator: (String? v) => (v ?? '').trim().isEmpty ? null : Validators.email(v),
        ),
        AppDatePicker(
          label: 'Opened on',
          selectedDate: openedOn,
          lastDate: DateTime.now(),
          onDateSelected: (DateTime d) => setState(() => openedOn = d),
        ),
      ],
    );
  }
}

/// Sales, stock and accounting settings of a showroom.
class ShowroomSettingsDialog extends ConsumerStatefulWidget {
  const ShowroomSettingsDialog({required this.settings, super.key});

  final ShowroomSettings settings;

  static Future<bool?> show(BuildContext context, ShowroomSettings settings) =>
      showDialog<bool>(context: context, builder: (_) => ShowroomSettingsDialog(settings: settings));

  @override
  ConsumerState<ShowroomSettingsDialog> createState() => ShowroomSettingsDialogState();
}

class ShowroomSettingsDialogState extends ConsumerState<ShowroomSettingsDialog> {
  late final ShowroomSettings s = widget.settings;
  late bool gstEnabled = s.gstEnabled;
  late bool roundOff = s.roundOffEnabled;
  late bool postCogs = s.postCogsOnSale;
  late bool negativeStock = s.allowNegativeStock;
  late String valuation = s.valuationMethod;
  late final TextEditingController bookingMin = TextEditingController(text: s.bookingMinAmount);
  late final TextEditingController bookingDays = TextEditingController(text: '${s.bookingValidityDays}');
  late final TextEditingController discount = TextEditingController(text: s.discountApprovalThreshold);
  late final TextEditingController lowStock = TextEditingController(text: '${s.lowStockThreshold}');

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[bookingMin, bookingDays, discount, lowStock]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> submit() async {
    await ref.read(showroomAdminActionsProvider).updateSettings(ShowroomSettings(
          showroomId: s.showroomId,
          gstEnabled: gstEnabled,
          roundOffEnabled: roundOff,
          postCogsOnSale: postCogs,
          allowNegativeStock: negativeStock,
          valuationMethod: valuation,
          lowStockThreshold: int.parse(lowStock.text.trim()),
          bookingMinAmount: bookingMin.text.trim().isEmpty ? '0' : bookingMin.text.trim(),
          bookingValidityDays: int.parse(bookingDays.text.trim()),
          discountApprovalThreshold: blankToNull(discount.text),
          invoiceTerms: s.invoiceTerms,
          invoiceFooter: s.invoiceFooter,
          receiptTerms: s.receiptTerms,
        ));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog<bool>(
      title: 'Showroom settings',
      onSubmit: submit,
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('GST registered'),
          subtitle: const Text('Invoices carry GST; tax rates come from tax settings.'),
          value: gstEnabled,
          onChanged: (bool v) => setState(() => gstEnabled = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Round invoice totals'),
          value: roundOff,
          onChanged: (bool v) => setState(() => roundOff = v),
        ),
        AppTextField(
          controller: bookingMin,
          label: 'Minimum booking amount (₹)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: Validators.amount,
        ),
        AppTextField(
          controller: bookingDays,
          label: 'Booking validity (days)',
          keyboardType: TextInputType.number,
          validator: (String? v) => Validators.wholeNumber(v, min: 1, max: 365),
        ),
        AppTextField(
          controller: discount,
          label: 'Discount needing approval above (₹, optional)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: Validators.amount,
        ),
        AppTextField(
          controller: lowStock,
          label: 'Low stock alert at (units)',
          keyboardType: TextInputType.number,
          validator: (String? v) => Validators.wholeNumber(v, min: 0, max: 100000),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Allow selling below zero stock'),
          value: negativeStock,
          onChanged: (bool v) => setState(() => negativeStock = v),
        ),
        AppDropdown<String>(
          label: 'Stock valuation',
          value: valuation,
          items: <AppDropdownItem<String>>[
            for (final MapEntry<String, String> e in ValuationMethods.labels.entries)
              AppDropdownItem<String>(value: e.key, label: e.value),
          ],
          onChanged: (String? v) => setState(() => valuation = v ?? valuation),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Post cost of goods with every sale'),
          value: postCogs,
          onChanged: (bool v) => setState(() => postCogs = v),
        ),
      ],
    );
  }
}

/// Texts printed on invoices and receipts.
class InvoiceTextsDialog extends ConsumerStatefulWidget {
  const InvoiceTextsDialog({required this.settings, super.key});

  final ShowroomSettings settings;

  static Future<bool?> show(BuildContext context, ShowroomSettings settings) =>
      showDialog<bool>(context: context, builder: (_) => InvoiceTextsDialog(settings: settings));

  @override
  ConsumerState<InvoiceTextsDialog> createState() => InvoiceTextsDialogState();
}

class InvoiceTextsDialogState extends ConsumerState<InvoiceTextsDialog> {
  late final TextEditingController terms = TextEditingController(text: widget.settings.invoiceTerms);
  late final TextEditingController footer = TextEditingController(text: widget.settings.invoiceFooter);
  late final TextEditingController receipt = TextEditingController(text: widget.settings.receiptTerms);

  @override
  void dispose() {
    terms.dispose();
    footer.dispose();
    receipt.dispose();
    super.dispose();
  }

  Future<bool> submit() async {
    await ref.read(showroomAdminActionsProvider).updateSettings(widget.settings.withTexts(
          invoiceTerms: blankToNull(terms.text),
          invoiceFooter: blankToNull(footer.text),
          receiptTerms: blankToNull(receipt.text),
        ));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog<bool>(
      title: 'Invoice texts',
      onSubmit: submit,
      children: <Widget>[
        AppTextField(controller: terms, label: 'Invoice terms', maxLines: 4),
        AppTextField(controller: footer, label: 'Invoice footer', maxLines: 2),
        AppTextField(controller: receipt, label: 'Receipt terms', maxLines: 3),
      ],
    );
  }
}

/// Adds or edits a bank account of a showroom.
class BankAccountDialog extends ConsumerStatefulWidget {
  const BankAccountDialog({required this.showroomId, this.account, super.key});

  final String showroomId;
  final BankAccount? account;

  static Future<bool?> show(BuildContext context, {required String showroomId, BankAccount? account}) =>
      showDialog<bool>(context: context, builder: (_) => BankAccountDialog(showroomId: showroomId, account: account));

  @override
  ConsumerState<BankAccountDialog> createState() => BankAccountDialogState();
}

class BankAccountDialogState extends ConsumerState<BankAccountDialog> {
  late final BankAccount? a = widget.account;
  late final TextEditingController accountName = TextEditingController(text: a?.accountName);
  late final TextEditingController bankName = TextEditingController(text: a?.bankName);
  late final TextEditingController number = TextEditingController(text: a?.accountNumber);
  late final TextEditingController ifsc = TextEditingController(text: a?.ifsc);
  late final TextEditingController branch = TextEditingController(text: a?.branch);
  late final TextEditingController upi = TextEditingController(text: a?.upiId);
  late bool isDefault = a?.isDefault ?? false;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[accountName, bankName, number, ifsc, branch, upi]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> submit() async {
    await ref.read(showroomAdminActionsProvider).saveBankAccount(BankAccount(
          id: a?.id,
          showroomId: widget.showroomId,
          accountName: accountName.text,
          bankName: bankName.text,
          accountNumber: number.text,
          ifsc: ifsc.text,
          branch: blankToNull(branch.text),
          upiId: blankToNull(upi.text),
          isDefault: isDefault,
        ));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog<bool>(
      title: a == null ? 'Add bank account' : 'Edit bank account',
      onSubmit: submit,
      children: <Widget>[
        AppTextField(
          controller: accountName,
          label: 'Account holder',
          validator: (String? v) => Validators.required(v, field: 'Account holder'),
        ),
        AppTextField(controller: bankName, label: 'Bank', validator: (String? v) => Validators.required(v, field: 'Bank')),
        AppTextField(
          controller: number,
          label: 'Account number',
          keyboardType: TextInputType.number,
          validator: (String? v) => Validators.required(v, field: 'Account number') ?? Validators.bankAccountNumber(v),
        ),
        AppTextField(
          controller: ifsc,
          label: 'IFSC',
          validator: (String? v) => Validators.required(v, field: 'IFSC') ?? Validators.ifsc(v),
        ),
        AppTextField(controller: branch, label: 'Branch (optional)'),
        AppTextField(controller: upi, label: 'UPI ID (optional)', validator: Validators.upi),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Print on invoices'),
          subtitle: const Text('Replaces the current default account.'),
          value: isDefault,
          onChanged: (bool v) => setState(() => isDefault = v),
        ),
      ],
    );
  }
}

/// Gives an existing user access to this showroom with a first role. Only
/// users the caller may manage everywhere can be added (RLS decides).
class AssignUserDialog extends ConsumerStatefulWidget {
  const AssignUserDialog({required this.showroomId, required this.showroomName, super.key});

  final String showroomId;
  final String showroomName;

  static Future<bool?> show(BuildContext context, {required String showroomId, required String showroomName}) =>
      showDialog<bool>(
        context: context,
        builder: (_) => AssignUserDialog(showroomId: showroomId, showroomName: showroomName),
      );

  @override
  ConsumerState<AssignUserDialog> createState() => AssignUserDialogState();
}

class AssignUserDialogState extends ConsumerState<AssignUserDialog> {
  String search = '';
  ManagedUser? user;
  String? roleId;

  Future<bool> submit() async {
    if (user == null || roleId == null) {
      throw const ValidationFailure(message: 'Choose a user and a role.');
    }
    await ref.read(userAdminActionsProvider).addShowroom(user!.id, widget.showroomId, roleId: roleId);
    ref.invalidate(usersPageProvider);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final List<ManagedUser> matches = search.isEmpty
        ? const <ManagedUser>[]
        : ref.watch(usersPageProvider(UsersQuery(search: search, pageSize: 8))).value?.items ?? const <ManagedUser>[];
    final List<RoleOption> roles = ref.watch(grantableRolesProvider(widget.showroomId)).value ?? const <RoleOption>[];
    return AppFormDialog<bool>(
      title: 'Assign user',
      subtitle: widget.showroomName,
      submitLabel: 'Assign',
      onSubmit: submit,
      children: <Widget>[
        AppSearchField(
          hint: 'Search name, email or employee code',
          onSubmitted: (String v) => setState(() => search = v.trim()),
          onClear: () => setState(() {
            search = '';
            user = null;
          }),
        ),
        if (search.isNotEmpty && matches.isEmpty) const Text('No matching user you can see.'),
        for (final ManagedUser m in matches)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(user?.id == m.id ? Icons.radio_button_checked : Icons.radio_button_unchecked),
            title: Text(m.fullName),
            subtitle: Text(m.email ?? ''),
            onTap: () => setState(() => user = m),
          ),
        AppDropdown<String>(
          label: 'Role in this showroom',
          value: roleId,
          enabled: roles.isNotEmpty,
          items: <AppDropdownItem<String>>[
            for (final RoleOption r in roles) AppDropdownItem<String>(value: r.id, label: r.name),
          ],
          onChanged: (String? id) => setState(() => roleId = id),
        ),
      ],
    );
  }
}
