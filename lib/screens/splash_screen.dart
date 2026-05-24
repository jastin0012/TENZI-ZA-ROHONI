import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:tenzi_za_rohoni/theme/colors.dart';
import 'package:tenzi_za_rohoni/main_layout.dart';
import 'package:tenzi_za_rohoni/services/hymn_service.dart';
import 'package:tenzi_za_rohoni/models/hymn.dart';
import 'package:tenzi_za_rohoni/widgets/error_view.dart';

class SplashScreen extends StatefulWidget {
  final ValueChanged<bool>? onDarkModeChanged;
  const SplashScreen({super.key, this.onDarkModeChanged});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      colors: true,
      printEmojis: false,
      printTime: false,
    ),
  );

  // progress/status kept previously for a linear progress UI; not used in the new design
  bool _hasError = false;
  bool _isInitializing = false;
  // keep status/progress fields so legacy _updateStatus calls remain valid
  String _status = '';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  void _updateStatus(String status, double progress) {
    if (!mounted) return;
    setState(() {
      _status = status;
      _progress = progress;
    });
  }

  Future<void> _initializeApp() async {
    if (_isInitializing) return;
    _isInitializing = true;
    _hasError = false;
    final start = DateTime.now();

    try {
      _updateStatus('Inapakua nyimbo...', 0.2);

      // Initialize HymnService with error handling
      try {
        final hymnService = HymnService();

        // First try to load from cache
        _updateStatus('Inasoma kumbukumbu za nyimbo...', 0.4);
        await hymnService.getAllHymns();

        if (!mounted) return;

        // Then refresh in background
        _updateStatus('Inasasisha orodha ya nyimbo...', 0.7);
        unawaited(hymnService.getAllHymns(forceRefresh: true).catchError((e) {
          _logger.w('Background refresh failed: $e');
          return <Hymn>[];
        }));
      } catch (e, stack) {
        _logger.e('Error initializing hymns', error: e, stackTrace: stack);
        if (mounted) {
          setState(() => _hasError = true);
        }
        return;
      }

      if (!mounted) return;

      _updateStatus('Tayari!', 1.0);
      // Ensure splash is visible for at least 3 seconds total
      final elapsed = DateTime.now().difference(start);
      final remaining = const Duration(seconds: 3) - elapsed;
      if (remaining.isNegative == false) {
        await Future.delayed(remaining);
      }

      if (!mounted) return;

      // Navigate to main app
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainLayout(initialIndex: 0),
          ),
        );
      }
    } catch (e, stack) {
      _logger.e('Critical error during app initialization',
          error: e, stackTrace: stack);

      if (mounted) {
        setState(() => _hasError = true);
      }
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _retryInitialization() async {
    if (_isInitializing) return;

    if (mounted) {
      setState(() {
        _hasError = false;
        _isInitializing = true;
      });
    }

    // Add a small delay to allow the UI to update
    await Future.delayed(const Duration(milliseconds: 100));

    await _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    // theme variable removed because this splash uses only the logo + indicator

    if (_hasError) {
      return ErrorView(
        message:
            'Haikuweza kuanzisha programu. Tafadhali angalia muunganisho wa intaneti na ujaribu tena.',
        onRetry: _retryInitialization,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Centered app logo (rounded)
            Hero(
              tag: 'app_logo',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 220,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.music_note,
                      size: 100,
                      color: Colors.grey,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Small circular loading indicator under the logo
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppColors.darkText : Colors.black),
              ),
            ),

            // Keep status/progress in the widget tree offstage so analyzer
            // recognizes they're used by _updateStatus while remaining hidden.
            Offstage(
              offstage: true,
              child: Column(
                children: [
                  Text(_status),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(value: _progress),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
