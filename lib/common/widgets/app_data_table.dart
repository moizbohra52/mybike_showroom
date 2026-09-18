import 'package:flutter/material.dart';
import 'package:mybike_showroom/common/widgets/app_card.dart';
import 'package:mybike_showroom/common/widgets/app_empty_state.dart';
import 'package:mybike_showroom/common/widgets/app_loading.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Column definition for [AppDataTable].
class AppDataTableColumn<T> {
  const AppDataTableColumn({
    required this.title,
    required this.cellBuilder,
    this.width,
    this.flex = 1,
    this.alignment = Alignment.centerLeft,
    this.isNumeric = false,
  });

  final String title;
  final Widget Function(BuildContext context, T item) cellBuilder;
  final double? width;
  final int flex;
  final Alignment alignment;
  final bool isNumeric;
}

/// Responsive, clean data table for lists, registers, and grids.
class AppDataTable<T> extends StatelessWidget {
  const AppDataTable({
    required this.columns,
    required this.items,
    this.onRowTap,
    this.loading = false,
    this.emptyMessage = 'No records found',
    this.emptyIcon = Icons.inbox_outlined,
    this.pagination,
    this.minWidth = 600,
    super.key,
  });

  final List<AppDataTableColumn<T>> columns;
  final List<T> items;
  final void Function(T item)? onRowTap;
  final bool loading;
  final String emptyMessage;
  final IconData emptyIcon;
  final Widget? pagination;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    if (loading) {
      return const AppCard(
        padding: EdgeInsets.all(AppDimensions.space40),
        child: Center(child: AppLoading(message: 'Loading data...')),
      );
    }

    if (items.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppDimensions.space40),
        child: AppEmptyState(
          title: emptyMessage,
          icon: emptyIcon,
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minWidth),
              child: IntrinsicWidth(
                child: Column(
                  children: <Widget>[
                    // Header Row
                    Container(
                      height: AppDimensions.tableHeaderHeight,
                      color: palette.hover,
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
                      child: Row(
                        children: columns.map((AppDataTableColumn<T> col) {
                          final Widget text = Text(
                            col.title.toUpperCase(),
                            style: AppTypography.caption.copyWith(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          );
                          return col.width != null
                              ? SizedBox(
                                  width: col.width,
                                  child: Align(
                                    alignment: col.alignment,
                                    child: text,
                                  ),
                                )
                              : Expanded(
                                  flex: col.flex,
                                  child: Align(
                                    alignment: col.alignment,
                                    child: text,
                                  ),
                                );
                        }).toList(),
                      ),
                    ),
                    // Data Rows
                    for (int i = 0; i < items.length; i++)
                      InkWell(
                        onTap: onRowTap != null ? () => onRowTap!(items[i]) : null,
                        child: Container(
                          height: AppDimensions.tableRowHeight,
                          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
                          decoration: BoxDecoration(
                            color: i.isEven ? palette.card : palette.surface,
                            border: Border(
                              bottom: BorderSide(
                                color: palette.border,
                              ),
                            ),
                          ),
                          child: Row(
                            children: columns.map((AppDataTableColumn<T> col) {
                              final Widget cell = col.cellBuilder(context, items[i]);
                              return col.width != null
                                  ? SizedBox(
                                      width: col.width,
                                      child: Align(
                                        alignment: col.alignment,
                                        child: cell,
                                      ),
                                    )
                                  : Expanded(
                                      flex: col.flex,
                                      child: Align(
                                        alignment: col.alignment,
                                        child: cell,
                                      ),
                                    );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          ?pagination,
        ],
      ),
    );
  }
}
