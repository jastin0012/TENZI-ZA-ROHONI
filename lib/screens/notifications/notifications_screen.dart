import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// google_mobile_ads not needed here; banners are global
// ad_service not required in this file; banner widgets handle loading

import 'package:tenzi_za_rohoni/services/notification_service.dart';
import 'package:tenzi_za_rohoni/utils/recent_manager.dart';
import 'package:tenzi_za_rohoni/utils/logger.dart';
import 'package:tenzi_za_rohoni/utils/text_utils.dart';
import 'package:tenzi_za_rohoni/widgets/base_screen.dart';
// Banner handled globally in MainLayout
import 'package:tenzi_za_rohoni/screens/hymn_detail_page.dart';
import 'package:tenzi_za_rohoni/models/hymn.dart';
import 'package:tenzi_za_rohoni/services/favorites_manager.dart';
import '../../theme/colors.dart';
import '../../utils/navigation_lock.dart';

class NotificationsScreen extends StatefulWidget {
  final List<Hymn> hymns;
  final List<String> unopenedNotifications;
  final Future<bool> Function() clearNotifications;

  const NotificationsScreen({
    super.key,
    required this.hymns,
    required this.unopenedNotifications,
    required this.clearNotifications,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Map<String, int> _times = {};
  final Set<String> _read = {};
  final Set<String> _unopenedSet = {};
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _ticker;
  List<String> _allNotifications = [];

  @override
  void initState() {
    super.initState();
    _initData();
    _startTicker();
  }

  Future<void> _initData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _loadTimes();
      if (!mounted) return;
      await _refreshAllNotifications();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Imeshindikana kupakua arifa';
      });
    }
  }

  Future<void> _loadTimes() async {
    final prefs = await SharedPreferences.getInstance();
    _times
      ..clear()
      ..addAll(_parseUnopenedTimes(prefs));

    final readList = prefs.getStringList('read_notifications') ?? <String>[];
    _read.clear();
    _read.addAll(readList);
  }

  Future<void> _refreshAllNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unopened =
          prefs.getStringList('unopened_notifications') ?? <String>[];
      final read = prefs.getStringList('read_notifications') ?? <String>[];

      // Keep unopened first (new ones), then append read items (avoid duplicates)
      final combined = <String>[];
      for (final n in unopened) {
        if (!combined.contains(n)) combined.add(n);
      }
      for (final r in read) {
        if (!combined.contains(r)) combined.add(r);
      }

      // update local unopened set for fast checks in build
      _unopenedSet
        ..clear()
        ..addAll(unopened);

      if (mounted) {
        setState(() {
          _allNotifications = combined;
        });
      }
    } catch (_) {}
  }

  Map<String, int> _parseUnopenedTimes(SharedPreferences prefs) {
    final raw = prefs.getString('unopened_times');
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final result = <String, int>{};
      for (final entry in raw.split(';')) {
        if (entry.isEmpty) continue;
        final parts = entry.split('=');
        if (parts.length == 2) {
          final v = int.tryParse(parts[1]);
          if (v != null) result[parts[0]] = v;
        }
      }
      return result;
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> _saveUnopenedTimes(
      SharedPreferences prefs, Map<String, int> map) async {
    final entries = map.entries.map((e) => '${e.key}=${e.value}').join(';');
    await prefs.setString('unopened_times', entries);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatTimeAgo(String hymnNumber) {
    final ts = _times[hymnNumber];
    if (ts == null || ts == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika zilizopita';
    if (diff.inHours < 24) return '${diff.inHours} saa zilizopita';
    return '${diff.inDays} siku zilizopita';
  }

  Future<void> _markAsSeen(String hymnNumber) async {
    if (hymnNumber.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      // Mark as opened (moves from unopened -> read and updates badge)
      await NotificationService().markAsOpened(hymnNumber);
      // Refresh combined list so the item remains visible (now as read)
      await _refreshAllNotifications();
      // Also refresh read set and times
      final prefs = await SharedPreferences.getInstance();
      final readList = prefs.getStringList('read_notifications') ?? <String>[];
      _read
        ..clear()
        ..addAll(readList);
      final times = _parseUnopenedTimes(await SharedPreferences.getInstance());
      _times
        ..clear()
        ..addAll(times);
      await NotificationService().updateBadgeCount();
    } catch (e, st) {
      getLogger('NotificationsScreen')
          .e('Error marking as seen', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFromList(String hymnNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _times.remove(hymnNumber);
      // Remove from both unopened and read lists
      final unopened =
          prefs.getStringList('unopened_notifications') ?? <String>[];
      if (unopened.contains(hymnNumber)) {
        unopened.remove(hymnNumber);
        await prefs.setStringList('unopened_notifications', unopened);
      }
      final read = prefs.getStringList('read_notifications') ?? <String>[];
      if (read.contains(hymnNumber)) {
        read.remove(hymnNumber);
        await prefs.setStringList('read_notifications', read);
      }

      // update times storage
      await _saveUnopenedTimes(prefs, _parseUnopenedTimes(prefs));
      // refresh combined list and state
      await _refreshAllNotifications();
      final readList = prefs.getStringList('read_notifications') ?? <String>[];
      _read
        ..clear()
        ..addAll(readList);
      await NotificationService().updateBadgeCount();
      if (mounted) setState(() {});
    } catch (e, st) {
      getLogger('NotificationsScreen')
          .e('Error deleting notification', error: e, stackTrace: st);
    }
  }

  Future<void> _markAllAsRead() async {
    final should = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Soma Zote'),
            content: const Text('Una uhakika unataka kusoma arifa zote?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Ghairi')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Soma Zote')),
            ],
          ),
        ) ??
        false;

    if (!should) return;
    setState(() => _isLoading = true);
    try {
      final service = NotificationService();
      // Clear persisted notifications first (authoritative)
      final cleared = await service.clearAllNotifications();
      // Also allow caller to react (best-effort)
      await widget.clearNotifications();

      if (cleared) {
        _times.clear();
        _read.clear();
        _unopenedSet.clear();
        _allNotifications = <String>[];
        await _refreshAllNotifications();
      }
    } catch (e, st) {
      getLogger('NotificationsScreen')
          .e('Error marking all as read', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return BaseScreen(
        appBar: AppBar(title: const Text('Arifa')),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return BaseScreen(
        appBar: AppBar(title: const Text('Arifa')),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Hitilafu imetokea', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(_errorMessage!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: _initData, child: const Text('Jaribu tena')),
              ],
            ),
          ),
        ),
      );
    }

    final keys = _allNotifications;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        elevation: 0,
        foregroundColor: isDark ? AppColors.darkText : Colors.black87,
        title: const Text('Arifa'),
        actions: [
          if (keys.isNotEmpty)
            TextButton(
                onPressed: _markAllAsRead, child: const Text('Futa zote')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: keys.isEmpty
                ? Center(
                    child: Text('Hakuna arifa za tenzi',
                        style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : Colors.black.withAlpha(180),
                            fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: keys.length,
                    itemBuilder: (context, index) {
                      final hymnNumber = keys[index];
                      final hymnModel = widget.hymns.firstWhere(
                        (h) => h.number == hymnNumber,
                        orElse: () => Hymn.empty(),
                      );
                      final timeAgo = _formatTimeAgo(hymnNumber);
                      final isRead = _read.contains(hymnNumber);
                      final isUnread = _unopenedSet.contains(hymnNumber);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Dismissible(
                          key: ValueKey('notif-$hymnNumber'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(16)),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (dir) async {
                            await _deleteFromList(hymnNumber);
                            return true;
                          },
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                await _markAsSeen(hymnNumber);
                                await RecentManager.instance
                                    .addToRecent(hymnNumber);
                                if (!context.mounted) return;
                                await NavigationLock.instance.run(() async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => HymnDetailPage(
                                        hymn: hymnModel,
                                        isFavorite: FavoritesManager.instance
                                            .isFavorite(hymnModel.id),
                                        onFavoriteToggled: (isFav) async {
                                          try {
                                            await FavoritesManager.instance
                                                .toggleFavoriteById(
                                                    hymnModel.id);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content: Text(isFav
                                                    ? 'Umeongeza tenzi hii katika Tenzi Pendwa'
                                                    : 'Umeondoa tenzi hii kutoka Tenzi Pendwa'),
                                                duration:
                                                    const Duration(seconds: 2),
                                              ));
                                            }
                                          } catch (e, st) {
                                            getLogger('NotificationsScreen').e(
                                              'Failed to toggle favorite from NotificationsScreen',
                                              error: e,
                                              stackTrace: st,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                }, key: hymnModel.id);

                                // Interstitials are not shown on navigation here.
                                // They are shown only when the user exits the detail
                                // page by pressing back (handled inside HymnDetailPage).
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? theme
                                          .colorScheme.surfaceContainerHighest
                                      : AppColors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                child: Row(
                                  children: [
                                    // Left circular number badge (match HymnCard)
                                    Container(
                                      width: 48,
                                      height: 48,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${hymnModel.songNumber}',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? AppColors.darkText
                                                    : Colors.black),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Title
                                          Text(
                                            TextUtils.toTitleCase(
                                                hymnModel.title),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontWeight: isUnread
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                                fontSize: 16),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  TextUtils.toTitleCase(
                                                      hymnModel.subtitle
                                                              .isNotEmpty
                                                          ? hymnModel.subtitle
                                                          : hymnModel
                                                              .firstLine),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      color: isDark
                                                          ? (isRead
                                                              ? AppColors
                                                                  .darkTextSecondary
                                                              : AppColors
                                                                  .darkText)
                                                          : (isRead
                                                              ? Colors.black45
                                                              : Colors
                                                                  .black87)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(timeAgo,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isDark
                                                          ? AppColors
                                                              .darkTextSecondary
                                                          : Colors.black54))
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value == 'open') {
                                          await _markAsSeen(hymnNumber);
                                          await RecentManager.instance
                                              .addToRecent(hymnNumber);
                                          if (!context.mounted) return;
                                          await NavigationLock.instance.run(
                                              () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    HymnDetailPage(
                                                        hymn: hymnModel),
                                              ),
                                            );
                                          }, key: hymnModel.id);
                                        } else if (value == 'delete') {
                                          await _deleteFromList(hymnNumber);
                                        }
                                      },
                                      itemBuilder: (ctx) => const [
                                        PopupMenuItem(
                                            value: 'open',
                                            child: Text('Fungua')),
                                        PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Futa')),
                                      ],
                                      icon: const Icon(Icons.more_vert),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Banner handled globally in MainLayout; removed per-screen banner.
        ],
      ),
    );
  }
}
