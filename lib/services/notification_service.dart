// Dart core
import 'dart:async';
import 'dart:typed_data';

// Flutter packages
import 'package:flutter/material.dart';
import 'package:tenzi_za_rohoni/utils/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Third-party packages
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:get_it/get_it.dart';
import 'package:tenzi_za_rohoni/gen/l10n/app_localizations.dart';

// App services
import 'package:tenzi_za_rohoni/services/hymn_service.dart';
import 'package:flutter/services.dart' show MissingPluginException;

class _NotificationStrings {
  final String appName;
  final String channelName;
  final String channelDescription;
  final String titleDaily;
  final String bodyDaily;
  final String titleTest;
  final String bodyTest;
  final String actionOpen;
  final String actionMarkRead;

  const _NotificationStrings({
    required this.appName,
    required this.channelName,
    required this.channelDescription,
    required this.titleDaily,
    required this.bodyDaily,
    required this.titleTest,
    required this.bodyTest,
    required this.actionOpen,
    required this.actionMarkRead,
  });
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Broadcast controller used for emitting updates
  final StreamController<List<String>> _unopenedController =
      StreamController<List<String>>.broadcast();

  // Expose a stream that first yields the current persisted list (if any)
  // then forwards subsequent broadcast events. This ensures subscribers
  // that attach before `init()` still receive the current state.
  Stream<List<String>> get unopenedStream async* {
    try {
      final prefs = await _prefs();
      final list = prefs.getStringList('unopened_notifications') ?? <String>[];
      yield List.unmodifiable(list);
    } catch (_) {
      yield const <String>[];
    }
    yield* _unopenedController.stream;
  }

  // Broadcast stream controller for numeric unread count
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();

  /// Dispose resources used by the service. Safe to call multiple times.
  void dispose() {
    try {
      if (!_unopenedController.isClosed) _unopenedController.close();
    } catch (_) {}
    try {
      if (!_unreadCountController.isClosed) _unreadCountController.close();
    } catch (_) {}
  }

  Stream<int> get unreadCountStream async* {
    try {
      final prefs = await _prefs();
      final list = prefs.getStringList('unopened_notifications') ?? <String>[];
      yield list.length;
    } catch (_) {
      yield 0;
    }
    yield* _unreadCountController.stream;
  }

  Future<SharedPreferences> _prefs() async {
    try {
      if (GetIt.I.isRegistered<SharedPreferences>()) {
        return GetIt.I<SharedPreferences>();
      }
    } catch (_) {}
    return SharedPreferences.getInstance();
  }

  /// Callback invoked when a notification is tapped while the app is running
  /// (foreground/background). The app sets this to navigate accordingly.
  VoidCallback? onNotificationTap;

  // Use a new channel ID to ensure updated importance/category take effect on devices
  static const String _channelId = 'daily_tenzi_message_channel';
  static const String _actionOpenId = 'ACTION_OPEN';
  static const String _actionMarkReadId = 'ACTION_MARK_READ';

  Future<_NotificationStrings> _strings() async {
    // Default fallback strings (English) in case localization cannot be loaded.
    const fallback = _NotificationStrings(
      appName: 'Christian Hymns',
      channelName: 'Daily Hymn',
      channelDescription: 'Daily evening hymn notification (heads-up)',
      titleDaily: "Today's hymn",
      bodyDaily: "Tap to open today's hymn",
      titleTest: 'Test notification',
      bodyTest: 'This is a test heads-up notification.',
      actionOpen: 'Open',
      actionMarkRead: 'Mark as read',
    );

    try {
      // Use device locale. This does not require a BuildContext.
      final locale = WidgetsBinding.instance.platformDispatcher.locale;
      final l10n = await AppLocalizations.delegate.load(locale);
      return _NotificationStrings(
        appName: l10n.appTitle,
        channelName: l10n.notificationChannelName,
        channelDescription: l10n.notificationChannelDescription,
        titleDaily: l10n.notificationTitleDaily,
        bodyDaily: l10n.notificationBodyDaily,
        titleTest: l10n.notificationTitleTest,
        bodyTest: l10n.notificationBodyTest,
        actionOpen: l10n.notificationActionOpen,
        actionMarkRead: l10n.notificationActionMarkRead,
      );
    } catch (_) {
      return fallback;
    }
  }

  /// Cancels all pending notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> init() async {
    if (_initialized) return;
    // Initialize timezone data and set local location (Tanzania local time)
    tz_data.initializeTimeZones();
    // Use the device's local timezone rather than forcing a specific
    // region. Forcing 'Africa/Dar_es_Salaam' causes notifications to
    // fire at that timezone's 18:00 rather than the device local 18:00.
    // tz.initializeTimeZones() is sufficient for `tz.local` to work.

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    var successfulInit = false;
    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse response) async {
          final prefs = await _prefs();
          final payload = response.payload ?? '';
          // Extract hymn number if present
          String? hymnNumInPayload;
          if (payload.startsWith('open_hymn:')) {
            hymnNumInPayload = payload.substring('open_hymn:'.length);
          }

          // Handle action-specific logic first
          if (response.actionId == _actionMarkReadId &&
              hymnNumInPayload != null) {
            // Remove from badge and from list entirely
            await _markAsReadInternal(prefs, hymnNumInPayload);
            await updateBadgeCount();
            return; // Do not navigate
          }

          if (payload.startsWith('open_hymn:')) {
            final hymnNum = hymnNumInPayload!;
            // Decrement badge immediately but keep it in the list (Gmail-like)
            await NotificationService().markAsOpened(hymnNum);
            await updateBadgeCount();
            await prefs.setString('last_tapped_hymn', hymnNum);
            // Ensure it appears in the in-app list: add timestamp if missing
            try {
              final map = _getUnopenedTimes(prefs);
              if (!map.containsKey(hymnNum)) {
                map[hymnNum] = DateTime.now().millisecondsSinceEpoch;
                await _saveUnopenedTimes(prefs, map);
              }
            } catch (_) {}
          } else {
            // Fallback: open notifications list
            await prefs.remove('last_tapped_hymn');
          }
          await prefs.setBool('open_notifications_on_launch', true);
          // If the app is already running, navigate immediately
          onNotificationTap?.call();
        },
      );
      successfulInit = true;
    } catch (e) {
      // Plugin platform implementation may not be available yet on some
      // platforms (or in tests). Log and continue; further plugin calls
      // will be guarded.
      getLogger('NotificationService')
          .w('Notification plugin initialize failed: $e');
    }

    if (!successfulInit) {
      // Do not mark initialized when platform initialization failed.
      return;
    }

    // Ensure Android notification channel is created with high importance
    // so notifications appear as heads-up (similar to SMS). This is a
    // local, on-device/channel configuration and works offline.
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final s = await _strings();
        final channel = AndroidNotificationChannel(
          _channelId, // id
          s.channelName, // name
          description: s.channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );
        await androidImpl.createNotificationChannel(channel);
      }
    } catch (e) {
      getLogger('NotificationService')
          .w('Failed to create Android notification channel: $e');
    }

    _initialized = true;

    // Request permissions where applicable (no-ops if unsupported)
    if (!kIsWeb) {
      // Keep lightweight, explicit requests will also be performed when enabling from Settings
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    try {
      final appLaunchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (appLaunchDetails?.didNotificationLaunchApp ?? false) {
        final prefs = await _prefs();
        await prefs.setBool('open_notifications_on_launch', true);
      }
    } on MissingPluginException catch (e) {
      getLogger('NotificationService').w('Notification plugin missing: $e');
    } catch (e, st) {
      // Some platforms or SDK versions may throw non-Exception errors here
      // (for example, a late initialization error). Catch generically and
      // log the issue without crashing the app.
      getLogger('NotificationService').e(
        'Unexpected error querying launch details',
        error: e,
        stackTrace: st,
      );
    }

    // Sync launcher badge with current unopened count on startup
    await updateBadgeCount();

    // Emit initial unopened notifications to listeners
    try {
      await _emitUnopened();
    } catch (_) {}
  }

  /// Returns true when platform plugin initialization completed successfully.
  bool get isInitialized => _initialized;

  /// Ensure the service is initialized. Safe to call multiple times.
  Future<void> ensureInitialized() async {
    if (!_initialized) await init();
  }

  /// Send a high-priority test notification a few seconds from now.
  /// Useful to verify heads-up banners/device settings.
  Future<void> showTestNotificationNow({int secondsFromNow = 5}) async {
    if (kIsWeb) return;
    final s = await _strings();
    // Determine a hymn number for payload so tapping can go to details
    String? hymnNum;
    try {
      final hymns = await HymnService().getAllHymns();
      if (hymns.isNotEmpty) {
        final now = tz.TZDateTime.now(tz.local);
        final count = hymns.length;
        final base = now.year * 10000 + now.month * 100 + now.day;
        final idx = (base * 3 + 7) % count;
        hymnNum = hymns[idx].songNumber.toString();
      }
    } catch (_) {}

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      s.channelName,
      channelDescription: s.channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      channelShowBadge: true,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      channelAction: AndroidNotificationChannelAction.update,
      vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
      ticker: s.titleTest,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          _actionOpenId,
          s.actionOpen,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          _actionMarkReadId,
          s.actionMarkRead,
          showsUserInterface: false,
        ),
      ],
      styleInformation: MessagingStyleInformation(
        Person(name: s.appName),
        conversationTitle: s.titleDaily,
        messages: [
          Message(
            s.bodyTest,
            DateTime.now(),
            Person(name: s.appName),
          ),
        ],
      ),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final now = tz.TZDateTime.now(tz.local);
    final when = now.add(Duration(seconds: secondsFromNow));

    // Pre-populate lists so it shows in the in-app list immediately
    try {
      if (hymnNum != null) {
        final prefs = await _prefs();
        final unopened =
            prefs.getStringList('unopened_notifications') ?? <String>[];
        if (!unopened.contains(hymnNum)) {
          unopened.add(hymnNum);
          await prefs.setStringList('unopened_notifications', unopened);
        }
        final times = _getUnopenedTimes(prefs);
        times.putIfAbsent(hymnNum, () => DateTime.now().millisecondsSinceEpoch);
        await _saveUnopenedTimes(prefs, times);
        await updateBadgeCount();
      }
    } catch (_) {}

    await _plugin.zonedSchedule(
      999,
      s.titleTest,
      s.bodyTest,
      when,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: hymnNum != null ? 'open_hymn:$hymnNum' : 'open_notifications',
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    // Notify listeners about the updated unopened list
    try {
      await _emitUnopened();
    } catch (_) {}
  }

  Future<void> scheduleDailyNotifications() async {
    if (kIsWeb) return; // Not supported on Web
    final s = await _strings();
    // Cancel existing to avoid duplicates
    await cancelDailyNotifications();

    // Configure Android for heads-up banner similar to Google Messages
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      s.channelName,
      channelDescription: s.channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      channelShowBadge: true,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      channelAction: AndroidNotificationChannelAction.update,
      vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
      ticker: s.channelName,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          _actionOpenId,
          s.actionOpen,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          _actionMarkReadId,
          s.actionMarkRead,
          showsUserInterface: false,
        ),
      ],
      styleInformation: MessagingStyleInformation(
        Person(name: s.appName),
        conversationTitle: s.titleDaily,
        messages: [
          Message(
            s.bodyDaily,
            DateTime.now(),
            Person(name: s.appName),
          ),
        ],
      ),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Prepare payload with today's chosen hymn number so taps open detail
    String? hymnNum;
    try {
      final hymns = await HymnService().getAllHymns();
      if (hymns.isNotEmpty) {
        final now = tz.TZDateTime.now(tz.local);
        final count = hymns.length;
        final base = now.year * 10000 + now.month * 100 + now.day;
        final eveningIndex = (base * 3 + 7) % count;
        hymnNum = hymns[eveningIndex].songNumber.toString();
      }
    } catch (_) {}

    // Single evening notification at 18:00
    await _plugin.zonedSchedule(
      101,
      s.titleDaily,
      s.bodyDaily,
      _nextInstanceOf(const TimeOfDay(hour: 18, minute: 0)),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: hymnNum != null ? 'open_hymn:$hymnNum' : 'open_notifications',
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelDailyNotifications() async {
    await _plugin.cancel(100);
    await _plugin.cancel(101);
    await _plugin.cancel(201); // periodic ID
  }

  /// Ensure that for today's 18:00 time, if already past and
  /// the corresponding hymn isn't in the unopened list, we add it with a timestamp.
  /// This works fully offline and on app start/resume.
  Future<void> syncUnopenedWithToday() async {
    try {
      final prefs = await _prefs();
      final hymns = await HymnService().getAllHymns();
      if (hymns.isEmpty) return;

      // Build deterministic selection based on date, but stable for the day
      final now = tz.TZDateTime.now(tz.local);
      final dateKey = _dateKey(now);

      // choose a deterministic index for the day (single evening hymn)
      final count = hymns.length;
      final base =
          now.year * 10000 + now.month * 100 + now.day; // increases daily
      final eveningIndex = (base * 3 + 7) % count;
      final eveningNum = hymns[eveningIndex].songNumber.toString();

      final unopened =
          prefs.getStringList('unopened_notifications') ?? <String>[];
      final times = _getUnopenedTimes(prefs);

      // Evening 18:00
      final eveningTime =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, 18, 0);
      if (now.isAfter(eveningTime) || now.isAtSameMomentAs(eveningTime)) {
        final eveningFlag = 'evening_added_$dateKey';
        final alreadyAdded = prefs.getBool(eveningFlag) ?? false;
        if (!alreadyAdded) {
          if (!unopened.contains(eveningNum)) unopened.add(eveningNum);
          // Record the actual scheduled timestamp (18:00 local) so the UI shows
          // the true arrival time even if the app wasn't open then.
          times[eveningNum] = eveningTime.millisecondsSinceEpoch;
          await prefs.setStringList('unopened_notifications', unopened);
          await _saveUnopenedTimes(prefs, times);
          await prefs.setBool(eveningFlag, true);
          await updateBadgeCount();
          try {
            await _emitUnopened();
          } catch (_) {}
        }
      }
    } catch (_) {
      // ignore errors silently
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  Map<String, int> _getUnopenedTimes(SharedPreferences prefs) {
    final raw = prefs.getString('unopened_times');
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      // Store as key=value pairs joined by ';' to avoid JSON dependency here
      final result = <String, int>{};
      for (final entry in raw.split(';')) {
        if (entry.isEmpty) continue;
        final parts = entry.split('=');
        if (parts.length == 2) {
          final v = int.tryParse(parts[1]);
          if (v != null) result[parts[0]] = v;
        }
      }
      return result;
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> _saveUnopenedTimes(
      SharedPreferences prefs, Map<String, int> map) async {
    final entries = map.entries.map((e) => '${e.key}=${e.value}').join(';');
    await prefs.setString('unopened_times', entries);
  }

  tz.TZDateTime _nextInstanceOf(TimeOfDay timeOfDay) {
    final now = tz.TZDateTime.now(tz.local);
    // Schedule at hh:mm:00 local
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
      0,
    );
    // If not strictly in the future, move to next day to avoid immediate/late fire
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Explicitly check/request notification permissions.
  /// Returns true if notifications are allowed after the call.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    bool granted = true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final bool? enabled = await android.areNotificationsEnabled();
      if (enabled == false) {
        final bool? res = await android.requestNotificationsPermission();
        if (res == false) granted = false;
      }
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final bool? res = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (res == false) granted = false;
    }

    final mac = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    if (mac != null) {
      final bool? res = await mac.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (res == false) granted = false;
    }

    return granted;
  }

  /// Android helper to query if notifications are enabled; returns null on non-Android.
  Future<bool?> areNotificationsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled();
  }

  /// Mark a hymn notification as opened: removes it from the unopened list and
  /// keeps its timestamp entry so it remains in the in-app list until marked read.
  ///
  /// Returns true if the hymn was marked as opened, false otherwise.
  Future<bool> markAsOpened(String hymnNumber) async {
    try {
      if (hymnNumber.isEmpty) {
        getLogger('NotificationService')
            .w('Invalid hymn number provided to markAsOpened');
        return false;
      }

      final prefs = await _prefs();
      await _markAsReadInternal(prefs, hymnNumber);
      await updateBadgeCount();
      try {
        await _emitUnopened();
      } catch (_) {}

      getLogger('NotificationService')
          .i('Successfully marked hymn $hymnNumber as opened');
      return true;
    } catch (e) {
      getLogger('NotificationService')
          .e('Error marking notification as opened', error: e);
      return false;
    }
  }

  /// Clears all notifications from the notification tray and resets all notification-related data
  ///
  /// Returns true if all operations completed successfully, false otherwise
  Future<bool> clearAllNotifications() async {
    try {
      getLogger('NotificationService').i('Clearing all notifications...');

      // Cancel all scheduled notifications
      await _plugin.cancelAll();
      getLogger('NotificationService')
          .i('Cancelled all scheduled notifications');

      // Clear all notification data from shared preferences
      final prefs = await _prefs();

      // Clear unopened notifications
      await prefs.remove('unopened_notifications');
      getLogger('NotificationService').i('Cleared unopened notifications');

      // Clear read notifications
      await prefs.remove('read_notifications');
      getLogger('NotificationService').i('Cleared read notifications');

      // Clear notification times
      await prefs.remove('unopened_times');
      getLogger('NotificationService').i('Cleared notification times');

      // Update the badge count
      await updateBadgeCount();
      getLogger('NotificationService').i('Updated badge count');

      return true;
    } catch (e) {
      getLogger('NotificationService')
          .e('Error clearing all notifications', error: e);
      return false;
    }
  }

  /// Returns the list of unopened notification hymn numbers
  Future<List<String>> getUnopenedNotifications() async {
    final prefs = await _prefs();
    return prefs.getStringList('unopened_notifications') ?? <String>[];
  }

  /// Consume and return the last tapped hymn (set by notification handler),
  /// removing it from preferences so it isn't re-consumed.
  Future<String?> consumeLaunchHymn() async {
    final prefs = await _prefs();
    final value = prefs.getString('last_tapped_hymn');
    if (value == null || value.isEmpty) return null;
    await prefs.remove('last_tapped_hymn');
    return value;
  }

  // Internal helper used by notification action to mark as read (remove from list)
  Future<void> _markAsReadInternal(
      SharedPreferences prefs, String hymnNumber) async {
    try {
      // Remove from unopened notifications list
      final unopened =
          prefs.getStringList('unopened_notifications') ?? <String>[];
      if (unopened.contains(hymnNumber)) {
        unopened.remove(hymnNumber);
        await prefs.setStringList('unopened_notifications', unopened);
      }

      // Add to read notifications list if not already there
      final read = prefs.getStringList('read_notifications') ?? <String>[];
      if (!read.contains(hymnNumber)) {
        read.add(hymnNumber);
        await prefs.setStringList('read_notifications', read);
      }

      // Update the badge count
      await updateBadgeCount();

      getLogger('NotificationService')
          .i('Marked notification for hymn $hymnNumber as read');
    } catch (e) {
      getLogger('NotificationService')
          .e('Error in _markAsReadInternal', error: e);
      rethrow;
    }
  }

  /// Update launcher icon badge to reflect unopened notifications count.
  /// On Android 8+ most launchers derive the badge automatically from active
  /// notifications when `channelShowBadge: true`. For iOS, we need to set it explicitly.
  Future<void> updateBadgeCount() async {
    try {
      if (kIsWeb) return; // Not supported on web

      // Get the current unopened notifications count
      final prefs = await _prefs();
      final unopened =
          prefs.getStringList('unopened_notifications') ?? <String>[];
      final count = unopened.length;

      // Update badge count
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      try {
        await android?.requestNotificationsPermission();
      } catch (_) {}
      try {
        await ios?.requestPermissions(alert: true, badge: true, sound: true);
      } catch (_) {}

      // On iOS, attempt to set the badge if the API exists
      // Attempting to set a badge on iOS/macOS may not be supported by the
      // installed plugin version. Rely on the OS/platform or other helper
      // packages to update the icon badge if necessary. No-op here.

      getLogger('NotificationService').i('Updated badge count to $count');
      try {
        await _emitUnopened();
        // Also emit numeric count for badge listeners
        try {
          _unreadCountController.add(count);
        } catch (_) {}
      } catch (_) {}
    } catch (e) {
      getLogger('NotificationService')
          .e('Error updating badge count', error: e);
    }
  }

  Future<void> _emitUnopened() async {
    try {
      final prefs = await _prefs();
      final list = prefs.getStringList('unopened_notifications') ?? <String>[];
      _unopenedController.add(List.unmodifiable(list));
      try {
        _unreadCountController.add(list.length);
      } catch (_) {}
    } catch (_) {
      // ignore
    }
  }
}
