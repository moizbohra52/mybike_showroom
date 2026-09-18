import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Form date picker input component.
class AppDatePicker extends StatelessWidget {
  const AppDatePicker({
    required this.selectedDate,
    required this.onDateSelected,
    this.label,
    this.hint = 'Select date',
    this.firstDate,
    this.lastDate,
    this.enabled = true,
    this.dateFormat,
    super.key,
  });

  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final String? label;
  final String hint;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;
  final DateFormat? dateFormat;

  /// Selects a date using the Material date picker.
  Future<void> pickDate(BuildContext context) async {
    if (!enabled) return;

    final DateTime now = DateTime.now();
    final DateTime initial = selectedDate ?? now;
    final DateTime first = firstDate ?? DateTime(2020);
    final DateTime last = lastDate ?? DateTime(2035);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : (initial.isAfter(last) ? last : initial),
      firstDate: first,
      lastDate: last,
      builder: (BuildContext ctx, Widget? child) {
        final AppPalette palette = AppPalette.of(ctx);
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: palette.brandPrimary,
              onPrimary: palette.brandOnPrimary,
              surface: palette.surface,
              onSurface: palette.textPrimary,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final DateFormat formatter = dateFormat ?? DateFormat('dd MMM yyyy');
    final String displayText = selectedDate != null ? formatter.format(selectedDate!) : hint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label != null && label!.isNotEmpty) ...<Widget>[
          Text(
            label!,
            style: AppTypography.labelMedium.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.space6),
        ],
        InkWell(
          onTap: enabled ? () => pickDate(context) : null,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Container(
            height: AppDimensions.controlHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
            decoration: BoxDecoration(
              color: enabled ? palette.surface : palette.hover,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(
                color: palette.border,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.calendar_today_outlined,
                  size: AppDimensions.iconSm,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Text(
                    displayText,
                    style: AppTypography.bodyMedium.copyWith(
                      color: selectedDate != null ? palette.textPrimary : palette.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
