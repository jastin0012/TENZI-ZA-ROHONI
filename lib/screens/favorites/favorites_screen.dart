import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/hymn.dart';
import 'package:get_it/get_it.dart';
import '../../services/favorites_manager.dart';
import '../../utils/navigation_lock.dart';
import '../../services/hymn_service.dart';
import '../../utils/recent_manager.dart';
import '../../widgets/hymn_card.dart';
import '../hymn_detail_page.dart';
import '../../utils/logger.dart';
import '../search/search_screen.dart';
import '../../gen/l10n/app_localizations.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final HymnService _hymnService = HymnService();
  final List<Hymn> _hymns = [];
  final Set<String> _favoriteHymnIds = <String>{};
  bool _isLoading = true;
  bool _hasError = false;
  StreamSubscription<Set<String>>? _favoritesSubscription;

  @override
  void initState() {
    super.initState();
    _favoritesSubscription = FavoritesManager.instance.favoritesIdStream.listen(
      (Set<String> favs) {
        if (mounted) {
          setState(() {
            _favoriteHymnIds.clear();
            _favoriteHymnIds.addAll(favs);
            _filterHymns();
          });
        }
      },
      onError: (error, st) {
        getLogger('FavoritesScreen')
            .e('Error in favorites stream', error: error, stackTrace: st);
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final favorites = await FavoritesManager.instance.getFavorites();
      final favoriteHymns =
          await _hymnService.getHymnsByNumberStrings(favorites);

      if (mounted) {
        setState(() {
          _hymns.clear();
          _hymns.addAll(favoriteHymns);
          _favoriteHymnIds.clear();
          _favoriteHymnIds.addAll(favorites);
          _isLoading = false;
        });
      }
    } catch (e, st) {
      getLogger('FavoritesScreen')
          .e('Error loading favorites', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _filterHymns() async {
    try {
      final favorites = await FavoritesManager.instance.getFavorites();
      final favoriteHymns = <Hymn>[];
      for (final hymn in _hymns) {
        if (favorites.contains(hymn.id)) {
          favoriteHymns.add(hymn);
        }
      }

      if (mounted) {
        setState(() {
          _hymns.clear();
          _hymns.addAll(favoriteHymns);
          _favoriteHymnIds.clear();
          _favoriteHymnIds.addAll(favorites);
        });
      }
    } catch (e, st) {
      getLogger('FavoritesScreen')
          .e('Error filtering hymns', error: e, stackTrace: st);
      if (mounted) {
        setState(() => _hasError = true);
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations?.favoriteUpdateFailed ?? 'Failed to update favorites')),
        );
      }
    }
  }

  Future<void> _navigateToHymnDetail(Hymn hymn) async {
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
                getLogger('FavoritesScreen')
                    .e('Failed to toggle favorite',
                        error: e, stackTrace: st);
              }
            },
          ),
        ),
      );
    }, key: hymn.id);

    if (mounted) {
      await _loadFavorites();
    }
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              localizations?.favoriteUpdateFailed ?? 'Failed to load favorites',
              style: const TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFavorites,
              child: Text(localizations?.retry ?? 'Try again'),
            ),
          ],
        ),
      );
    }

    final sortedHymns = List<Hymn>.from(_hymns)
      ..sort((a, b) => (int.tryParse(a.number) ?? 0).compareTo(
            int.tryParse(b.number) ?? 0,
          ));

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(localizations?.favoritesTitle ?? 'Favorites', textAlign: TextAlign.start),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              await NavigationLock.instance.run(() async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SearchScreen(
                      initialHymns: List<Hymn>.from(sortedHymns),
                      title: localizations?.favoritesTitle,
                    ),
                  ),
                );
              });
            },
          ),
        ],
      ),
      body: sortedHymns.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: scheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations?.noHymnsFound ?? 'No favorite hymns found',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${sortedHymns.length} ${localizations?.favoritesTitle}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: sortedHymns.length,
                    itemBuilder: (context, index) {
                      final hymn = sortedHymns[index];
                      return HymnCard(
                        hymn: hymn,
                        isFavorite: _favoriteHymnIds.contains(hymn.id),
                        onTap: () async {
                          final recent = GetIt.I<RecentManager>();
                          await recent.addToRecent(hymn.id);
                          _navigateToHymnDetail(hymn);
                        },
                        onFavoriteToggled: (isFav) async {
                          final localizations = AppLocalizations.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await FavoritesManager.instance
                                .toggleFavoriteById(hymn.id);
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(isFav
                                      ? (localizations?.addedToFavorites ?? 'Added to favorites')
                                      : (localizations?.removedFromFavorites ?? 'Removed from favorites')),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                    content: Text(localizations?.favoriteUpdateFailed ?? 'Failed to update favorites')),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
