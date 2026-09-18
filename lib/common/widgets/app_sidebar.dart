import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/routes/navigation_registry.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Navigation item for [AppSidebar].
class AppSidebarItem {
  const AppSidebarItem({
    required this.title,
    required this.icon,
    required this.path,
    this.badge,
  });

  final String title;
  final IconData icon;
  final String path;
  final String? badge;
}

/// Desktop / Web left navigation sidebar.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    required this.currentPath,
    required this.onNavigate,
    this.entries,
    this.header,
    this.footer,
    this.width = AppDimensions.sidebarWidth,
    super.key,
  });

  final String currentPath;
  final ValueChanged<String> onNavigate;
  final List<AppSidebarItem>? entries;
  final Widget? header;
  final Widget? footer;
  final double width;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final List<AppSidebarItem> items = entries ??
        NavigationRegistry.sidebarEntries
            .map(
              (NavigationEntry e) => AppSidebarItem(
                title: e.label,
                icon: e.icon,
                path: e.path,
              ),
            )
            .toList();

    return Material(
      color: palette.sidebarBackground,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: palette.border)),
        ),
        child: Column(
          children: <Widget>[
            // Header / Brand
            if (header != null)
              header!
            else
              Container(
                height: AppDimensions.headerHeight,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space20),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: palette.brandPrimary,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: Center(
                        child: Text(
                          'M',
                          style: AppTypography.button.copyWith(
                            color: palette.brandOnPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Text(
                      'MYBIKE',
                      style: AppTypography.textTheme.titleMedium?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            // Navigation list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space12,
                  vertical: AppDimensions.space8,
                ),
                itemCount: items.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: AppDimensions.space4),
                itemBuilder: (BuildContext context, int index) {
                  final AppSidebarItem item = items[index];
                  final bool isSelected = currentPath == item.path;

                  return InkWell(
                    onTap: () => onNavigate(item.path),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space12),
                      decoration: BoxDecoration(
                        color: isSelected ? palette.brandSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            item.icon,
                            size: AppDimensions.iconSm,
                            color: isSelected ? palette.brandPrimary : palette.textSecondary,
                          ),
                          const SizedBox(width: AppDimensions.space12),
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: isSelected ? palette.textPrimary : palette.textSecondary,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (item.badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.space6,
                                vertical: AppDimensions.space2,
                              ),
                              decoration: BoxDecoration(
                                color: palette.brandPrimary,
                                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                              ),
                              child: Text(
                                item.badge!,
                                style: AppTypography.caption.copyWith(
                                  color: palette.brandOnPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Footer
            ?footer,
          ],
        ),
      ),
    );
  }
}
