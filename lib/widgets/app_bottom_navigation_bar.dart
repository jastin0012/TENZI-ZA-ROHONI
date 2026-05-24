import 'package:flutter/material.dart';

import '../constants/navigation.dart';
import '../theme/colors.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onSearchPressed;

  // Preferred overall height for the bar (useful for attaching banners)
  // Comfortable touch targets similar to popular messaging apps
  static const double preferredHeight = 60.0;

  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onSearchPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Compute bottom inset so the bar sits flush above system navigation
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // We intentionally avoid SafeArea here to remove unexpected extra gaps
    // and instead account for the bottom inset directly in the height so
    // banners can be placed directly above this widget without extra space.
    return Container(
      width: double.infinity,
      height: preferredHeight + bottomInset,
      // slightly more horizontal padding so icons don't hug the edges
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : theme.colorScheme.surface,
        // top edge should be a straight line; keep subtle rounding on
        // the bottom corners for a pleasant look.
        borderRadius: const BorderRadius.only(
          topLeft: Radius.zero,
          topRight: Radius.zero,
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(isDark ? 0.28 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: AppTab.values.map((tab) {
          final index = tab.index;
          final selected = index == currentIndex;
          final iconData = selected ? tab.activeIcon : tab.icon;
          final Color unselectedIconColor =
              colorScheme.onSurface.withOpacity(0.7);
          const Color brandYellow = AppColors.primary;

          return Expanded(
            child: InkWell(
              onTap: () => onTap(index),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    // larger circular container for better touch target
                    width: selected ? 48 : 44,
                    height: selected ? 48 : 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // Always show a white circular background (as requested)
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                    ),
                    child: Icon(
                      iconData,
                      // Icon color changes to brand yellow when selected
                      color: selected ? brandYellow : unselectedIconColor,
                      size: selected ? 26 : 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: selected ? 24 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color:
                          selected ? colorScheme.onSurface : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
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
