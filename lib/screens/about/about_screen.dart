// Flutter packages
import 'package:flutter/material.dart';

// Third-party packages
import 'package:package_info_plus/package_info_plus.dart';

import '../../theme/colors.dart';

// Theme
// (colors imported via ThemeData where needed)

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      // Fallback if package info fails
      if (!mounted) return;
      setState(() {
        _version = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Brand yellow used across the app
    const Color brandYellow = Color(0xFFF7BA14);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : brandYellow,
      body: SafeArea(
        child: Stack(
          children: [
            // Vertical subtle stripes background
            const Positioned.fill(
              child: CustomPaint(
                painter: _StripedBackgroundPainter(color: brandYellow),
              ),
            ),

            // Back button
            Positioned(
              top: 12,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
                color: isDark ? const Color(0xFFE1E1E1) : Colors.black,
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: brandYellow.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Toleo ${_version.isEmpty ? '...' : _version}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.darkText : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Footer small text
            Positioned(
              bottom: 10,
              left: 8,
              right: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Imebuniwa na kutengenezwa na Ravens Consulting Co. Ltd',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkText : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tovuti: www.ravensconsulting.co.tz',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkText : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Developer: Jastin Salvatory',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkText : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
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

// Painter for subtle vertical stripes to match design
class _StripedBackgroundPainter extends CustomPainter {
  final Color color;
  const _StripedBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    // Base fill
    canvas.drawRect(Offset.zero & size, paint);

    // Draw subtle vertical stripes with slightly darker tint
    final stripePaint = Paint()..color = color.withOpacity(0.06);
    const stripeWidth = 18.0;
    for (double x = 0; x < size.width; x += stripeWidth * 2) {
      canvas.drawRect(
          Rect.fromLTWH(x, 0, stripeWidth, size.height), stripePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
