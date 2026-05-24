// Core imports
import 'package:flutter/material.dart';
import '../constants/navigation.dart';

class AppNavigationRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSearchPressed;

  const AppNavigationRail({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onSearchPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      labelType: NavigationRailLabelType.all,
      destinations: NavigationItems.getRailDestinations(context),
    );
  }
}
