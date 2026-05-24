import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:tenzi_za_rohoni/models/hymn.dart';
import 'package:get_it/get_it.dart';

const String _hymnsAssetPath = 'assets/json/tenzi.json';
const String _hymnsCacheKey = 'cached_hymns';
const String _lastUpdatedKey = 'last_updated';
const Duration _cacheDuration = Duration(days: 1);

/// Service for loading and managing hymns with caching
class HymnService {
  static final HymnService _instance = HymnService._internal();
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
      printTime: false,
    ),
  );

  List<Hymn>? _hymns;
  Completer<void>? _initCompleter;
  DateTime? _lastUpdated;

  // Private constructor
  HymnService._internal();

  // Factory constructor to return the singleton instance
  factory HymnService() => _instance;

  static HymnService get instance => GetIt.I<HymnService>();

  // Getters
  bool get isInitialized => _hymns != null;
  DateTime? get lastUpdated => _lastUpdated;

  /// Load all hymns with caching support. Ensures only one initialization happens.
  Future<void> _loadHymns() async {
    if (_hymns != null) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    try {
      // 1. Try loading from cache first for fast startup
      final cachedHymns = await _loadFromCache();
      if (cachedHymns != null && cachedHymns.isNotEmpty) {
        _hymns = cachedHymns;
        _logger.i('Loaded ${_hymns!.length} hymns from cache');
      }

      // 2. If no cache or cache is stale, load from assets
      final shouldRefresh = _hymns == null ||
          _lastUpdated == null ||
          DateTime.now().difference(_lastUpdated!) > _cacheDuration;

      if (shouldRefresh) {
        await _refreshHymns();
      }

      if (_hymns == null || _hymns!.isEmpty) {
        throw Exception('Hymn database is empty after loading');
      }

      _initCompleter!.complete();
    } catch (e, stack) {
      _logger.e('Error loading hymns', error: e, stackTrace: stack);
      if (_hymns != null) {
        // We have cached data, so we can recover from refresh failure
        _initCompleter!.complete();
      } else {
        _initCompleter!.completeError(e, stack);
      }
    } finally {
      _initCompleter = null;
    }
  }

  /// Refresh hymns from the asset file
  Future<void> _refreshHymns() async {
    try {
      _logger.i('Refreshing hymns from assets');
      final jsonString = await rootBundle.loadString(_hymnsAssetPath);
      final List<dynamic> jsonList = jsonDecode(jsonString);

      final newHymns = jsonList.map((json) => Hymn.fromJson(json)).toList();

      if (newHymns.isNotEmpty) {
        _hymns = newHymns;
        _lastUpdated = DateTime.now();
        // Update cache in background
        _saveToCache(_hymns!)
            .catchError((e) => _logger.w('Cache save failed: $e'));
        _logger.i('Successfully refreshed ${_hymns!.length} hymns from assets');
      }
    } catch (e, stack) {
      _logger.e('Error refreshing hymns', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Load hymns from cache
  Future<List<Hymn>?> _loadFromCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_hymnsCacheKey.json');

      if (!await file.exists()) return null;

      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final lastUpdatedStr = data[_lastUpdatedKey] as String?;
      if (lastUpdatedStr == null) return null;

      final lastUpdated = DateTime.parse(lastUpdatedStr);
      final jsonList = data[_hymnsCacheKey] as List?;

      if (jsonList == null) return null;

      _lastUpdated = lastUpdated;
      return jsonList.map((e) => Hymn.fromJson(e)).toList();
    } catch (e) {
      _logger.w('Error loading from cache: $e');
      return null;
    }
  }

  /// Save hymns to cache
  Future<void> _saveToCache(List<Hymn> hymns) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_hymnsCacheKey.json');

      final data = {
        _lastUpdatedKey: DateTime.now().toIso8601String(),
        _hymnsCacheKey: hymns.map((h) => h.toJson()).toList(),
      };

      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      _logger.w('Error saving to cache: $e');
    }
  }

  /// Get all hymns with optional force refresh
  Future<List<Hymn>> getAllHymns({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await _refreshHymns();
    } else {
      await _loadHymns();
    }

    if (_hymns == null) {
      throw Exception('Failed to load hymns');
    }

    return List<Hymn>.unmodifiable(_hymns!);
  }

  /// Get a list of hymns by their numbers
  Future<List<Hymn>> getHymnsByNumbers(List<int> numbers) async {
    await _loadHymns();
    final numbersSet = numbers.toSet();
    return _hymns!
        .where((hymn) => numbersSet.contains(hymn.songNumber))
        .toList();
  }

  /// Get a list of hymns by their numbers (string version for compatibility)
  Future<List<Hymn>> getHymnsByNumberStrings(List<String> numberStrings) async {
    final numbers =
        numberStrings.map((s) => int.tryParse(s)).whereType<int>().toList();
    return getHymnsByNumbers(numbers);
  }

  /// Get a hymn by song number
  Future<Hymn?> getHymnByNumber(int number) async {
    await _loadHymns();
    try {
      return _hymns!.firstWhere((hymn) => hymn.songNumber == number);
    } catch (e) {
      _logger.w('Hymn not found for number: $number');
      return null;
    }
  }

  /// Get a hymn by song number (string version for compatibility)
  Future<Hymn?> getHymnByNumberString(String number) async {
    final num = int.tryParse(number);
    if (num == null) return null;
    return getHymnByNumber(num);
  }

  /// Search hymns by title or number
  Future<List<Hymn>> searchHymns(String query, {int limit = 50}) async {
    await _loadHymns();
    if (query.isEmpty) return [];

    final searchQuery = query.toLowerCase().trim();
    final results = <Hymn>[];

    for (final hymn in _hymns!) {
      if (hymn.title.toLowerCase().contains(searchQuery) ||
          hymn.number.toLowerCase().contains(searchQuery)) {
        results.add(hymn);
      }
      if (results.length >= limit) break;
    }

    return results;
  }
}
