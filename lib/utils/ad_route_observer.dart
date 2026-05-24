// Flutter packages
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

/// Global route observer that triggers a single ad show on the first push.
class AdRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  AdRouteObserver._();
  static final AdRouteObserver instance = AdRouteObserver._();

  // No internal state required at the moment; keep class minimal.

  /// Helper for widgets to subscribe easily using the standard RouteObserver API
  @override
  void subscribe(RouteAware routeAware, PageRoute<dynamic> route) {
    super.subscribe(routeAware, route);
  }

  /// Helper to unsubscribe a RouteAware
  @override
  void unsubscribe(RouteAware routeAware) {
    // Delegate to base implementation to keep internal cleanup consistent.
    super.unsubscribe(routeAware);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (kIsWeb) return; // don't attempt to show interstitials on web

    // Intentionally do not show interstitials on route push. Ads should be
    // shown only on explicit user exits from detail pages to avoid
    // interrupting navigation.
  }
}
