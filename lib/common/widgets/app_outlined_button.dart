import 'package:flutter/material.dart';
import 'package:mybike_showroom/common/widgets/app_button.dart';

/// Reusable bordered outlined button component.
///
/// Convenience wrapper over [AppButton] with [AppButtonVariant.outline].
class AppOutlinedButton extends StatelessWidget {
  const AppOutlinedButton({
    required this.text,
    this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expanded = false,
    super.key,
  });

  final String text;
  final VoidCallback? onPressed;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      text: text,
      onPressed: onPressed,
      variant: AppButtonVariant.outline,
      size: size,
      icon: icon,
      trailingIcon: trailingIcon,
      loading: loading,
      expanded: expanded,
    );
  }
}
