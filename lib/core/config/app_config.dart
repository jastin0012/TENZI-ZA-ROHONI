import 'package:flutter/foundation.dart';
import 'package:tenzi_za_rohoni/utils/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  static const String appName = 'RohoniFlow';
  static const String appDescription = 'A Swahili hymns companion app';

  // App version information
  String version = '1.0.0';
  String buildNumber = '1';
  String packageName = 'com.rav850418082.tenzi_za_rohoni';

  // Feature flags
  bool get isDebugMode => kDebugMode;
  bool get isReleaseMode => kReleaseMode;
  bool get isWeb => kIsWeb;

  // API and remote configuration
  final String apiBaseUrl = 'https://api.example.com/v1';

  // Ad configuration
  final bool enableAds = true;

  // Initialize app configuration
  Future<void> init() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      version = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
      packageName = packageInfo.packageName;
    } catch (e, st) {
      getLogger('AppConfig')
          .w('Failed to load package info', error: e, stackTrace: st);
    }
  }
}
