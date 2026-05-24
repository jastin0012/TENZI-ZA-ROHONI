import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tenzi_za_rohoni/models/hymn.dart';
import 'package:tenzi_za_rohoni/services/favorites_manager.dart';
import 'package:tenzi_za_rohoni/services/hymn_service.dart';
import 'package:tenzi_za_rohoni/services/notification_service.dart';
import 'package:tenzi_za_rohoni/screens/hymn_detail_page.dart';
import 'package:tenzi_za_rohoni/screens/notifications/notifications_screen.dart';
import 'package:tenzi_za_rohoni/widgets/base_screen.dart';
import 'package:tenzi_za_rohoni/widgets/hymn_card.dart';
import 'package:tenzi_za_rohoni/widgets/notification_banner.dart';
import '../../utils/navigation_lock.dart';
import 'package:tenzi_za_rohoni/services/ad_service.dart';
import 'package:tenzi_za_rohoni/utils/logger.dart';
import 'package:tenzi_za_rohoni/screens/search/search_screen.dart';
import 'package:tenzi_za_rohoni/gen/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Hymn> _hymns = [];
  final Set<String> _favoriteHymnIds = {};
  final Set<String> _unopenedNotifications = {};
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _hasMore = false;
  bool _isNavigating = false;

  Timer? _syncTicker;
  StreamSubscription<List<String>>? _unopenedSub;
  StreamSubscription<int>? _unreadCountSub;
  StreamSubscription<Set<String>>? _favoritesSub;
  String? _topUnopenedHymn;

  @override
  void initState() {
    super.initState();
    _setupScrollController();
    _loadInitialData();
    _subscribeUnopened();
    try {
      _unreadCountSub = NotificationService().unreadCountStream.listen((count) {
        if (!mounted) return;
        setState(() {
          _unreadCount = count;
        });
      });
    } catch (_) {}
    
    _favoritesSub = FavoritesManager.instance.favoritesIdStream.listen((ids) {
      if (!mounted) return;
      setState(() {
        _favoriteHymnIds
          ..clear()
          ..addAll(ids);
      });
    });
    _startSyncTicker();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        AdService.instance.preloadInterstitial();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _syncTicker?.cancel();
    _scrollController.dispose();
    _unopenedSub?.cancel();
    _unreadCountSub?.cancel();
    _favoritesSub?.cancel();
    _unopenedSub = null;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _setupScrollController() {
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreHymns();
      }
    });
  }

  void _subscribeUnopened() {
    try {
      _unopenedSub = NotificationService().unopenedStream.listen((list) {
        if (!mounted) return;
        setState(() {
          _unopenedNotifications
            ..clear()
            ..addAll(list);
          _topUnopenedHymn = list.isNotEmpty ? list.first : null;
          _unreadCount = list.length;
        });
      });
    } catch (_) {}
  }

  Future<void> _loadInitialData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadHymns(),
        _loadFavorites(),
      ]);
    } catch (e, st) {
      getLogger('HomeScreen')
          .e('Error loading initial data', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHymns() async {
    final localizations = AppLocalizations.of(context);
    try {
      final hymns = await HymnService().getAllHymns();
      if (!mounted) return;
      setState(() {
        _hymns
          ..clear()
          ..addAll(hymns);
        _hasMore = false;
      });
    } catch (e, st) {
      getLogger('HomeScreen')
          .e('Error loading hymns', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations?.hymnsLoadFailed ?? 'Failed to load hymns')),
        );
      }
    }
  }

  Future<void> _loadMoreHymns() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    try {
      await _loadHymns();
    } catch (e, st) {
      getLogger('HomeScreen')
          .e('Error loading more hymns', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await FavoritesManager.instance.getFavorites();
      if (mounted) {
        setState(() {
          _favoriteHymnIds
            ..clear()
            ..addAll(favorites);
        });
      }
    } catch (e, st) {
      getLogger('HomeScreen')
          .e('Error loading favorites', error: e, stackTrace: st);
    }
  }

  Future<void> _navigateToSearch() async {
    if (!mounted) return;
    await NavigationLock.instance.run(() async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SearchScreen(),
        ),
      );
    });
  }

  Future<void> _onHymnTap(Hymn hymn) async {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      try {
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
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isFav
                            ? (localizations?.addedToFavorites ?? 'Added to favorites')
                            : (localizations?.removedFromFavorites ?? 'Removed from favorites')),
                        duration: const Duration(seconds: 2),
                      ));
                    }
                  } catch (e, st) {
                    getLogger('HomeScreen').e(
                      'Failed to toggle favorite from HomeScreen list tap',
                      error: e,
                      stackTrace: st,
                    );
                  }
                },
              ),
            ),
          );
        }, key: hymn.id);
      } catch (e, st) {
        getLogger('HomeScreen')
            .e('Failed to open hymn from HomeScreen', error: e, stackTrace: st);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations?.hymnOpenFailed ?? 'Failed to open hymn. Try again.'),
            ),
          );
        }
      }
    } finally {
      _isNavigating = false;
    }

    if (mounted) await _loadFavorites();
  }

  Widget _buildHymnList() {
    final localizations = AppLocalizations.of(context);
    if (_hymns.isEmpty && !_isLoading) {
      return Center(child: Text(localizations?.noHymnsFound ?? 'No hymns found'));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _hymns.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _hymns.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final hymn = _hymns[index];
        return HymnCard(
          hymn: hymn,
          isFavorite: _favoriteHymnIds.contains(hymn.id),
          onTap: () => _onHymnTap(hymn),
          onFavoriteToggled: (isFav) async {
            final localizations = AppLocalizations.of(context);
            if (!mounted) return;
            setState(() {
              if (isFav) {
                _favoriteHymnIds.add(hymn.id);
              } else {
                _favoriteHymnIds.remove(hymn.id);
              }
            });
            try {
              await FavoritesManager.instance.toggleFavoriteById(hymn.id);
            } catch (e) {
              if (mounted) {
                setState(() {
                  if (isFav) {
                    _favoriteHymnIds.remove(hymn.id);
                  } else {
                    _favoriteHymnIds.add(hymn.id);
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(localizations?.favoriteUpdateFailed ?? 'Failed to update favorites')),
                );
              }
            }
          },
        );
      },
    );
  }

  void _startSyncTicker() {
    _syncTicker = Timer.periodic(const Duration(minutes: 5), (_) {
      _loadFavorites();
    });
  }

  Widget _buildContent() {
    return Column(
      children: [
        if (_topUnopenedHymn != null)
          NotificationBanner(
            hymnNumber: _topUnopenedHymn!,
            onOpened: () async {
              await _loadFavorites();
              await _loadHymns();
            },
            onDismissed: () async {
              await _loadFavorites();
              await _loadHymns();
            },
          ),
        Expanded(
            child: _isLoading && _hymns.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _buildHymnList()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return BaseScreen(
      appBar: AppBar(
        centerTitle: false,
        title: Text(localizations?.appTitle ?? 'Christian Hymns', textAlign: TextAlign.start),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _navigateToSearch,
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (_unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 16),
                      child: Text(
                        '${_unreadCount > 99 ? '99+' : _unreadCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () async {
              await NavigationLock.instance.run(() async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationsScreen(
                      hymns: _hymns,
                      unopenedNotifications: _unopenedNotifications.toList(),
                      clearNotifications: () async {
                        try {
                          final ok = await NotificationService()
                              .clearAllNotifications();
                          return ok;
                        } catch (_) {
                          return false;
                        }
                      },
                    ),
                  ),
                );
              });

              if (mounted) await Future.wait([_loadFavorites(), _loadHymns()]);
            },
          ),
        ],
      ),
      child: _isLoading && _hymns.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }
}
