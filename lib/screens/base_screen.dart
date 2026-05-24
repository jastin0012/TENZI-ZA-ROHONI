import 'package:flutter/material.dart';

/// Lightweight BaseScreen used across the app to provide a consistent
/// scaffold and optional app bar. Kept intentionally minimal so it is
/// safe to use while other screens are iteratively fixed.
class BaseScreen extends StatelessWidget {
  final Widget child;
  final String? title;
  final bool useSafeArea;

  const BaseScreen(
      {super.key, required this.child, this.title, this.useSafeArea = true});

  @override
  Widget build(BuildContext context) {
    final body = useSafeArea ? SafeArea(child: child) : child;
    return Scaffold(
      appBar: title != null ? AppBar(title: Text(title!)) : null,
      body: body,
    );
  }
}
