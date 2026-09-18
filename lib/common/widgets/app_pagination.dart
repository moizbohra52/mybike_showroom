import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Pagination controls for data tables and paginated lists.
class AppPagination extends StatelessWidget {
  const AppPagination({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.totalItems,
    this.itemsPerPage,
    this.onItemsPerPageChanged,
    this.pageSizeOptions = const <int>[10, 25, 50, 100],
    super.key,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final int? totalItems;
  final int? itemsPerPage;
  final ValueChanged<int?>? onItemsPerPageChanged;
  final List<int> pageSizeOptions;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final bool canGoPrev = currentPage > 1;
    final bool canGoNext = currentPage < totalPages;

    final String rangeText;
    if (totalItems != null && itemsPerPage != null) {
      final int start = (currentPage - 1) * itemsPerPage! + 1;
      final int end = (start + itemsPerPage! - 1).clamp(0, totalItems!);
      rangeText = '$start–$end of $totalItems';
    } else {
      rangeText = 'Page $currentPage of $totalPages';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space12,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          if (itemsPerPage != null && onItemsPerPageChanged != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Rows per page:',
                  style: AppTypography.caption.copyWith(color: palette.textSecondary),
                ),
                const SizedBox(width: AppDimensions.space8),
                DropdownButton<int>(
                  value: itemsPerPage,
                  items: pageSizeOptions.map((int size) {
                    return DropdownMenuItem<int>(
                      value: size,
                      child: Text(
                        '$size',
                        style: AppTypography.bodySmall.copyWith(color: palette.textPrimary),
                      ),
                    );
                  }).toList(),
                  onChanged: onItemsPerPageChanged,
                  underline: const SizedBox.shrink(),
                ),
              ],
            )
          else
            const SizedBox.shrink(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                rangeText,
                style: AppTypography.caption.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(width: AppDimensions.space16),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                iconSize: AppDimensions.iconMd,
                color: canGoPrev ? palette.textPrimary : palette.textMuted,
                onPressed: canGoPrev ? () => onPageChanged(currentPage - 1) : null,
                tooltip: 'Previous Page',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                iconSize: AppDimensions.iconMd,
                color: canGoNext ? palette.textPrimary : palette.textMuted,
                onPressed: canGoNext ? () => onPageChanged(currentPage + 1) : null,
                tooltip: 'Next Page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
