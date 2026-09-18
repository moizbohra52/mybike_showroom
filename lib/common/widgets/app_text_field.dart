import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Form input field adhering to MyBike design standards.
///
/// Features custom label headers, password visibility toggle, prefix/suffix icons,
/// custom error styling, and reactive focus states.
class AppTextField extends StatefulWidget {
  const AppTextField({
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.prefixWidget,
    this.suffixIcon,
    this.suffixWidget,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.focusNode,
    super.key,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? prefixWidget;
  final IconData? suffixIcon;
  final Widget? suffixWidget;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => AppTextFieldState();
}

/// Public state for [AppTextField] allowing access to visibility toggle.
class AppTextFieldState extends State<AppTextField> {
  late bool isObscured;

  @override
  void initState() {
    super.initState();
    isObscured = widget.obscureText;
  }

  /// Toggles visibility for obscured fields.
  void toggleObscure() {
    setState(() {
      isObscured = !isObscured;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    final Widget? prefix = widget.prefixWidget ??
        (widget.prefixIcon != null
            ? Icon(
                widget.prefixIcon,
                size: AppDimensions.iconMd,
                color: palette.textSecondary,
              )
            : null);

    Widget? suffix = widget.suffixWidget;
    if (widget.obscureText) {
      suffix = IconButton(
        icon: Icon(
          isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: AppDimensions.iconMd,
          color: palette.textSecondary,
        ),
        onPressed: toggleObscure,
      );
    } else if (widget.suffixIcon != null && suffix == null) {
      suffix = Icon(
        widget.suffixIcon,
        size: AppDimensions.iconMd,
        color: palette.textSecondary,
      );
    }

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

    final OutlineInputBorder errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      borderSide: BorderSide(
        color: palette.danger,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.label != null && widget.label!.isNotEmpty) ...<Widget>[
          Text(
            widget.label!,
            style: AppTypography.labelMedium.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.space6),
        ],
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          autofocus: widget.autofocus,
          obscureText: isObscured,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          style: AppTypography.bodyMedium.copyWith(
            color: widget.enabled ? palette.textPrimary : palette.textMuted,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: palette.textMuted,
            ),
            helperText: widget.helperText,
            helperStyle: AppTypography.caption.copyWith(
              color: palette.textSecondary,
            ),
            errorText: widget.errorText,
            errorStyle: AppTypography.caption.copyWith(
              color: palette.danger,
            ),
            filled: true,
            fillColor: widget.enabled ? palette.surface : palette.hover,
            prefixIcon: prefix,
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical: AppDimensions.space12,
            ),
            enabledBorder: defaultBorder,
            disabledBorder: defaultBorder.copyWith(
              borderSide: BorderSide(color: palette.border.withValues(alpha: 0.5)),
            ),
            focusedBorder: focusedBorder,
            errorBorder: errorBorder,
            focusedErrorBorder: errorBorder.copyWith(
              borderSide: BorderSide(
                color: palette.danger,
                width: AppDimensions.focusBorderWidth,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
