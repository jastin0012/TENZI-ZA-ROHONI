import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tenzi_za_rohoni/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenzi_za_rohoni/app.dart';
import 'package:tenzi_za_rohoni/core/service_locator.dart' as service_locator;
import 'package:tenzi_za_rohoni/core/app_prefs.dart';
import 'package:tenzi_za_rohoni/services/notification_service.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    configureLogger();

    FlutterError.onError = (FlutterErrorDetails details) {
      // Forward all Flutter framework errors to the zone handler as uncaught
      final exception = details.exception;
      final stack = details.stack ?? StackTrace.current;
      Zone.current.handleUncaughtError(exception, stack);
      getLogger('Main')
          .e('Flutter framework error', error: exception, stackTrace: stack);
    };

    getLogger('Main').i('Main: initializing services...');

    // Set up application services and singletons
    await service_locator.ServiceLocator.setup();

    // Read initial preferences for theme
    final SharedPreferences prefs =
        service_locator.locator<SharedPreferences>();
    final bool? initialIsDark = prefs.getBool('darkMode');

    getLogger('Main').i('Main: running app...');
    runApp(TenziZaRohoniApp(
      prefs: prefs,
      initialIsDark: initialIsDark,
    ));

    // Post-start initialization for notifications based on saved preference
    // Default to disabled on first run to avoid plugin timing issues.
    try {
      final bool notificationsEnabled =
          prefs.getBool(AppPrefs.notificationsEnabled) ?? false;
      if (notificationsEnabled) {
        final notificationService =
            service_locator.locator<NotificationService>();
        await notificationService.init();
        await notificationService.scheduleDailyNotifications();
        await notificationService.syncUnopenedWithToday();
      }
    } catch (e, st) {
      getLogger('Main')
          .w('Main: notification init failed', error: e, stackTrace: st);
    }
  }, (error, stack) {
    getLogger('Main')
        .e('Uncaught zone error at startup', error: error, stackTrace: stack);
  });
}
