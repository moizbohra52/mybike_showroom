import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Semantic intent of a status badge.
enum AppStatusIntent { success, warning, danger, info, neutral }

/// Pill badge for entity states (booking confirmed, stock low, invoice paid…).
///
/// Either pass a raw [label] with an [intent], or use [AppStatusBadge.fromKey]
/// with a domain status string (e.g. `'confirmed'`, `'sold'`, `'overdue'`);
/// unknown keys fall back to neutral.
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    required this.label,
    this.intent = AppStatusIntent.neutral,
    super.key,
  });

  AppStatusBadge.fromKey({
    required String statusKey,
    super.key,
  })  : label = statusKey,
        intent = intentFor(statusKey);

  final String label;
  final AppStatusIntent intent;

  /// Public resolution of domain status string to [AppStatusIntent].
  static AppStatusIntent intentFor(String key) {
    return switch (key.trim().toLowerCase()) {
      'active' || 'available' || 'confirmed' || 'paid' || 'delivered' ||
      'completed' || 'approved' || 'received' || 'in_stock' =>
        AppStatusIntent.success,
      'pending' || 'reserved' || 'partial' || 'in_transit' || 'due_soon' ||
      'low_stock' =>
        AppStatusIntent.warning,
      'cancelled' || 'overdue' || 'damaged' || 'failed' || 'rejected' ||
      'unpaid' =>
        AppStatusIntent.danger,
      'draft' || 'ordered' || 'booked' || 'transferred' => AppStatusIntent.info,
      _ => AppStatusIntent.neutral,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final (Color fg, Color bg) = switch (intent) {
      AppStatusIntent.success => (palette.success, palette.successSoft),
      AppStatusIntent.warning => (palette.warning, palette.warningSoft),
      AppStatusIntent.danger => (palette.danger, palette.dangerSoft),
      AppStatusIntent.info => (palette.info, palette.infoSoft),
      AppStatusIntent.neutral => (palette.textSecondary, palette.hover),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
