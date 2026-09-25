import 'package:flutter/material.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';

/// Label / value line of a detail card: side by side on wide screens,
/// stacked on phones. Empty values show as a dash.
class AppInfoRow extends StatelessWidget {
  const AppInfoRow({required this.label, required this.value, super.key});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Widget labelText = Text(label, style: TextStyle(color: palette.textSecondary));
    final Widget valueText = Text(value == null || value!.isEmpty ? '—' : value!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space4),
      child: context.isCompactLayout
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[labelText, valueText])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[SizedBox(width: 220, child: labelText), Expanded(child: valueText)],
            ),
    );
  }
}
