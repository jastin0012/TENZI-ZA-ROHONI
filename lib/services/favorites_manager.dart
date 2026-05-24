import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_imports.dart';
import 'package:tenzi_za_rohoni/models/hymn.dart';
import '../core/service_locator.dart';
import 'package:tenzi_za_rohoni/services/hymn_service.dart';
import '../utils/logger.dart';

/// Minimal FavoritesManager that stores favorite hymn IDs in SharedPreferences
/// and exposes a stream of Hymn objects when available from HymnService.
class FavoritesManager {
  static const String _favoritesKey = 'favorites_v2';

  // Provide backwards-compatible singleton accessor used across the app
  static FavoritesManager get instance => locator<FavoritesManager>();

  final SharedPreferences _prefs;
  final Logger _logger = getLogger('FavoritesManager');

  final _favoritesController = StreamController<List<Hymn>>.broadcast();
  final List<Hymn> _favorites = [];

  FavoritesManager(this._prefs);

  /// Stream of favorite Hymn objects. New listeners receive the current
  /// favorites immediately and subsequent updates thereafter.
  Stream<List<Hymn>> get favoritesStream {
    return Stream.multi((controller) {
      // Emit current favorites immediately for this listener
      controller.add(List.unmodifiable(_favorites));

      // Forward subsequent updates
      final sub = _favoritesController.stream.listen((list) {
        controller.add(list);
      }, onError: (e, st) => controller.addError(e, st));

      controller.onCancel = () {
        sub.cancel();
      };
    });
  }

  List<Hymn> get favorites => List.unmodifiable(_favorites);

  /// Stream of favorite hymn IDs for callers that only need ids.
  ///
  /// Implemented with `Stream.multi` so each new listener receives the
  /// current set of favorite ids immediately, and then receives subsequent
  /// updates from the internal `_favoritesController` stream.
  Stream<Set<String>> get favoritesIdStream {
    return Stream.multi((controller) {
      // Emit current favorites immediately for this listener
      controller.add(_favorites.map((h) => h.id).toSet());

      // Forward subsequent updates from the main favorites controller
      final sub = _favoritesController.stream.listen((list) {
        controller.add(list.map((h) => h.id).toSet());
      }, onError: (e, st) => controller.addError(e, st));

      controller.onCancel = () {
        sub.cancel();
      };
    });
  }

  /// Return list of favorite hymn ids
  Future<List<String>> getFavorites() async {
    return _favorites.map((h) => h.id).toList();
  }

  Future<void> initialize() async {
    await _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final jsonString = _prefs.getString(_favoritesKey);
      if (jsonString == null) return;
      final data = jsonDecode(jsonString) as List<dynamic>;
      _favorites.clear();
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          _favorites.add(Hymn.fromJson(item));
        }
      }
      _favoritesController.add(List.unmodifiable(_favorites));
    } catch (e) {
      _logger.w('Failed to load favorites: $e');
    }
  }

  bool isFavorite(String hymnId) => _favorites.any((h) => h.id == hymnId);

  Future<void> addToFavorite(Hymn hymn) async {
    if (isFavorite(hymn.id)) return;
    _favorites.add(hymn);
    await _saveToPrefs();
    _favoritesController.add(List.unmodifiable(_favorites));
  }

  /// Add by hymn id (string). Tries to resolve to a Hymn via HymnService,
  /// otherwise adds a minimal placeholder.
  Future<void> addToFavorites(String hymnId) async {
    if (isFavorite(hymnId)) return;
    Hymn? hymn;
    try {
      final svc = HymnService();
      hymn = await svc.getHymnByNumberString(hymnId);
    } catch (_) {}
    hymn ??=
        Hymn.fromJson({'song_number': hymnId, 'title': '', 'subtitle': ''});
    await addToFavorite(hymn);
  }

  Future<void> removeFromFavorites(String hymnId) async {
    _favorites.removeWhere((h) => h.id == hymnId);
    await _saveToPrefs();
    _favoritesController.add(List.unmodifiable(_favorites));
  }

  /// Toggle by id for existing call sites that pass ids
  Future<void> toggleFavoriteById(String hymnId) async {
    try {
      if (isFavorite(hymnId)) {
        await removeFromFavorites(hymnId);
      } else {
        await addToFavorites(hymnId);
      }
    } catch (e, stack) {
      _logger.w('Failed to toggle favorite for $hymnId',
          error: e, stackTrace: stack);
      // Do not rethrow to avoid crashing UI callers; FavoritesManager
      // will remain in a consistent state or log the error.
    }
  }

  Future<void> toggleFavorite(Hymn hymn) async {
    if (isFavorite(hymn.id)) {
      await removeFromFavorites(hymn.id);
    } else {
      await addToFavorite(hymn);
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final jsonList = _favorites.map((h) => h.toJson()).toList();
      await _prefs.setString(_favoritesKey, jsonEncode(jsonList));
    } catch (e) {
      _logger.w('Failed to save favorites: $e');
    }
  }

  void dispose() {
    _favoritesController.close();
  }
}
