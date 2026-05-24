import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tenzi_za_rohoni/config/ad_config.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tenzi_za_rohoni/utils/logger.dart';

/// Platform detection for ad support
bool get _isAndroid {
  if (kIsWeb) return false;
  try {
    return defaultTargetPlatform == TargetPlatform.android;
  } catch (_) {
    return false;
  }
}

class AdService {
  static final AdService _instance = AdService._internal();
  static AdService get instance => _instance;

  AdService._internal() {
    if (_isAndroid) {
      _init();
    }
  }

  static const int _maxRetryAttempts = 3;
  int _currentRetry = 0;
  InterstitialAd? _interstitialAd;
  bool _isLoading = false;
  bool _interstitialReady = false;
  bool _isInitialized = false;
  DateTime? _lastShownAt;
  static const Duration _cooldown = Duration(minutes: 5);

  /// Check if an ad is ready to be shown
  bool get isAdReady => _interstitialReady && _interstitialAd != null;

  /// Whether ad display is currently in cooldown period
  bool get _inCooldown {
    if (_lastShownAt == null) return false;
    final elapsed = DateTime.now().difference(_lastShownAt!);
    return elapsed < _cooldown;
  }

  /// Initialize the ad service
  Future<void> _init() async {
    if (_isInitialized || !_isAndroid) return;

    getLogger('AdService').i('Initializing AdService...');

    try {
      _isInitialized = true;
      _loadInterstitialAd();
      getLogger('AdService').i('AdService initialized successfully');
    } catch (e) {
      getLogger('AdService').e('Failed to initialize AdService', error: e);
      _scheduleRetry();
    }
  }

  /// Load an interstitial ad
  Future<void> _loadInterstitialAd() async {
    if (!_isAndroid || _isLoading) return;

    _isLoading = true;
    _interstitialReady = false;

    try {
      await InterstitialAd.load(
        adUnitId: AdConfig.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _interstitialReady = true;
            _currentRetry = 0; // Reset retry counter on success
            _isLoading = false;
            getLogger('AdService').i('Interstitial ad loaded successfully');

            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                _interstitialReady = false;
                _interstitialAd?.dispose();
                _interstitialAd = null;
                _loadInterstitialAd(); // Load the next ad
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                getLogger('AdService').e('Failed to show ad: ${error.message}');
                ad.dispose();
                _interstitialAd = null;
                _loadInterstitialAd();
              },
            );
          },
          onAdFailedToLoad: (error) {
            getLogger('AdService').w('InterstitialAd failed to load: $error');
            _isLoading = false;
            _interstitialReady = false;
            _scheduleRetry();
          },
        ),
      );
    } catch (e) {
      getLogger('AdService').e('Error loading interstitial ad', error: e);
      _isLoading = false;
      _scheduleRetry();
    }
  }

  /// Schedule a retry for loading ads
  void _scheduleRetry() {
    if (_currentRetry >= _maxRetryAttempts) {
      getLogger('AdService').w('Max retry attempts reached');
      return;
    }

    _currentRetry++;
    final delay = Duration(seconds: _currentRetry * 5); // Exponential backoff

    Timer(delay, () {
      if (!_isInitialized) {
        _init();
      } else {
        _loadInterstitialAd();
      }
    });
  }

  /// Show an interstitial ad if one is ready
  Future<bool> showInterstitialAd() async {
    if (!_isAndroid) {
      getLogger('AdService').i('Skipping ad: Not running on Android');
      return false;
    }

    if (_inCooldown) {
      getLogger('AdService').i('Skipping interstitial: in cooldown');
      return false;
    }

    if (!_interstitialReady || _interstitialAd == null) {
      getLogger('AdService').w('Ad not ready to show');
      _loadInterstitialAd(); // Try to load for next time
      return false;
    }

    try {
      await _interstitialAd?.show();
      _lastShownAt = DateTime.now();
      // Marking shown-per-session removed; no-op
      return true;
    } catch (e) {
      getLogger('AdService').e('Failed to show ad', error: e);
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _interstitialReady = false;
      _loadInterstitialAd();
      return false;
    }
  }

  /// Returns banner ad unit ID for Android, empty string otherwise
  String getBannerAdUnitId({bool test = false}) {
    if (!_isAndroid) return '';
    return test ? AdConfig.testBannerAdUnitId : AdConfig.bannerAdUnitId;
  }

  /// Returns interstitial ad unit ID for Android, empty string otherwise
  String getInterstitialAdUnitId({bool test = false}) {
    if (!_isAndroid) return '';
    return test
        ? AdConfig.testInterstitialAdUnitId
        : AdConfig.interstitialAdUnitId;
  }

  /// Shows an ad if running on Android and an ad is ready
  Future<void> maybeShow() async {
    if (!_isAndroid) return;
    await showInterstitialAd();
  }

  /// Backwards-compatible preloader used throughout the app. Some screens call
  /// `AdService.instance.preloadInterstitial()` proactively so an interstitial
  /// is ready by the time the user navigates back. This simply triggers the
  /// internal loader with appropriate guards.
  void preloadInterstitial() {
    _loadInterstitialAd();
  }

  /// Show an interstitial ad and await its dismissal. Returns true if an ad
  /// was shown and dismissed, false otherwise. This helps callers wait until
  /// the ad is finished before continuing (for example, before popping a
  /// route).
  Future<bool> showInterstitialAndAwaitDismiss(
      {Duration timeout = const Duration(seconds: 8)}) async {
    if (!_isAndroid) return false;
    if (_inCooldown) return false;
    if (!_interstitialReady || _interstitialAd == null) {
      // Try to load for next time but signal no ad was shown now.
      _loadInterstitialAd();
      return false;
    }

    final completer = Completer<bool>();

    try {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          try {
            ad.dispose();
          } catch (_) {}
          _interstitialReady = false;
          _interstitialAd = null;
          // Kick off loading the next ad.
          _loadInterstitialAd();
          if (!completer.isCompleted) completer.complete(true);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          try {
            ad.dispose();
          } catch (_) {}
          _interstitialReady = false;
          _interstitialAd = null;
          _loadInterstitialAd();
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      // Show the ad (may throw) and wait for the callback to complete the future.
      _lastShownAt = DateTime.now();
      _interstitialAd!.show();
    } catch (e) {
      try {
        _interstitialAd?.dispose();
      } catch (_) {}
      _interstitialAd = null;
      _interstitialReady = false;
      _loadInterstitialAd();
      if (!completer.isCompleted) completer.complete(false);
    }

    try {
      return await completer.future.timeout(timeout, onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  /// Backwards-compatible method for loading interstitial ads
  Future<void> loadInterstitialAd({
    required void Function(InterstitialAd) onAdLoaded,
    required VoidCallback onAdDismissed,
  }) async {
    _loadInterstitialAd();

    // If an interstitial is ready immediately, call back
    if (_interstitialReady && _interstitialAd != null) {
      onAdLoaded(_interstitialAd!);
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) => onAdDismissed(),
        onAdFailedToShowFullScreenContent: (ad, error) => onAdDismissed(),
      );
    }
  }

  /// Dispose of resources
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _interstitialReady = false;
    _isLoading = false;
    _currentRetry = 0;
  }
}
