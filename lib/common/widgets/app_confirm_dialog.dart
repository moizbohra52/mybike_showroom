import 'package:flutter/material.dart';
import 'package:mybike_showroom/common/widgets/app_button.dart';
import 'package:mybike_showroom/common/widgets/app_dialog.dart';
import 'package:mybike_showroom/common/widgets/app_outlined_button.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Confirmation dialog for user actions (delete, submit, discard).
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
    this.onConfirm,
    this.onCancel,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  /// Public helper showing confirmation dialog and returning true on confirm.
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final bool? result = await AppDialog.show<bool>(
      context: context,
      title: title,
      content: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(
          color: AppPalette.of(context).textSecondary,
        ),
      ),
      actions: <Widget>[
        AppOutlinedButton(
          text: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          text: confirmLabel,
          variant: isDestructive ? AppButtonVariant.danger : AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return AppDialog(
      title: title,
      content: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(color: palette.textSecondary),
      ),
      actions: <Widget>[
        AppOutlinedButton(
          text: cancelLabel,
          onPressed: () {
            onCancel?.call();
            Navigator.of(context).pop(false);
          },
        ),
        AppButton(
          text: confirmLabel,
          variant: isDestructive ? AppButtonVariant.danger : AppButtonVariant.primary,
          onPressed: () {
            onConfirm?.call();
            Navigator.of(context).pop(true);
          },
        ),
      ],
    );
  }
}
