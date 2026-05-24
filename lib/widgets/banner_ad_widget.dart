// Core imports
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tenzi_za_rohoni/utils/logger.dart';

// Core app imports
import 'package:tenzi_za_rohoni/services/ad_service.dart';

/// A widget that displays a banner ad with automatic loading and error handling.
/// The ad will automatically dispose when the widget is disposed.
class BannerAdWidget extends StatefulWidget {
  /// The size of the banner ad
  final AdSize size;

  /// Optional custom ad unit ID. If not provided, the default from AdService will be used.
  final String? adUnitId;

  /// Whether to keep the ad alive when the widget is not visible.
  /// If true, the ad will not be disposed when the widget is not visible.
  /// Defaults to false to save resources.
  final bool keepAlive;

  const BannerAdWidget({
    super.key,
    required this.size,
    this.adUnitId,
    this.keepAlive = false,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget>
    with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  int _currentRetry = 0;
  static const int _maxRetries = 3;
  final AdService _adService = AdService.instance;

  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(fn);
    });
  }

  @override
  void didUpdateWidget(BannerAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.size != oldWidget.size ||
        widget.adUnitId != oldWidget.adUnitId) {
      _loadBannerAd();
    }
  }

  Future<void> _loadBannerAd() async {
    // Skip loading ads on non-Android platforms or in web
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _safeSetState(() => _isAdLoaded = false);
      return;
    }

    // Use explicit test ad unit IDs when running non-release builds to
    // guarantee test inventory is returned during development/testing.
    final adUnitId =
        widget.adUnitId ?? _adService.getBannerAdUnitId(test: !kReleaseMode);
    if (adUnitId.isEmpty) {
      _safeSetState(() => _isAdLoaded = false);
      return;
    }

    try {
      // If the requested size is AdSize.banner, prefer an adaptive anchored
      // banner that matches device width to look more native.
      AdSize requestedSize = widget.size;
      if (widget.size == AdSize.banner) {
        try {
          final width = MediaQuery.of(context).size.width.toInt();
          final adaptive =
              await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
                  width);
          if (adaptive != null) requestedSize = adaptive;
        } catch (_) {
          // Fallback to provided size if adaptive calculation fails.
          requestedSize = widget.size;
        }
      }

      final bannerAd = BannerAd(
        adUnitId: adUnitId,
        size: requestedSize,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted) {
              ad.dispose();
              return;
            }
            // Cast early so we can log details immediately
            final loadedBanner = ad as BannerAd;
            _safeSetState(() {
              _bannerAd?.dispose();
              _bannerAd = loadedBanner;
              _isAdLoaded = true;
            });
            // Provide a clear debug log when an ad successfully loads.
            getLogger('BannerAdWidget').i(
                'BannerAd loaded: ${loadedBanner.adUnitId} size=${loadedBanner.size}');
          },
          onAdFailedToLoad: (ad, error) {
            // Provide more detailed logs for debugging
            getLogger('BannerAdWidget').w(
                'Failed to load banner ad (code=${error.code}): ${error.message}');
            ad.dispose();
            _safeSetState(() {
              _isAdLoaded = false;
            });

            // Retry with exponential backoff. Use a shorter delay in debug
            // builds so developers get faster feedback.
            const baseDelaySec = kReleaseMode ? 30 : 5;
            Future.delayed(
                Duration(seconds: baseDelaySec * (_currentRetry + 1)), () {
              if (mounted && _currentRetry < _maxRetries) {
                _currentRetry++;
                _loadBannerAd();
              }
            });
          },
        ),
      );

      await bannerAd.load();
    } catch (e) {
      getLogger('BannerAdWidget').e('Error loading banner ad', error: e);
      _safeSetState(() => _isAdLoaded = false);
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
    super.dispose();
  }

  @override
  void deactivate() {
    // Avoid calling setState during deactivate/build phase. We only clear
    // internal references here; actual disposal happens in dispose().
    if (!widget.keepAlive) {
      _bannerAd = null;
      _isAdLoaded = false;
    }
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Needed for AutomaticKeepAliveClientMixin

    // Reserve the banner height and center the ad. Show a neutral placeholder
    // when the ad is not available to avoid layout jumps. Wrap in SafeArea to
    // ensure the banner isn't clipped by gesture/navigation areas.
    final reservedHeight = widget.size.height.toDouble();

    final bool canShowRealAd =
        defaultTargetPlatform == TargetPlatform.android &&
            _bannerAd != null &&
            _isAdLoaded;

    // In release builds, collapse the space entirely when there is no ad to
    // avoid leaving an empty colored strip. In debug, keep a minimal placeholder
    // to visualize the slot during development.
    final double effectiveHeight = canShowRealAd
        ? (_bannerAd?.size.height.toDouble() ?? reservedHeight)
        : (kReleaseMode ? 0 : reservedHeight);

    final Widget content = SizedBox(
      width: double.infinity,
      height: effectiveHeight,
      child: canShowRealAd
          ? Center(child: AdWidget(ad: _bannerAd!))
          : (defaultTargetPlatform == TargetPlatform.android && !kReleaseMode)
              ? Builder(
                  builder: (context) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    return Container(
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: Text(
                        'Banner slot (no ad loaded)',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey : Colors.black45),
                      ),
                    );
                  },
                )
              : const SizedBox.shrink(),
    );

    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          if (canShowRealAd) const BannerNavDivider(),
        ],
      ),
    );
  }

  // Placeholder handled inline in build(); helper removed.
}

// A tiny translucent divider to visually separate banner from bottom nav.
class BannerNavDivider extends StatelessWidget {
  const BannerNavDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.black.withOpacity(0.06)
          : Colors.white.withOpacity(0.06),
    );
  }
}

// A smaller banner variant for tight spaces
class SmallBannerAd extends StatelessWidget {
  const SmallBannerAd({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 50,
      child: BannerAdWidget(size: AdSize.banner, keepAlive: true),
    );
  }
}
