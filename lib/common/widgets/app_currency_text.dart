import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Money text with tabular digits so columns align.
///
/// Accepts either a pre-formatted [formatted] string (preferred — formatting
/// lives in `FormattingService` from Phase 5+) or a raw [amount] with an
/// optional [currencySymbol] prefix for Phase 2 previews.
class AppCurrencyText extends StatelessWidget {
  const AppCurrencyText.formatted(
    this.formatted, {
    this.style,
    this.color,
    this.large = false,
    super.key,
  })  : amount = null,
        currencySymbol = null;

  const AppCurrencyText(
    this.amount, {
    this.currencySymbol = '₹',
    this.style,
    this.color,
    this.large = false,
    super.key,
  })  : formatted = null;

  final double? amount;
  final String? formatted;
  final String? currencySymbol;
  final TextStyle? style;
  final Color? color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final TextStyle base = large
        ? AppTypography.money.copyWith(fontSize: 20)
        : AppTypography.money;
    final String text =
        formatted ?? '${currencySymbol ?? ''}${compactAmount(amount ?? 0)}';

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: base.copyWith(
        fontFamily: AppTypography.fontFamily,
        fontFamilyFallback: AppTypography.fontFamilyFallback,
        color: color ?? palette.textPrimary,
      ).merge(style),
    );
  }

  /// Public compact representation (e.g. 1.5L, 2.3Cr, 45K).
  static String compactAmount(double value) {
    if (value.abs() >= 10000000) {
      return '${trimDecimals(value / 10000000)} Cr';
    }
    if (value.abs() >= 100000) {
      return '${trimDecimals(value / 100000)} L';
    }
    if (value.abs() >= 1000) {
      return '${trimDecimals(value / 1000)}K';
    }
    return trimDecimals(value);
  }

  /// Public decimal trimming helper for display.
  static String trimDecimals(double value) {
    final String fixed = value.toStringAsFixed(2);
    return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
  }
}
