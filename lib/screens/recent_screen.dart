import 'dart:async';
import 'package:flutter/material.dart';

import '../core/app_imports.dart';
import 'package:tenzi_za_rohoni/models/hymn.dart';
import '../utils/logger.dart';
import '../utils/recent_manager.dart';
import '../services/favorites_manager.dart';
import 'package:tenzi_za_rohoni/screens/search/search_page.dart';
import '../widgets/hymn_card.dart';
import 'hymn_detail_page.dart';
import '../core/service_locator.dart';
import '../utils/navigation_lock.dart';
import 'package:tenzi_za_rohoni/services/ad_service.dart';
import '../gen/l10n/app_localizations.dart';

final logger = getLogger('RecentScreen');

class RecentScreen extends StatefulWidget {
  const RecentScreen({super.key});

  @override
  State<RecentScreen> createState() => _RecentScreenState();
}

class _RecentScreenState extends State<RecentScreen> {
  List<Hymn> _recentHymns = [];
  bool _isLoading = true;
  bool _hasError = false;
  late final RecentManager _recentManager;
  StreamSubscription? _recentsSubscription;
  final Set<String> _favoriteHymnIds = {};
  StreamSubscription<Set<String>>? _favoritesSubscription;

  @override
  void initState() {
    super.initState();
    _recentManager = locator<RecentManager>();
    _favoritesSubscription = FavoritesManager.instance.favoritesIdStream.listen(
      (ids) {
        if (!mounted) return;
        setState(() {
          _favoriteHymnIds
            ..clear()
            ..addAll(ids);
        });
      },
      onError: (e) {},
    );
    _setupRecentsListener();
    _loadRecentHymns();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        AdService.instance.preloadInterstitial();
      } catch (_) {}
    });
  }

  void _setupRecentsListener() {
    _recentsSubscription = _recentManager.recentHymnsStream.listen(
      (hymns) {
        if (mounted) {
          setState(() {
            _recentHymns = hymns;
            _isLoading = false;
            _hasError = false;
          });
        }
      },
      onError: (error, stackTrace) {
        logger.e('Error in recents stream',
            error: error, stackTrace: stackTrace);
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
      },
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _recentsSubscription?.cancel();
    _favoritesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentHymns() async {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);

    try {
      setState(() => _isLoading = true);
      final hymns = await _recentManager.getRecentHymns();
      if (!mounted) return;

      setState(() {
        _recentHymns = hymns;
        _isLoading = false;
        _hasError = false;
      });
    } catch (e, stackTrace) {
      logger.e('Error loading recent hymns', error: e, stackTrace: stackTrace);
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations?.errorMessageDataFetch ?? 'Failed to load recent hymns')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(localizations?.recentTitle ?? 'Recent',
            textAlign: TextAlign.start),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            alignment: Alignment.center,
            onPressed: () async {
              await NavigationLock.instance.run(() async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SearchPage(hymns: _recentHymns),
                  ),
                );
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _confirmClearRecents();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                  value: 'clear', child: Text('Futa Historia')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildHymnList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHymnList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_recentHymns.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: _recentHymns.length,
      itemBuilder: (context, index) {
        return _buildHymnCard(_recentHymns[index]);
      },
    );
  }

  Widget _buildHymnCard(Hymn hymn) {
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    return HymnCard(
      hymn: hymn,
      isFavorite: _favoriteHymnIds.contains(hymn.id),
      onTap: () => _navigateToHymnDetail(hymn),
      onFavoriteToggled: (isFav) async {
        try {
          await FavoritesManager.instance.toggleFavoriteById(hymn.id);
          if (mounted) {
            messenger.showSnackBar(SnackBar(
              content: Text(isFav
                  ? (localizations?.addedToFavorites ?? 'Added to favorites')
                  : (localizations?.removedFromFavorites ?? 'Removed from favorites')),
              duration: const Duration(seconds: 2),
            ));
          }
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text(localizations?.favoriteUpdateFailed ?? 'Failed to update favorites')),
            );
          }
        }
      },
    );
  }

  Future<void> _navigateToHymnDetail(Hymn hymn) async {
    final localizations = AppLocalizations.of(context);
    try {
      _recentManager.addToRecent(hymn.id);

      if (!mounted) return;

      await NavigationLock.instance.run(() async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HymnDetailPage(
              hymn: hymn,
              isFavorite: _favoriteHymnIds.contains(hymn.id),
              onFavoriteToggled: (isFav) async {
                try {
                  await FavoritesManager.instance.toggleFavoriteById(hymn.id);
                } catch (e, st) {
                  logger.e('Failed to toggle favorite from RecentScreen',
                      error: e, stackTrace: st);
                }
              },
            ),
          ),
        );
      }, key: hymn.id);
    } catch (e) {
      logger.e('Error navigating to hymn detail', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations?.hymnOpenFailed ?? 'Failed to open hymn')),
      );
    }
  }

  Widget _buildEmptyState() {
    final localizations = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_outlined,
              size: 80,
              color: Theme.of(context).disabledColor.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              localizations?.noHymnsFound ?? 'No recently viewed hymns',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).textTheme.titleLarge?.color,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final localizations = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              localizations?.errorTitle ?? 'Error',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).textTheme.titleLarge?.color,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              localizations?.errorMessageDataFetch ?? 'Failed to load recent hymns',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.8),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: _loadRecentHymns,
              child: Text(localizations?.retry ?? 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearRecents() async {
    if (_recentHymns.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Futa Historia'),
        content: const Text(
            'Una uhakika unataka kufuta historia ya tenzi ulizozitazama?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HAPANA'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('NDIYO', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _recentManager.clearRecentHymns();
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Historia imefutwa')),
          );
        }
      } catch (e, stackTrace) {
        logger.e('Error clearing recent hymns',
            error: e, stackTrace: stackTrace);
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Imeshindikana kufuta historia')),
          );
        }
      }
    }
  }
}
