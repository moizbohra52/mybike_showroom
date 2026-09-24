import 'package:flutter/material.dart';
import 'package:mybike_showroom/common/widgets/app_async_view.dart';
import 'package:mybike_showroom/common/widgets/app_button.dart';
import 'package:mybike_showroom/common/widgets/app_dialog.dart';
import 'package:mybike_showroom/common/widgets/app_outlined_button.dart';
import 'package:mybike_showroom/core/errors/error_mapper.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';

/// Modal form: validates [children], runs [onSubmit], shows the mapped failure
/// inline and closes with the result on success (`null` when cancelled).
class AppFormDialog<T> extends StatefulWidget {
  const AppFormDialog({
    required this.title,
    required this.children,
    required this.onSubmit,
    this.subtitle,
    this.submitLabel = 'Save',
    this.destructive = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Future<T> Function() onSubmit;
  final String submitLabel;
  final bool destructive;

  @override
  State<AppFormDialog<T>> createState() => AppFormDialogState<T>();
}

class AppFormDialogState<T> extends State<AppFormDialog<T>> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  bool busy = false;
  String? error;

  Future<void> submit() async {
    if (busy || !(formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final T result = await widget.onSubmit();
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          busy = false;
          error = AppFeedback.describe(ErrorMapper.map(e, stackTrace));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return AppDialog(
      title: widget.title,
      subtitle: widget.subtitle,
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final Widget child in widget.children)
                Padding(padding: const EdgeInsets.only(bottom: AppDimensions.space16), child: child),
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(error!, style: TextStyle(color: palette.danger)),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        AppOutlinedButton(text: 'Cancel', onPressed: busy ? null : () => Navigator.of(context).pop()),
        AppButton(
          text: widget.submitLabel,
          loading: busy,
          variant: widget.destructive ? AppButtonVariant.danger : AppButtonVariant.primary,
          onPressed: busy ? null : submit,
        ),
      ],
    );
  }
}
