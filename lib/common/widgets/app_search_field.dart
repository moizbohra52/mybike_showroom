import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Specialized search input field with clear action and search icon.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.hint = 'Search...',
    this.autofocus = false,
    super.key,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final String hint;
  final bool autofocus;

  @override
  State<AppSearchField> createState() => AppSearchFieldState();
}

/// Public state for [AppSearchField].
class AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController internalController;
  bool showClear = false;

  @override
  void initState() {
    super.initState();
    internalController = widget.controller ?? TextEditingController();
    showClear = internalController.text.isNotEmpty;
    internalController.addListener(handleTextChange);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      internalController.dispose();
    } else {
      internalController.removeListener(handleTextChange);
    }
    super.dispose();
  }

  /// Handles internal text changes to update clear button visibility.
  void handleTextChange() {
    final bool shouldShow = internalController.text.isNotEmpty;
    if (showClear != shouldShow) {
      setState(() {
        showClear = shouldShow;
      });
    }
  }

  /// Clears the search text field.
  void clear() {
    internalController.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return SizedBox(
      height: AppDimensions.controlHeight,
      child: TextField(
        controller: internalController,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        style: AppTypography.bodyMedium.copyWith(color: palette.textPrimary),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: AppTypography.bodyMedium.copyWith(color: palette.textMuted),
          prefixIcon: Icon(
            Icons.search,
            size: AppDimensions.iconMd,
            color: palette.textSecondary,
          ),
          suffixIcon: showClear
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: AppDimensions.iconSm,
                    color: palette.textSecondary,
                  ),
                  onPressed: clear,
                )
              : null,
          filled: true,
          fillColor: palette.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space16,
            vertical: AppDimensions.space8,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: BorderSide(
              color: palette.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            borderSide: BorderSide(
              color: palette.brandPrimary,
              width: AppDimensions.focusBorderWidth,
            ),
          ),
        ),
      ),
    );
  }
}
