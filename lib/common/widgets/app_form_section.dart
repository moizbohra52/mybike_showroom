import 'package:flutter/material.dart';
import 'package:mybike_showroom/common/widgets/app_card.dart';
import 'package:mybike_showroom/common/widgets/app_section_header.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';

/// Form section wrapping a logical group of inputs inside an [AppCard].
class AppFormSection extends StatelessWidget {
  const AppFormSection({
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.spacing = AppDimensions.space16,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppSectionHeader(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
          ),
          const SizedBox(height: AppDimensions.space8),
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      ),
    );
  }
}
