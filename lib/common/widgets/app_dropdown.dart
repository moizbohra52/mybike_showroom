import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Item representation for [AppDropdown].
class AppDropdownItem<T> {
  const AppDropdownItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// Generic dropdown selector conforming to MyBike styling.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    required this.items,
    this.value,
    this.onChanged,
    this.label,
    this.hint,
    this.errorText,
    this.prefixIcon,
    this.enabled = true,
    super.key,
  });

  final List<AppDropdownItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hint;
  final String? errorText;
  final IconData? prefixIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    final OutlineInputBorder defaultBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      borderSide: BorderSide(
        color: palette.border,
      ),
    );

    final OutlineInputBorder focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      borderSide: BorderSide(
        color: palette.brandPrimary,
        width: AppDimensions.focusBorderWidth,
      ),
    );

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
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items.map((AppDropdownItem<T> item) {
            return DropdownMenuItem<T>(
              value: item.value,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (item.icon != null) ...<Widget>[
                    Icon(item.icon, size: AppDimensions.iconSm, color: palette.textSecondary),
                    const SizedBox(width: AppDimensions.space8),
                  ],
                  Text(
                    item.label,
                    style: AppTypography.bodyMedium.copyWith(color: palette.textPrimary),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
          dropdownColor: palette.surface,
          icon: Icon(Icons.arrow_drop_down, color: palette.textSecondary),
          style: AppTypography.bodyMedium.copyWith(color: palette.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.bodyMedium.copyWith(color: palette.textMuted),
            errorText: errorText,
            errorStyle: AppTypography.caption.copyWith(color: palette.danger),
            filled: true,
            fillColor: enabled ? palette.surface : palette.hover,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: AppDimensions.iconMd, color: palette.textSecondary)
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical: AppDimensions.space12,
            ),
            enabledBorder: defaultBorder,
            disabledBorder: defaultBorder.copyWith(
              borderSide: BorderSide(color: palette.border.withValues(alpha: 0.5)),
            ),
            focusedBorder: focusedBorder,
          ),
        ),
      ],
    );
  }
}
