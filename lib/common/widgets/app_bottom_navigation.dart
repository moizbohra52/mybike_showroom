import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';
import 'package:mybike_showroom/core/theme/app_typography.dart';

/// Navigation item for [AppBottomNavigation].
class AppBottomNavItem {
  const AppBottomNavItem({
    required this.label,
    required this.icon,
    required this.path,
    this.badgeCount,
  });

  final String label;
  final IconData icon;
  final String path;
  final int? badgeCount;
}

/// Responsive bottom navigation bar for mobile views.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.currentPath,
    required this.items,
    required this.onTap,
    super.key,
  });

  final String currentPath;
  final List<AppBottomNavItem> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return Container(
      height: AppDimensions.bottomNavHeight,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          top: BorderSide(color: palette.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((AppBottomNavItem item) {
          final bool isSelected = currentPath == item.path;
          final Color itemColor = isSelected ? palette.brandPrimary : palette.textSecondary;

          return Expanded(
            child: InkWell(
              onTap: () => onTap(item.path),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Icon(item.icon, size: AppDimensions.iconMd, color: itemColor),
                      if (item.badgeCount != null && item.badgeCount! > 0)
                        Positioned(
                          top: -4,
                          right: -8,
                          child: Container(
                            padding: const EdgeInsets.all(AppDimensions.space2),
                            decoration: BoxDecoration(
                              color: palette.danger,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                            child: Center(
                              child: Text(
                                '${item.badgeCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: itemColor,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
