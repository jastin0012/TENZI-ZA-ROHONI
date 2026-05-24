import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'constants/navigation.dart';
import 'services/hymn_service.dart';
import 'services/notification_service.dart';
import 'widgets/app_bottom_navigation_bar.dart';
import 'widgets/banner_ad_widget.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'router_outlet.dart';
import 'package:tenzi_za_rohoni/gen/l10n/app_localizations.dart';
import 'screens/search/search_screen.dart';
import 'utils/navigation_lock.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;
  final ValueChanged<int>? onTabTapped;
  final VoidCallback? onSearchPressed;
  final bool skipInit;

  const MainLayout({
    super.key,
    this.initialIndex = 0,
    this.onTabTapped,
    this.onSearchPressed,
    this.skipInit = false,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  final GlobalKey<RouterOutletState> _routerKey =
      GlobalKey<RouterOutletState>();
  final Logger _logger = Logger();

  late int _selectedIndex;
  bool _isInitialized = false;
  bool _hasError = false;

  // Services
  late final HymnService _hymnService;
  late final NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
    if (!widget.skipInit) {
      _initializeServices();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForUpdates();
    }
  }

  Future<void> _initializeServices() async {
    try {
      _hymnService = HymnService();
      // Use the shared NotificationService instance; it should be initialized
      // in `main._postStartupInit`. Do not call init() here to avoid
      // platform initialization races.
      _notificationService = NotificationService();

      // Wire notification tap handling so taps navigate into the app
      _notificationService.onNotificationTap = () async {
        try {
          final hymnNumStr = await _notificationService.consumeLaunchHymn();
          if (hymnNumStr == null) return;
          final hymnNum = int.tryParse(hymnNumStr);
          if (hymnNum == null) return;
          final hymn = await _hymnService.getHymnByNumber(hymnNum);
          if (hymn == null) return;

          // Ensure we are on the home tab which contains the hymns list
          if (mounted) {
            setState(() => _selectedIndex = AppTab.home.index);
          }
          // Give RouterOutlet a moment to update
          await Future.delayed(const Duration(milliseconds: 100));
          _routerKey.currentState?.openHymnDetail(hymn);
        } catch (e, stack) {
          _logger.w('Error handling notification tap',
              error: e, stackTrace: stack);
        }
      };

      // Preload hymns
      await _hymnService.getAllHymns();

      if (mounted) {
        setState(() => _isInitialized = true);
      }

      // If app was launched from a notification, consume it now and navigate
      try {
        final hymnNumStr = await _notificationService.consumeLaunchHymn();
        if (hymnNumStr != null) {
          final hymnNum = int.tryParse(hymnNumStr);
          if (hymnNum != null) {
            final hymn = await _hymnService.getHymnByNumber(hymnNum);
            if (hymn != null) {
              // Switch to home and open detail
              if (mounted) setState(() => _selectedIndex = AppTab.home.index);
              await Future.delayed(const Duration(milliseconds: 150));
              _routerKey.currentState?.openHymnDetail(hymn);
            }
          }
        }
      } catch (_) {}
      // Check for updates in background
      _checkForUpdates();
    } catch (e, stack) {
      _logger.e('Error initializing services', error: e, stackTrace: stack);
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      await _hymnService.getAllHymns(forceRefresh: true);
    } catch (e) {
      _logger.w('Background update check failed: $e');
    }
  }

  void _handleTabTapped(int index) {
    if (_selectedIndex == index) return;

    if (mounted) {
      setState(() => _selectedIndex = index);
    }

    // Forward to RouterOutlet's nested navigator
    _routerKey.currentState?.onItemTapped(index);

    // Also notify external listeners if provided
    widget.onTabTapped?.call(index);

    // Log the tab change
    _logger.i('Tab changed to: ${AppTab.fromIndex(index).name}');
  }

  Future<void> _handleSearchPressed() async {
    if (!mounted) return;

    try {
      await NavigationLock.instance.run(() async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const SearchScreen(),
          ),
        );
      });
    } catch (e, stack) {
      _logger.e('Error during search', error: e, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tatizo limetokea wakati wa kutafuta'),
          ),
        );
      }
    }
  }

  Widget _buildLoadingView() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)?.loading ?? 'Loading...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)?.errorTitle ?? 'Error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeServices,
                child: Text(AppLocalizations.of(context)?.retry ?? 'Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return _buildLoadingView();
    }

    if (_hasError) {
      return _buildErrorView(
        'Haikuweza kupakua data. Tafadhali angalia muunganisho wako wa intaneti na ujaribu tena.',
      );
    }

    return Scaffold(
      body: RouterOutlet(
        key: _routerKey,
        initialIndex: _selectedIndex,
        onTabTapped: _handleTabTapped,
        onSearchPressed: _handleSearchPressed,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Global banner so every screen (including detail) shows a banner
          const BannerAdWidget(
            size: AdSize.banner,
            keepAlive: true,
          ),
          AppBottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _handleTabTapped,
          ),
        ],
      ),
    );
  }
}
