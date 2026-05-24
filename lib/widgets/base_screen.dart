import 'package:flutter/material.dart';
// colors are provided via ThemeData now

class BaseScreen extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showBackground;
  final bool showSafeArea;
  final Color? backgroundColor;

  const BaseScreen({
    super.key,
    required this.child,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showBackground = true,
    this.showSafeArea = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = showSafeArea
        ? SafeArea(
            child: child,
          )
        : child;

    return Scaffold(
      // Prefer theme's scaffoldBackgroundColor so AppBarTheme/background
      // stay consistent with the active theme. Allow overriding via
      // `backgroundColor` when needed.
      backgroundColor: backgroundColor ??
          (showBackground
              ? Theme.of(context).scaffoldBackgroundColor
              : Colors.transparent),
      appBar: appBar,
      body: content,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
