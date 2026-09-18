import 'package:flutter/material.dart';
import 'package:mybike_showroom/common/widgets/app_card.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Module navigation card for dashboards and home grids.
///
/// Icon tile + title + subtitle + trailing chevron; taps route to a module.
/// Distinct from [AppStatCard] (which shows a KPI value).
class AppDashboardCard extends StatelessWidget {
  const AppDashboardCard({
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
    super.key,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: AppDimensions.controlHeightLg,
            height: AppDimensions.controlHeightLg,
            decoration: BoxDecoration(
              color: palette.brandSoft,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Icon(icon, color: palette.brandPrimary, size: AppDimensions.icon),
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppDimensions.space2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.space8),
          Icon(
            Icons.chevron_right,
            color: palette.textMuted,
            size: AppDimensions.iconMd,
          ),
        ],
      ),
    );
  }
}
