import 'dart:async';
import 'package:flutter/material.dart' show ThemeMode, ValueNotifier;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, kReleaseMode;
import 'package:tenzi_za_rohoni/utils/logger.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';
import '../services/hymn_service.dart';
import '../models/hymn.dart';
import '../services/favorites_manager.dart';
import '../services/notification_service.dart';
import '../utils/recent_manager.dart';

final GetIt locator = GetIt.instance;

class ServiceLocator {
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static Future<void> setup() async {
    if (_isInitialized) return;

    try {
      // 1. Register core services
      await _registerCoreServices();

      // 2. Register app services
      await _registerAppServices();

      // 3. Initialize services
      await _initializeServices();

      _isInitialized = true;
    } catch (e) {
      // Reset state if initialization fails
      _isInitialized = false;
      rethrow;
    }
  }

  static Future<void> _registerCoreServices() async {
    // SharedPreferences
    final sharedPreferences = await SharedPreferences.getInstance();
    locator.registerSingleton<SharedPreferences>(sharedPreferences);

    // Initialize Mobile Ads
    // Initialize Mobile Ads only on supported mobile platforms (Android/iOS).
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        await MobileAds.instance.initialize();
      } catch (e) {
        getLogger('ServiceLocator')
            .w('Warning: MobileAds initialization failed: $e');
      }

      // Configure request settings for development builds so developers can
      // safely receive test ads while validating production ad units. Replace
      // 'YOUR_DEVICE_ID' with the value printed in the log when testing, or
      // leave as an empty list to rely on server-side test handling.
      if (!kReleaseMode) {
        try {
          await MobileAds.instance.updateRequestConfiguration(
            RequestConfiguration(testDeviceIds: ['YOUR_DEVICE_ID']),
          );
          getLogger('ServiceLocator').i(
              'MobileAds request configuration updated for debug builds. Replace YOUR_DEVICE_ID with your device id from logs to mark it as a test device.');
        } catch (e) {
          getLogger('ServiceLocator')
              .w('Warning: failed to set MobileAds request configuration: $e');
        }
      }
    }
  }

  static Future<void> _registerAppServices() async {
    final prefs = locator<SharedPreferences>();

    // Hymn Service (singleton factory)
    final hymnService = HymnService();
    // HymnService initializes lazily when first used. Start a background
    // warm-up to populate cache without blocking startup.
    hymnService.getAllHymns().catchError((e) {
      getLogger('ServiceLocator').w('Background hymn warm-up failed: $e');
      return <Hymn>[];
    });
    locator.registerSingleton<HymnService>(hymnService);

    // Recent Manager
    final recentManager = RecentManager(
      prefs: prefs,
      hymnService: hymnService,
    );
    await recentManager.initialize();
    locator.registerSingleton<RecentManager>(recentManager);

    // Favorites Manager
    final favoritesManager = FavoritesManager(prefs);
    await favoritesManager.initialize();
    locator.registerSingleton<FavoritesManager>(favoritesManager);

    // Theme notifier - initial value based on saved preference.
    // Default to light mode on first run (savedDark == null).
    final bool? savedDark = prefs.getBool('darkMode');
    final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
        savedDark == null
            ? ThemeMode.light
            : (savedDark ? ThemeMode.dark : ThemeMode.light));
    locator.registerSingleton<ValueNotifier<ThemeMode>>(themeNotifier);

    // Notification Service
    // Do not initialize the plugin here - platform implementations may not be
    // registered yet. Initialize after app startup (see main._postStartupInit).
    final notificationService = NotificationService();
    locator.registerSingleton<NotificationService>(notificationService);

    // Ad Service (use singleton instance provided by the class)
    final adService = AdService.instance;
    locator.registerSingleton<AdService>(adService);
  }

  static Future<void> _initializeServices() async {
    // All services are now initialized during registration
    // This method is kept for any future initialization that might be needed
  }

  static Future<void> reset() async {
    try {
      // Dispose any services that need explicit cleanup before reset
      try {
        if (locator.isRegistered<NotificationService>()) {
          locator<NotificationService>().dispose();
        }
      } catch (_) {}

      await locator.reset();
      _isInitialized = false;
      await setup();
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }
}
