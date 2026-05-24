import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart' as share_plus;

import 'package:tenzi_za_rohoni/models/hymn.dart';
import 'package:tenzi_za_rohoni/services/favorites_manager.dart';
import 'package:tenzi_za_rohoni/services/ad_service.dart';
import 'package:tenzi_za_rohoni/utils/logger.dart';
import 'package:tenzi_za_rohoni/utils/text_utils.dart';
import 'package:tenzi_za_rohoni/utils/recent_manager.dart';
import 'package:tenzi_za_rohoni/theme/colors.dart';
import 'package:tenzi_za_rohoni/gen/l10n/app_localizations.dart';

final logger = getLogger('HymnDetailPage');

class HymnDetailPage extends StatefulWidget {
  final Hymn hymn;
  final bool isFavorite;
  final ValueChanged<bool>? onFavoriteToggled;

  const HymnDetailPage({
    super.key,
    required this.hymn,
    this.isFavorite = false,
    this.onFavoriteToggled,
  });

  @override
  State<HymnDetailPage> createState() => _HymnDetailPageState();
}

class _HymnDetailPageState extends State<HymnDetailPage> {
  static final Set<String> _openHymnIds = <String>{};
  bool _isDuplicateInstance = false;

  late double _fontSize;
  late bool _isFavorite;
  bool _showAudioPlayer = false;
  bool _isFullScreen = false;
  bool _isToggling = false;

  static const double minFontSize = 12.0;
  static const double maxFontSize = 32.0;
  static const double fontSizeStep = 2.0;

  late final FavoritesManager _favoritesManager;
  late final RecentManager _recentManager;
  StreamSubscription? _favoritesSubscription;

  @override
  void initState() {
    super.initState();

    if (_openHymnIds.contains(widget.hymn.id)) {
      _isDuplicateInstance = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return;
    }

    _openHymnIds.add(widget.hymn.id);

    _fontSize = 18.0;
    _isFavorite = widget.isFavorite;
    _favoritesManager = GetIt.I<FavoritesManager>();
    _recentManager = GetIt.I<RecentManager>();
    _setupFavoritesListener();
    _loadFavoriteStatus();
    _addToRecents();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService.instance.preloadInterstitial();
    });
  }

  Future<void> _loadFavoriteStatus() async {
    final localizations = AppLocalizations.of(context);
    try {
      final isFavorite = _favoritesManager.isFavorite(widget.hymn.id);
      if (!mounted) return;

      setState(() {
        _isFavorite = isFavorite;
      });
    } catch (e, stackTrace) {
      logger.e('Error loading favorite status',
          error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(localizations?.favoriteLoadFailed ??
                  'Failed to load favorite status')),
        );
      }
    }
  }

  Future<void> _addToRecents() async {
    try {
      await _recentManager.addToRecent(widget.hymn.id);
    } catch (e, stackTrace) {
      logger.e('Error adding hymn to recents',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _copyHymn() async {
    final localizations = AppLocalizations.of(context);
    try {
      final title = TextUtils.toTitleCase(widget.hymn.title);
      final songNumber = widget.hymn.number;
      final content = _buildLyricsText();

      if (content.isEmpty) {
        _showErrorSnackbar(localizations?.hymnCopyNoText ?? 'No text to copy');
        return;
      }

      const attribution = '— Chanzo: RohoniFlow';
      await Clipboard.setData(
        ClipboardData(
          text: '$title (Tenzi $songNumber)\n\n$content\n$attribution',
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(localizations?.hymnCopied ?? 'Hymn copied to clipboard'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar(localizations?.hymnCopyFailed(e.toString()) ??
            'Failed to copy hymn');
      }
    }
  }

  Future<void> _toggleFullScreen() async {
    final next = !_isFullScreen;
    if (next) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (!mounted) return;
    setState(() => _isFullScreen = next);
  }

  PreferredSizeWidget _buildAppBar() {
    final localizations = AppLocalizations.of(context);
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      title: const SizedBox.shrink(),
      actions: [
        IconButton(
          icon: Icon(_showAudioPlayer ? Icons.music_off : Icons.music_note),
          onPressed: () => setState(() => _showAudioPlayer = !_showAudioPlayer),
          tooltip: _showAudioPlayer
              ? localizations?.hideAudio
              : localizations?.showAudio,
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: _shareHymn,
          tooltip: localizations?.shareHymn,
        ),
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: _copyHymn,
          tooltip: localizations?.copyHymn,
        ),
        IconButton(
          icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
          onPressed: _toggleFullScreen,
          tooltip: localizations?.toggleFullScreen,
        ),
      ],
    );
  }

  Widget _buildFontSizeSlider() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          const Icon(Icons.text_fields, size: 20),
          Expanded(
            child: Slider(
              value: _fontSize,
              min: minFontSize,
              max: maxFontSize,
              divisions: ((maxFontSize - minFontSize) / fontSizeStep).toInt(),
              label: '${_fontSize.toInt()}',
              onChanged: (value) {
                setState(() => _fontSize = value);
              },
            ),
          ),
          Text('${_fontSize.toInt()}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final localizations = AppLocalizations.of(context);
    if (!mounted || _isToggling) return;

    setState(() => _isToggling = true);
    final previous = _isFavorite;
    setState(() => _isFavorite = !_isFavorite);

    try {
      if (widget.onFavoriteToggled != null) {
        widget.onFavoriteToggled!.call(_isFavorite);
      } else {
        await _favoritesManager.toggleFavorite(widget.hymn);
      }
    } catch (e, st) {
      logger.e('Error toggling favorite', error: e, stackTrace: st);
      if (mounted) {
        setState(() => _isFavorite = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(localizations?.favoriteUpdateFailed ??
                  'Failed to update favorites')),
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  Future<void> _shareHymn() async {
    final localizations = AppLocalizations.of(context);
    try {
      final title = TextUtils.toTitleCase(widget.hymn.title);
      final songNumber = widget.hymn.number;
      final content = _buildLyricsText();
      if (content.isEmpty) {
        _showErrorSnackbar(
            localizations?.hymnShareNoText ?? 'No text to share');
        return;
      }

      final text = '$title (Tenzi $songNumber)\n\n$content\n\n— RohoniFlow';
      share_plus.Share.share(text);
    } catch (e) {
      logger.e('Error sharing hymn', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  localizations?.hymnShareFailed ?? 'Failed to share hymn')),
        );
      }
    }
  }

  String _buildLyricsText() {
    final hymn = widget.hymn;
    final buffer = StringBuffer();

    for (var i = 0; i < hymn.stanzas.length; i++) {
      final stanza = hymn.stanzas[i];
      if (stanza.isEmpty) continue;

      buffer.writeln('${i + 1}. ${stanza.join('\n')}');
      buffer.writeln();

      if (i == 0 && hymn.chorus != null && hymn.chorus!.isNotEmpty) {
        buffer.writeln('Chorus:\n${hymn.chorus!.join('\n')}');
        buffer.writeln();
      }
    }

    if (hymn.stanzas.isEmpty && hymn.chorus != null) {
      buffer.writeln(hymn.chorus!.join('\n'));
    }

    return buffer.toString().trim();
  }

  Widget _buildHeaderBlock() {
    final hymn = widget.hymn;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tenzi No. ${hymn.number}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              IconButton(
                icon: _isToggling
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? AppColors.primary : null),
                onPressed: _toggleFavorite,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            TextUtils.toTitleCase(hymn.title),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          if (hymn.subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              TextUtils.toTitleCase(hymn.subtitle),
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildLyricsWidgets() {
    final localizations = AppLocalizations.of(context);
    final hymn = widget.hymn;
    final widgets = <Widget>[];

    if (hymn.stanzas.isEmpty && (hymn.chorus == null || hymn.chorus!.isEmpty)) {
      return [
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(localizations?.noLyrics ?? 'No lyrics available.',
              textAlign: TextAlign.center),
        ),
      ];
    }

    for (var i = 0; i < hymn.stanzas.length; i++) {
      widgets.add(
        _buildStanza(i + 1, hymn.stanzas[i]),
      );

      if (i == 0 && hymn.chorus != null) {
        widgets.add(_buildChorus(hymn.chorus!));
      }
    }

    if (hymn.stanzas.isEmpty && hymn.chorus != null) {
      widgets.add(_buildChorus(hymn.chorus!));
    }

    return widgets;
  }

  Widget _buildStanza(int number, List<String> lines) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$number. ',
                  style: TextStyle(
                      fontSize: _fontSize, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  lines.join('\n'),
                  style: TextStyle(fontSize: _fontSize, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 20), // Balance the number on the left
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChorus(List<String> lines) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            lines.join('\n'),
            style: TextStyle(
              fontSize: _fontSize,
              height: 1.4,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    if (!_isDuplicateInstance) _openHymnIds.remove(widget.hymn.id);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _setupFavoritesListener() {
    _favoritesSubscription = _favoritesManager.favoritesStream.listen((hymns) {
      if (mounted) {
        setState(() => _isFavorite = hymns.any((h) => h.id == widget.hymn.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) {
          AdService.instance.showInterstitialAndAwaitDismiss();
        }
      },
      child: Scaffold(
        appBar: _isFullScreen ? null : _buildAppBar(),
        body: Column(
          children: [
            if (!_isFullScreen) ...[
              _buildHeaderBlock(),
              _buildFontSizeSlider(),
            ],
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(children: _buildLyricsWidgets()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
