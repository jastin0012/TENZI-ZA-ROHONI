import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/navigation.dart';
import 'core/app_prefs.dart';
import 'models/hymn.dart';
import 'utils/logger.dart';
import 'screens/favorites/favorites_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/hymn_detail_page.dart';
import 'screens/recent_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/settings/settings_screen.dart';
// ...existing imports... (no ad calls here)
import 'package:get_it/get_it.dart';
import 'services/favorites_manager.dart';
import 'utils/navigation_lock.dart';

class RouterOutlet extends StatefulWidget {
  final int initialIndex;
  final ValueChanged<int> onTabTapped;
  final VoidCallback onSearchPressed;

  const RouterOutlet({
    super.key,
    required this.initialIndex,
    required this.onTabTapped,
    required this.onSearchPressed,
  });

  @override
  State<RouterOutlet> createState() => RouterOutletState();
}

class RouterOutletState extends State<RouterOutlet> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _checkFirstLaunch();
  }

  @override
  void didUpdateWidget(RouterOutlet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      setState(() {
        _currentIndex = widget.initialIndex;
      });
    }
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('first_launch') ?? true;
    if (isFirstLaunch) {
      await prefs.setBool(AppPrefs.notificationsEnabled, false);
      await prefs.setBool(AppPrefs.firstLaunch, false);
    }
  }

  // Public method so parent (MainLayout) can drive tab changes
  void onItemTapped(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    // Do not show interstitials on tab switches — ads are shown only when
    // the user explicitly leaves a detail page by pressing back.
  }

  // Public method to open the global search from FAB/rail/bottom bar
  Future<void> onSearchPressed() async {
    // Delegate to the parent-provided handler which performs the
    // navigation (and already uses NavigationLock). Avoid pushing here
    // as that caused a duplicate push when the parent also pushed.
    try {
      widget.onSearchPressed();
    } catch (e) {
      // As a fallback, ensure we still open the Search screen but
      // guarded by the navigation lock so rapid taps don't stack.
      await NavigationLock.instance.run(() async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const SearchScreen()),
        );
      });
    }
  }

  /// Public helper to open a hymn detail page from outside (e.g. notifications)
  Future<void> openHymnDetail(Hymn hymn) async {
    try {
      await NavigationLock.instance.run(() async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => HymnDetailPage(
              hymn: hymn,
              isFavorite: GetIt.I<FavoritesManager>().isFavorite(hymn.id),
              onFavoriteToggled: (isFav) async {
                try {
                  if (isFav) {
                    await GetIt.I<FavoritesManager>().addToFavorites(hymn.id);
                  } else {
                    await GetIt.I<FavoritesManager>()
                        .removeFromFavorites(hymn.id);
                  }
                } catch (e, st) {
                  getLogger('RouterOutlet')
                      .e('Failed to update favorite from openHymDetail',
                          error: e, stackTrace: st);
                }
              },
            ),
          ),
        );
      }, key: hymn.id);

      // Do not show interstitials after programmatic opens; users should
      // not be interrupted by ads when the app opens pages programmatically.
    } catch (e, stack) {
      getLogger('RouterOutlet')
          .e('Failed to open hymn detail', error: e, stackTrace: stack);
    }
  }

  /// Public helper to open the notifications screen with provided data
  Future<void> openNotifications(List<Hymn> hymns, List<String> unopened,
      Future<bool> Function() clearNotifications) async {
    try {
      await NavigationLock.instance.run(() async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => NotificationsScreen(
              hymns: hymns,
              unopenedNotifications: unopened,
              clearNotifications: clearNotifications,
            ),
          ),
        );
      });
    } catch (e, stack) {
      getLogger('RouterOutlet')
          .e('Failed to open notifications screen', error: e, stackTrace: stack);
    }
  }

  Widget _buildScreenForIndex(int index) {
    final tab = AppTab.fromIndex(index);
    switch (tab) {
      case AppTab.home:
        return const HomeScreen();
      case AppTab.favorites:
        return const FavoritesScreen();
      case AppTab.recent:
        return const RecentScreen();
      case AppTab.settings:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Render the currently selected screen directly. Use the root Navigator
    // (Navigator.of(context)) for pushes so the pushed routes are part of the
    // main app navigation stack and inherit ambient widgets correctly.
    // Do not schedule ads here — interstitials are shown only when the
    // user explicitly leaves a detail via the back action.

    return _buildScreenForIndex(_currentIndex);
  }
}
