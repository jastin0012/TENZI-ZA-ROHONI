import 'dart:async';
// removed unused imports
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_imports.dart';
import 'package:tenzi_za_rohoni/models/hymn.dart';
import 'package:tenzi_za_rohoni/services/hymn_service.dart';
import 'package:tenzi_za_rohoni/utils/logger.dart';

// Provide a GetIt-backed singleton accessor so callers can do
// `RecentManager.instance.addToRecent(...)` safely.
import '../core/service_locator.dart' as service_locator;

/// Manages recently viewed hymns using SharedPreferences for persistence
class RecentManager {
  final _logger = getLogger('RecentManager');

  /// Convenience accessor to the app-wide RecentManager registered in the
  /// service locator. Allows legacy static-style usage in the codebase.
  static RecentManager get instance => service_locator.locator<RecentManager>();

  static const String _recentsKey = 'recent_hymns_v2';
  static const int _maxRecents = 50;
  static const Duration _cacheDuration = Duration(minutes: 5);

  final SharedPreferences _prefs;
  final HymnService _hymnService;

  final _recentsController = StreamController<List<String>>.broadcast();
  final _recentHymnsController = StreamController<List<Hymn>>.broadcast();

  List<Hymn>? _recentHymnsCache;
  DateTime _lastCacheUpdate = DateTime(0);
  bool _isInitialized = false;
  Exception? _lastError;

  /// Stream of recent hymn IDs
  Stream<List<String>> get recentsStream => _recentsController.stream;

  /// Stream of recent hymn objects
  Stream<List<Hymn>> get recentHymnsStream => _recentHymnsController.stream;

  /// Constructor with required dependencies
  RecentManager({
    required SharedPreferences prefs,
    required HymnService hymnService,
  })  : _prefs = prefs,
        _hymnService = hymnService;

  /// Initialize the manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load recent hymn IDs from cache
      final ids = await getRecentHymnIds();
      if (ids.isNotEmpty) {
        _recentsController.add(ids);
        // Preload recent hymns
        await _loadRecentHymns(ids);
      }
      _isInitialized = true;
    } catch (e, stackTrace) {
      _lastError =
          e is Exception ? e : Exception('Failed to initialize RecentManager');
      _logger.e('Error initializing RecentManager',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Add a hymn to recents
  Future<void> addToRecent(String hymnId) async {
    try {
      if (hymnId.isEmpty) return;

      // Get current recents
      final List<String> recents = await getRecentHymnIds();

      // Remove if already exists to maintain order
      recents.remove(hymnId);

      // Add to beginning of list
      recents.insert(0, hymnId);

      // Trim to max size
      if (recents.length > _maxRecents) {
        recents.removeRange(_maxRecents, recents.length);
      }

      // Save to prefs
      await _prefs.setStringList(_recentsKey, recents);

      // Update streams
      _recentsController.add(List.unmodifiable(recents));
      await _loadRecentHymns(recents);
    } catch (e, stackTrace) {
      _lastError = e is Exception ? e : Exception('Failed to add to recents');
      _logger.e('Error adding to recents', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get list of recent hymn IDs
  Future<List<String>> getRecentHymnIds() async {
    try {
      return _prefs.getStringList(_recentsKey) ?? [];
    } catch (e, stackTrace) {
      _lastError =
          e is Exception ? e : Exception('Failed to get recent hymn IDs');
      _logger.e('Error getting recent hymn IDs',
          error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get list of recent hymn objects
  Future<List<Hymn>> getRecentHymns() async {
    try {
      final ids = await getRecentHymnIds();
      if (ids.isEmpty) return [];

      // Check if cache is still valid
      if (_recentHymnsCache != null &&
          DateTime.now().difference(_lastCacheUpdate) < _cacheDuration) {
        return _recentHymnsCache!;
      }

      // Load from service
      final hymns = await _hymnService.getHymnsByNumberStrings(ids);

      // Sort to match the order of IDs
      final hymnMap = {for (var hymn in hymns) hymn.id: hymn};
      final sortedHymns = <Hymn>[];

      for (final id in ids) {
        final hymn = hymnMap[id];
        if (hymn != null) {
          sortedHymns.add(hymn);
        }
      }

      // Update cache
      _recentHymnsCache = sortedHymns;
      _lastCacheUpdate = DateTime.now();

      return sortedHymns;
    } catch (e, stackTrace) {
      _lastError =
          e is Exception ? e : Exception('Failed to load recent hymns');
      _logger.e('Error getting recent hymns', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Clear recent hymns
  Future<void> clearRecentHymns() async {
    try {
      await _prefs.remove(_recentsKey);
      _recentHymnsCache = [];
      _lastCacheUpdate = DateTime.now();
      _recentsController.add([]);
      _recentHymnsController.add([]);
    } catch (e, stackTrace) {
      _lastError =
          e is Exception ? e : Exception('Failed to clear recent hymns');
      _logger.e('Error clearing recent hymns',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Load recent hymns and update stream
  Future<void> _loadRecentHymns(List<String> ids) async {
    try {
      if (ids.isEmpty) {
        _recentHymnsController.add([]);
        return;
      }

      final hymns = await _hymnService.getHymnsByNumberStrings(ids);

      // Sort to match the order of IDs
      final hymnMap = {for (var hymn in hymns) hymn.id: hymn};
      final sortedHymns = <Hymn>[];

      for (final id in ids) {
        final hymn = hymnMap[id];
        if (hymn != null) {
          sortedHymns.add(hymn);
        }
      }

      _recentHymnsCache = sortedHymns;
      _lastCacheUpdate = DateTime.now();
      _recentHymnsController.add(sortedHymns);
    } catch (e, stackTrace) {
      _lastError =
          e is Exception ? e : Exception('Failed to load recent hymns');
      _logger.e('Error loading recent hymns', error: e, stackTrace: stackTrace);
      _recentHymnsController.addError(e);
    }
  }

  /// Get the last error that occurred
  Exception? get lastError => _lastError;

  /// Check if the manager is initialized
  bool get isInitialized => _isInitialized;

  /// Get the timestamp of the last cache update
  DateTime get lastCacheUpdate => _lastCacheUpdate;

  /// Get the number of recent hymns
  Future<int> get recentHymnsCount async {
    final ids = await getRecentHymnIds();
    return ids.length;
  }

  /// Dispose resources
  void dispose() {
    _recentsController.close();
    _recentHymnsController.close();
  }
}
