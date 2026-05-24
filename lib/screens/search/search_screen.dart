import 'package:flutter/material.dart';
import 'package:tenzi_za_rohoni/models/hymn.dart';
import 'package:tenzi_za_rohoni/screens/hymn_detail_page.dart';
import 'package:tenzi_za_rohoni/services/favorites_manager.dart';
import 'package:tenzi_za_rohoni/services/hymn_service.dart';
import 'package:tenzi_za_rohoni/utils/debouncer.dart';
import 'package:tenzi_za_rohoni/utils/logger.dart';
import 'package:tenzi_za_rohoni/utils/recent_manager.dart';
import 'package:tenzi_za_rohoni/widgets/hymn_card.dart';
import 'package:tenzi_za_rohoni/utils/navigation_lock.dart';
import 'package:tenzi_za_rohoni/widgets/base_screen.dart';
import 'package:tenzi_za_rohoni/services/ad_service.dart';
import 'package:tenzi_za_rohoni/gen/l10n/app_localizations.dart';

class SearchScreen extends StatefulWidget {
  final List<Hymn>? initialHymns;
  final String? title;

  const SearchScreen({super.key, this.initialHymns, this.title});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 300));
  
  List<Hymn> _allHymns = [];
  List<Hymn> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingHymns = false;
  bool _hasError = false;
  Set<String> _favoriteHymnIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadFavorites();
    
    if (widget.initialHymns != null) {
      _allHymns = widget.initialHymns!;
      _searchResults = []; 
    } else {
      _loadAllHymns();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService.instance.preloadInterstitial();
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await FavoritesManager.instance.getFavorites();
      if (mounted) {
        setState(() {
          _favoriteHymnIds = favorites.toSet();
        });
      }
    } catch (e, st) {
      getLogger('SearchScreen').e('Error loading favorites', error: e, stackTrace: st);
    }
  }

  Future<void> _loadAllHymns() async {
    if (_isLoadingHymns) return;
    setState(() {
      _isLoadingHymns = true;
      _hasError = false;
    });
    try {
      final hymns = await HymnService.instance.getAllHymns();
      if (!mounted) return;
      setState(() {
        _allHymns = hymns;
        _searchResults = [];
      });
    } catch (e, st) {
      getLogger('SearchScreen').e('Error loading hymns in search', error: e, stackTrace: st);
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoadingHymns = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debouncer.run(() {
      final lower = query.toLowerCase();
      final results = _allHymns.where((h) {
        return h.title.toLowerCase().contains(lower) ||
            h.number.toLowerCase().contains(lower);
      }).toList();

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _onHymnTap(Hymn hymn) async {
    await RecentManager.instance.addToRecent(hymn.id);
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);

    try {
      await NavigationLock.instance.run(() async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HymnDetailPage(
              hymn: hymn,
              isFavorite: FavoritesManager.instance.isFavorite(hymn.id),
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
                  getLogger('SearchScreen').e('Failed to toggle favorite', error: e, stackTrace: st);
                }
              },
            ),
          ),
        );
      }, key: hymn.id);
    } catch (e, st) {
      getLogger('SearchScreen').e('Failed to open hymn', error: e, stackTrace: st);
    }
    await _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final localizations = AppLocalizations.of(context);

    return BaseScreen(
      appBar: AppBar(
        title: Text(widget.title ?? localizations?.appTitle ?? 'Tafuta'),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              decoration: InputDecoration(
                hintText: localizations?.searchHint ?? 'Search...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchFocusNode.requestFocus();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final localizations = AppLocalizations.of(context);
    
    if (_isLoadingHymns || _isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(localizations?.searchError ?? 'Error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAllHymns, child: Text(localizations?.retry ?? 'Retry')),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? (localizations?.searchHint ?? 'Search...')
              : (localizations?.noHymnsFound ?? 'No hymns found'),
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final hymn = _searchResults[index];
        return HymnCard(
          hymn: hymn,
          isFavorite: _favoriteHymnIds.contains(hymn.id),
          highlightQuery: _searchController.text.trim(),
          onTap: () => _onHymnTap(hymn),
        );
      },
    );
  }
}
