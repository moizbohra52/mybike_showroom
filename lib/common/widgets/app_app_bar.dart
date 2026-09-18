import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Standard top application bar across screens.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.showBottomBorder = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBottomBorder;

  @override
  Size get preferredSize => const Size.fromHeight(AppDimensions.headerHeight);

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        color: palette.surface,
        border: showBottomBorder
            ? Border(bottom: BorderSide(color: palette.border))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: AppDimensions.space8),
          ] else if (Navigator.of(context).canPop()) ...<Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              color: palette.textPrimary,
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back',
            ),
            const SizedBox(width: AppDimensions.space8),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: palette.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          ...?actions,
        ],
      ),
    );
  }
}
