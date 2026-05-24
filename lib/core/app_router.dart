import 'package:flutter/material.dart';
import 'package:tenzi_za_rohoni/models/hymn.dart';
import 'package:tenzi_za_rohoni/screens/hymn_detail_page.dart';
import 'package:tenzi_za_rohoni/services/favorites_manager.dart';
import 'package:tenzi_za_rohoni/screens/search/search_screen.dart';
import 'package:tenzi_za_rohoni/screens/settings/settings_screen.dart';
import 'package:tenzi_za_rohoni/screens/about/about_screen.dart';
import 'package:tenzi_za_rohoni/screens/feedback/feedback_screen.dart';
import 'package:tenzi_za_rohoni/main_layout.dart';
import 'package:tenzi_za_rohoni/utils/logger.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const MainLayout());
      case '/hymn':
        final hymn = settings.arguments as Hymn;
        return MaterialPageRoute(
          builder: (_) => HymnDetailPage(
            key: ValueKey('hymn_${hymn.id}'),
            hymn: hymn,
            isFavorite: FavoritesManager.instance.isFavorite(hymn.id),
            onFavoriteToggled: (isFav) async {
              try {
                await FavoritesManager.instance.toggleFavoriteById(hymn.id);
              } catch (e, st) {
                getLogger('AppRouter')
                    .e('Failed to toggle favorite from AppRouter',
                        error: e, stackTrace: st);
              }
            },
          ),
        );
      case '/search':
        return MaterialPageRoute(
          builder: (_) => const SearchScreen(),
        );
      case '/settings':
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        );
      case '/settings/about':
        return MaterialPageRoute(
          builder: (_) => const AboutScreen(),
        );
      case '/settings/feedback':
        return MaterialPageRoute(
          builder: (_) => const FeedbackScreen(),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
