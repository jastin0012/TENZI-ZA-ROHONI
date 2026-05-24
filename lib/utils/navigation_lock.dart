import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tenzi_za_rohoni/utils/logger.dart';

/// A simple global async navigation lock to prevent multiple near-simultaneous
/// Navigator.push calls that cause duplicate pages to stack.
class NavigationLock {
  NavigationLock._();

  static final NavigationLock instance = NavigationLock._();

  // When not-null this map contains keys currently being navigated to.
  // We use this to allow different navigations in parallel while
  // suppressing duplicates for the same resource (for example the same
  // hymn id).
  final Set<String> _activeKeys = <String>{};

  /// When true, the lock will emit debug logs via [debugPrint] when it
  /// suppresses or acquires navigation keys. Useful for diagnosing
  /// residual stacking during rapid-tap tests. Default: false.
  static bool enableLogging = true; // Enable logging for debugging purposes

  /// When true, keyed runs will still be globally exclusive: if any
  /// navigation is in progress, new runs (even with different keys) will
  /// be suppressed. This is useful as a conservative guard to avoid the
  /// app stacking multiple different detail pages under rapid taps.
  /// Default: true while diagnosing stacking; can be toggled off later.
  static bool enforceGlobalExclusionForKeys = false;

  /// Live counters exposed for debug overlays/tests.
  static final ValueNotifier<int> suppressedCount = ValueNotifier<int>(0);
  static final ValueNotifier<int> activeCount = ValueNotifier<int>(0);

  /// Run [action] guarded by the navigation lock. If a navigation is already
  /// in progress this returns null immediately. When [key] is provided,
  /// concurrent runs with the same key are suppressed while allowing other
  /// navigations to proceed.
  ///
  /// The [action] is allowed to return a nullable future (for example
  /// `Navigator.push<T>` returns `Future<T?>`). The method returns the
  /// action result or `null` if the navigation was suppressed.
  Future<T?> run<T>(Future<T?> Function() action, {String? key}) async {
    if (key != null) {
      // Enforce global exclusion if configured: if other keys are active
      // then suppress this run even if different.
      if (enforceGlobalExclusionForKeys && _activeKeys.isNotEmpty) {
        if (enableLogging) {
          getLogger('NavigationLock').d(
              'NavigationLock: suppressed run for key=$key due to activeKeys=$_activeKeys');
          // Print a stack trace to help locate the caller that attempted
          // to run navigation while another was active. Debug-only.
          if (kDebugMode) {
            getLogger('NavigationLock')
                .d('NavigationLock suppression stack for key=$key');
          }
        }
        suppressedCount.value = suppressedCount.value + 1;
        return null;
      }
      if (_activeKeys.contains(key)) {
        if (enableLogging) {
          getLogger('NavigationLock')
              .d('NavigationLock: suppressed run for key=$key');
          if (kDebugMode) {
            getLogger('NavigationLock')
                .d('NavigationLock suppression stack for key=$key');
          }
        }
        return null;
      }
      if (enableLogging) {
        getLogger('NavigationLock').d('NavigationLock: acquiring key=$key');
      }
      _activeKeys.add(key);
      activeCount.value = _activeKeys.length;
      try {
        return await action();
      } finally {
        _activeKeys.remove(key);
        activeCount.value = _activeKeys.length;
        if (enableLogging) {
          getLogger('NavigationLock').d('NavigationLock: released key=$key');
        }
      }
    }

    // No key: act as a global lock (backwards compatible)
    if (_activeKeys.isNotEmpty) {
      if (enableLogging) {
        getLogger('NavigationLock').d(
            'NavigationLock: suppressed global run (activeKeys=$_activeKeys)');
        if (kDebugMode) {
          getLogger('NavigationLock')
              .d('NavigationLock suppression stack for global run');
        }
      }
      suppressedCount.value = suppressedCount.value + 1;
      return null;
    }
    // Use a synthetic key so multiple non-keyed runs also dedupe.
    const globalKey = '__global_nav_lock__';
    if (enableLogging) {
      getLogger('NavigationLock').d('NavigationLock: acquiring global lock');
    }
    _activeKeys.add(globalKey);
    activeCount.value = _activeKeys.length;
    try {
      return await action();
    } finally {
      _activeKeys.remove(globalKey);
      activeCount.value = _activeKeys.length;
      if (enableLogging) {
        getLogger('NavigationLock').d('NavigationLock: released global lock');
      }
    }
  }

  /// For debug overlay: snapshot of active keys (not reactive)
  List<String> get activeKeysSnapshot => List<String>.from(_activeKeys);
}
