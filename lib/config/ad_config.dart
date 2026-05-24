import 'package:flutter/foundation.dart';

class AdConfig {
  // AdMob App ID
  static const String productionAppId = 'ca-app-pub-3553897102603320~2497577269';
  static const String testAppId = 'ca-app-pub-3940256099942544~3347511713';

  // Test ad unit IDs (official Google test IDs)
  static const testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  // Production ad unit IDs
  static const productionBannerAdUnitId =
      'ca-app-pub-3553897102603320/8049286849';
  static const productionInterstitialAdUnitId =
      'ca-app-pub-3553897102603320/7007667917';

  // Get the appropriate ad unit ID based on build mode
  static String get bannerAdUnitId =>
      kReleaseMode ? productionBannerAdUnitId : testBannerAdUnitId;

  static String get interstitialAdUnitId =>
      kReleaseMode ? productionInterstitialAdUnitId : testInterstitialAdUnitId;

  static String get appId =>
      kReleaseMode ? productionAppId : testAppId;
}
