import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tenzi_za_rohoni/utils/logger.dart';

import 'package:tenzi_za_rohoni/screens/hymn_detail_page.dart';
import 'package:tenzi_za_rohoni/models/hymn.dart';
import 'package:tenzi_za_rohoni/services/favorites_manager.dart';
import 'package:tenzi_za_rohoni/theme/colors.dart';
import 'package:tenzi_za_rohoni/utils/text_utils.dart';
import '../utils/navigation_lock.dart';
import 'package:tenzi_za_rohoni/gen/l10n/app_localizations.dart';

class HymnCard extends StatefulWidget {
  const HymnCard({
    super.key,
    required this.hymn,
    this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggled,
    this.highlightQuery,
  });

  final Hymn hymn;
  final VoidCallback? onTap;
  final bool isFavorite;
  final Function(bool)? onFavoriteToggled;
  final String? highlightQuery;

  @override
  State<HymnCard> createState() => _HymnCardState();
}

class _HymnCardState extends State<HymnCard> {
  bool _tapLocked = false;

  Future<void> _handleFavoriteTap() async {
    final localizations = AppLocalizations.of(context);
    final bool currently = FavoritesManager.instance.isFavorite(widget.hymn.id);
    final bool newState = !currently;

    if (widget.onFavoriteToggled != null) {
      try {
        widget.onFavoriteToggled!.call(newState);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(newState
                ? (localizations?.addedToFavorites ?? 'Added to favorites')
                : (localizations?.removedFromFavorites ?? 'Removed from favorites')),
            duration: const Duration(seconds: 2),
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations?.favoriteUpdateFailed ?? 'Failed to update favorites')),
          );
        }
      }
      return;
    }

    try {
      if (currently) {
        await FavoritesManager.instance.removeFromFavorites(widget.hymn.id);
      } else {
        await FavoritesManager.instance.addToFavorite(widget.hymn);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(!currently
              ? (localizations?.addedToFavorites ?? 'Added to favorites')
              : (localizations?.removedFromFavorites ?? 'Removed from favorites')),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations?.favoriteUpdateFailed ?? 'Failed to update favorites')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final localizations = AppLocalizations.of(context);
    
    final String? highlightQuery =
        widget.highlightQuery != null && widget.highlightQuery!.isNotEmpty
            ? widget.highlightQuery!.trim()
            : null;
    final String secondaryLine = widget.hymn.subtitle.isNotEmpty
        ? widget.hymn.subtitle
        : widget.hymn.firstLine;

    final String displayTitle = TextUtils.toTitleCase(widget.hymn.title);
    final String displaySecondaryLine = TextUtils.toTitleCase(secondaryLine);

    final bool isNumericQuery =
        highlightQuery != null && RegExp(r'^\d+$').hasMatch(highlightQuery);
    final bool titleContainsQuery = highlightQuery != null
        ? widget.hymn.title.toLowerCase().contains(highlightQuery.toLowerCase())
        : false;
    final bool highlightTitleOnly =
        highlightQuery != null && (isNumericQuery || titleContainsQuery);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      child: InkWell(
        onTap: widget.onTap ??
            () async {
              if (_tapLocked) return;
              setState(() => _tapLocked = true);
              try {
                try {
                  await NavigationLock.instance.run(() async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HymnDetailPage(
                          hymn: widget.hymn,
                          isFavorite: FavoritesManager.instance
                              .isFavorite(widget.hymn.id),
                          onFavoriteToggled: (isFavorite) {
                            widget.onFavoriteToggled?.call(isFavorite);
                            setState(() {});
                          },
                        ),
                      ),
                    );
                  }, key: widget.hymn.id);
                } catch (e, st) {
                  getLogger('HymnCard').e(
                    'Failed to open hymn detail',
                    error: e,
                    stackTrace: st,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(localizations?.hymnOpenFailed ?? 'Failed to open hymn. Try again.'),
                      ),
                    );
                  }
                }
              } finally {
                await Future.delayed(const Duration(milliseconds: 350));
                if (mounted) setState(() => _tapLocked = false);
              }
            },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${widget.hymn.songNumber}',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFE1E1E1)
                        : Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (highlightQuery != null)
                      RichText(
                        text: _buildHighlightedText(
                          displayTitle,
                          highlightQuery,
                          textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold) ??
                              const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        displayTitle,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    if (secondaryLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      if (highlightQuery != null && !highlightTitleOnly)
                        RichText(
                          text: _buildHighlightedText(
                            displaySecondaryLine,
                            highlightQuery,
                            textTheme.bodyMedium
                                    ?.copyWith(color: theme.hintColor) ??
                                TextStyle(color: theme.hintColor),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          displaySecondaryLine,
                          style: textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ],
                ),
              ),
              if (_tapLocked)
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                )
              else
                StreamBuilder<Set<String>>(
                  stream: FavoritesManager.instance.favoritesIdStream,
                  initialData: {if (widget.isFavorite) widget.hymn.id},
                  builder: (context, snapshot) {
                    final ids = snapshot.data ?? <String>{};
                    final isFav = ids.contains(widget.hymn.id);
                    return SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? AppColors.primary : null,
                        ),
                        onPressed: _handleFavoriteTap,
                        padding: const EdgeInsets.all(8.0),
                        constraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                        tooltip:
                            isFav ? 'Ondoa kutoka vipendwa' : 'Ongeza vipendwa',
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _buildHighlightedText(String text, String query, TextStyle style) {
    if (query.isEmpty) return TextSpan(text: text, style: style);
    final lcText = text.toLowerCase();
    final lcQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    int idx = lcText.indexOf(lcQuery, start);
    while (idx >= 0) {
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: style));
      }
      spans.add(TextSpan(
          text: text.substring(idx, idx + lcQuery.length),
          style: style.copyWith(
              backgroundColor: Colors.yellow.withOpacity(0.6))));
      start = idx + lcQuery.length;
      idx = lcText.indexOf(lcQuery, start);
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }
    return TextSpan(children: spans, style: style);
  }
}
