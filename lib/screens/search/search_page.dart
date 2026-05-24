// Core imports
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// App imports
import 'package:tenzi_za_rohoni/models/hymn.dart';
import 'package:tenzi_za_rohoni/screens/hymn_detail_page.dart';
import 'package:tenzi_za_rohoni/utils/debouncer.dart';
import 'package:tenzi_za_rohoni/utils/recent_manager.dart';
import 'package:tenzi_za_rohoni/widgets/hymn_card.dart';
import 'package:tenzi_za_rohoni/widgets/base_screen.dart';
import 'package:tenzi_za_rohoni/services/ad_service.dart';
import 'package:tenzi_za_rohoni/utils/logger.dart';
import 'package:tenzi_za_rohoni/services/favorites_manager.dart';
import 'package:tenzi_za_rohoni/utils/navigation_lock.dart';

enum SearchOrigin { home, favorites }

class SearchPage extends StatefulWidget {
  final List<Hymn> hymns;
  final SearchOrigin origin;
  final Function(Hymn)? onHymnSelected;

  const SearchPage({
    super.key,
    required this.hymns,
    this.origin = SearchOrigin.home,
    this.onHymnSelected,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late List<Hymn> _filteredHymns;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final bool _isLoading = false;
  final Debouncer _debouncer =
      Debouncer(delay: const Duration(milliseconds: 300));
  final Set<String> _favoriteHymnIds = {};
  StreamSubscription<Set<String>>? _favoritesSub;

  @override
  void initState() {
    super.initState();
    _filteredHymns = <Hymn>[];
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _subscribeToFavorites();

    // Preload interstitial so it's ready when user backs from detail
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        AdService.instance.preloadInterstitial();
      } catch (_) {}
    });
  }

  void _subscribeToFavorites() {
    // Seed current state immediately
    FavoritesManager.instance.getFavorites().then((ids) {
      if (mounted) {
        setState(() {
          _favoriteHymnIds
            ..clear()
            ..addAll(ids);
        });
      }
    });

    // Listen for subsequent updates
    _favoritesSub =
        FavoritesManager.instance.favoritesIdStream.listen((Set<String> ids) {
      if (mounted) {
        setState(() {
          _favoriteHymnIds
            ..clear()
            ..addAll(ids);
        });
      }
    }, onError: (e, st) {
      getLogger('SearchPage')
          .e('Favorites stream error', error: e, stackTrace: st);
    });
  }

  Future<void> _toggleFavorite(Hymn hymn, bool isFavorite) async {
    try {
      await FavoritesManager.instance.toggleFavoriteById(hymn.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFavorite
                ? 'Umeongeza tenzi hii katika Tenzi Pendwa'
                : 'Umeondoa tenzi hii kutoka Tenzi Pendwa'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, st) {
      getLogger('SearchPage')
          .e('Error toggling favorite', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Imeshindikana kuhifadhi kwenye vipendwa')),
        );
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _debouncer.dispose();
    _favoritesSub?.cancel();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onSearchChanged() {
    _debouncer.run(() {
      final query = _searchController.text.trim().toLowerCase();
      if (query.isEmpty) {
        setState(() {
          // When query is empty, do not return the full list. Show empty state.
          _filteredHymns = <Hymn>[];
        });
        return;
      }

      setState(() {
        // Return only related items: match title or number only.
        _filteredHymns = widget.hymns.where((hymn) {
          final title = hymn.title.toLowerCase();
          final number = hymn.number.toLowerCase();
          return title.contains(query) || number.contains(query);
        }).toList();
      });

      _scrollToTop();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      // Load more results if needed
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    _onSearchChanged();
  }

  // removed unused helpers: _sanitize, _dismissKeyboard

  Future<void> _navigateToHymnDetail(Hymn hymn) async {
    if (widget.onHymnSelected != null) {
      widget.onHymnSelected!(hymn);
      return;
    }

    try {
      // Add to recent searches
      await RecentManager.instance.addToRecent(hymn.id);

      if (!mounted) return;

      final result = await NavigationLock.instance.run<bool>(
        () async {
          if (!mounted) return null;
          return await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => HymnDetailPage(
                key: ValueKey('hymn_${hymn.id}'),
                hymn: hymn,
                isFavorite: widget.origin == SearchOrigin.favorites ||
                    _favoriteHymnIds.contains(hymn.id),
                onFavoriteToggled: (isFavorite) {
                  if (!mounted) return;
                  setState(() {
                    if (isFavorite) {
                      _favoriteHymnIds.add(hymn.id);
                    } else {
                      _favoriteHymnIds.remove(hymn.id);
                    }
                  });
                },
              ),
            ),
          );
        },
        key: hymn.id,
      );

      if (result == true && mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imeshindikana kufungua tenzi: $e')),
        );
      }
    }
  }

  // removed unused platform helper

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BaseScreen(
      appBar: AppBar(
        title: const Text('Tafuta Tenzi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [],
      ),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Tafuta kwa jina, namba au mstari wa nyimbo...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  filled: true,
                  // Use surface color so it contrasts on brand yellow
                  fillColor: theme.brightness == Brightness.light
                      ? scheme.surface
                      : scheme.surfaceContainerHighest,
                ),
                onChanged: (_) => _onSearchChanged(),
                textInputAction: TextInputAction.search,
              ),
            ),

            // Search results count
            if (_searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_filteredHymns.length} matokeo yamepatikana',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),

            // Search results list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredHymns.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.isEmpty
                                ? 'Andika kwenye kisanduku cha kutafutia'
                                : 'Hakuna nyimbo zilizopatikana',
                            style: theme.textTheme.bodyLarge,
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _filteredHymns.length,
                          itemBuilder: (context, index) {
                            final hymn = _filteredHymns[index];
                            final isFavorite =
                                _favoriteHymnIds.contains(hymn.id);
                            return HymnCard(
                              key: ValueKey('hymn_${hymn.id}'),
                              hymn: hymn,
                              isFavorite: isFavorite,
                              highlightQuery: _searchController.text.trim(),
                              onTap: () => _navigateToHymnDetail(hymn),
                              onFavoriteToggled: (isFavorite) {
                                _toggleFavorite(hymn, isFavorite);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
