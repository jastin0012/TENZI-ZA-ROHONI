import 'package:flutter/material.dart';

enum AppTab {
  home('Home', 'Nyumbani', Icons.home_outlined, Icons.home),
  favorites('Favorites', 'Vipendwa', Icons.favorite_border, Icons.favorite),
  recent('Recent', 'Hivi Karibuni', Icons.history_outlined, Icons.history),
  settings('Settings', 'Mipangilio', Icons.settings_outlined, Icons.settings);

  const AppTab(
    this.enLabel,
    this.swLabel,
    this.icon,
    this.activeIcon,
  );

  final String enLabel;
  final String swLabel;
  final IconData icon;
  final IconData activeIcon;

  static AppTab fromIndex(int index) {
    return values.firstWhere((tab) => tab.index == index,
        orElse: () => values.first);
  }
}

class NavigationItems {
  static List<NavigationRailDestination> getRailDestinations(
      BuildContext context) {
    return AppTab.values.map((tab) {
      return NavigationRailDestination(
        icon: Icon(tab.icon),
        selectedIcon: Icon(tab.activeIcon),
        label: Text(tab.enLabel),
      );
    }).toList();
  }

  static List<BottomNavigationBarItem> getBottomNavItems(BuildContext context) {
    return AppTab.values.map((tab) {
      return BottomNavigationBarItem(
        icon: Icon(tab.icon),
        activeIcon: Icon(tab.activeIcon),
        label: tab.swLabel,
      );
    }).toList();
  }
}
