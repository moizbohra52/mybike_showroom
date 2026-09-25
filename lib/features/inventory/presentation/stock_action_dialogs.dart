import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/validators/validators.dart';
import 'package:mybike_showroom/features/inventory/application/inventory_controller.dart';

/// Receives a purchased vehicle into stock with its unit cost.
class ReceiveStockDialog extends ConsumerStatefulWidget {
  const ReceiveStockDialog({required this.vehicleId, super.key});

  final String vehicleId;

  static Future<bool?> show(BuildContext context, String vehicleId) =>
      showDialog<bool>(context: context, builder: (_) => ReceiveStockDialog(vehicleId: vehicleId));

  @override
  ConsumerState<ReceiveStockDialog> createState() => ReceiveStockDialogState();
}

class ReceiveStockDialogState extends ConsumerState<ReceiveStockDialog> {
  final TextEditingController unitCost = TextEditingController();
  final TextEditingController referenceNo = TextEditingController();
  final TextEditingController remarks = TextEditingController();

  @override
  void dispose() {
    unitCost.dispose();
    referenceNo.dispose();
    remarks.dispose();
    super.dispose();
  }

  Future<bool> submit() async {
    await ref.read(inventoryActionsProvider).receiveVehicle(
          widget.vehicleId,
          unitCost.text.trim(),
          referenceNo: referenceNo.text.trim().isEmpty ? null : referenceNo.text.trim(),
          remarks: remarks.text.trim().isEmpty ? null : remarks.text.trim(),
        );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog<bool>(
      title: 'Receive stock',
      subtitle: 'Moves this vehicle from awaiting receipt to in stock.',
      submitLabel: 'Receive',
      onSubmit: submit,
      children: <Widget>[
        AppTextField(
          controller: unitCost,
          label: 'Unit cost (₹)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String? v) => Validators.required(v, field: 'Unit cost') ?? Validators.amount(v),
        ),
        AppTextField(controller: referenceNo, label: 'Reference no. (optional)', hint: 'GRN / invoice number'),
        AppTextField(controller: remarks, label: 'Remarks (optional)', maxLines: 2),
      ],
    );
  }
}

/// Holds an in-stock vehicle for a customer.
class ReserveVehicleDialog extends ConsumerStatefulWidget {
  const ReserveVehicleDialog({required this.vehicleId, super.key});

  final String vehicleId;

  static Future<bool?> show(BuildContext context, String vehicleId) =>
      showDialog<bool>(context: context, builder: (_) => ReserveVehicleDialog(vehicleId: vehicleId));

  @override
  ConsumerState<ReserveVehicleDialog> createState() => ReserveVehicleDialogState();
}

class ReserveVehicleDialogState extends ConsumerState<ReserveVehicleDialog> {
  final TextEditingController reason = TextEditingController();

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<bool> submit() async {
    await ref
        .read(inventoryActionsProvider)
        .reserveVehicle(widget.vehicleId, reason: reason.text.trim().isEmpty ? null : reason.text.trim());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog<bool>(
      title: 'Reserve vehicle',
      submitLabel: 'Reserve',
      onSubmit: submit,
      children: <Widget>[AppTextField(controller: reason, label: 'Reason (optional)', hint: 'Customer name / booking')],
    );
  }
}

/// Releases a vehicle's active reservation, or marks it damaged — both need a
/// required reason, so they share one small form. The caller supplies the
/// action itself (it already has `ref`); this widget only collects the reason.
class ReasonRequiredDialog extends StatefulWidget {
  const ReasonRequiredDialog({
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    this.destructive = false,
    super.key,
  });

  final String title;
  final String submitLabel;
  final Future<void> Function(String reason) onSubmit;
  final bool destructive;

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String submitLabel,
    required Future<void> Function(String reason) onSubmit,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ReasonRequiredDialog(title: title, submitLabel: submitLabel, onSubmit: onSubmit, destructive: destructive),
    );
  }

  @override
  State<ReasonRequiredDialog> createState() => ReasonRequiredDialogState();
}

class ReasonRequiredDialogState extends State<ReasonRequiredDialog> {
  final TextEditingController reason = TextEditingController();

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<bool> submit() async {
    await widget.onSubmit(reason.text.trim());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog<bool>(
      title: widget.title,
      submitLabel: widget.submitLabel,
      destructive: widget.destructive,
      onSubmit: submit,
      children: <Widget>[
        AppTextField(controller: reason, label: 'Reason', validator: (String? v) => Validators.required(v, field: 'Reason')),
      ],
    );
  }
}
