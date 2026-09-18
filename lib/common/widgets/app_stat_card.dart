import 'package:flutter/material.dart';
import 'package:mybike_showroom/common/widgets/app_card.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// KPI card: overline label + large tabular value + optional delta row.
///
/// Used on dashboards for Total Sales, Stock Value, Receivable, Cash Balance,
/// etc. `deltaText`/`deltaPositive` render the trend chip; `onTap` makes the
/// whole card tappable (e.g. drill into a report).
class AppStatCard extends StatelessWidget {
  const AppStatCard({
    required this.label,
    required this.value,
    this.icon,
    this.deltaText,
    this.deltaPositive,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? deltaText;
  final bool? deltaPositive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final bool hasDelta =
        deltaText != null && deltaText!.isNotEmpty && deltaPositive != null;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: AppDimensions.iconMd, color: palette.textSecondary),
                const SizedBox(width: AppDimensions.space8),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.overline.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.kpiValue.copyWith(
              color: palette.textPrimary,
              fontFamily: AppTypography.fontFamily,
              fontFamilyFallback: AppTypography.fontFamilyFallback,
            ),
          ),
          if (hasDelta) ...<Widget>[
            const SizedBox(height: AppDimensions.space8),
            AppDeltaChip(
              text: deltaText!,
              positive: deltaPositive!,
              palette: palette,
            ),
          ],
        ],
      ),
    );
  }
}

/// Trend chip showing positive/negative movement with an icon and percentage/label.
class AppDeltaChip extends StatelessWidget {
  const AppDeltaChip({
    required this.text,
    required this.positive,
    required this.palette,
    super.key,
  });

  final String text;
  final bool positive;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final Color foreground = positive ? palette.success : palette.danger;
    final Color background =
        positive ? palette.successSoft : palette.dangerSoft;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            positive ? Icons.trending_up : Icons.trending_down,
            size: AppDimensions.iconSm,
            color: foreground,
          ),
          const SizedBox(width: AppDimensions.space4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
