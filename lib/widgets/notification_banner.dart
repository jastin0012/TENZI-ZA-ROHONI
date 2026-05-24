import 'package:flutter/material.dart';
import 'dart:async';
import 'package:tenzi_za_rohoni/services/notification_service.dart';
import 'package:tenzi_za_rohoni/services/hymn_service.dart';
import 'package:tenzi_za_rohoni/screens/hymn_detail_page.dart';
import 'package:tenzi_za_rohoni/models/hymn.dart';
import 'package:tenzi_za_rohoni/services/favorites_manager.dart';
import 'package:tenzi_za_rohoni/utils/text_utils.dart';
import 'package:tenzi_za_rohoni/utils/logger.dart';
// No ad SDK usage in this widget; banners are handled elsewhere.
import '../utils/navigation_lock.dart';

/// A compact, tappable in-app notification banner that shows a single
/// unopened hymn notification (number + title + time) and exposes actions
/// to open the hymn or dismiss the notification.
class NotificationBanner extends StatelessWidget {
  final String hymnNumber;
  final VoidCallback? onOpened;
  final VoidCallback? onDismissed;

  const NotificationBanner({
    super.key,
    required this.hymnNumber,
    this.onOpened,
    this.onDismissed,
  });

  Future<Hymn> _loadHymn() async {
    final svc = HymnService();
    final hymn = await svc.getHymnByNumberString(hymnNumber);
    return hymn ?? Hymn.empty();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Hymn>(
      future: _loadHymn(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }
        final hymn = snap.data ?? Hymn.empty();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                // Mark opened and navigate to hymn detail
                try {
                  await NotificationService().markAsOpened(hymnNumber);
                } catch (_) {}
                if (onOpened != null) onOpened!();

                try {
                  await NavigationLock.instance.run(() async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HymnDetailPage(
                          hymn: hymn,
                          isFavorite:
                              FavoritesManager.instance.isFavorite(hymn.id),
                          onFavoriteToggled: (isFav) async {
                            try {
                              await FavoritesManager.instance
                                  .toggleFavoriteById(hymn.id);
                            } catch (_) {}
                          },
                        ),
                      ),
                    );
                  }, key: hymn.id);
                } catch (e, st) {
                  getLogger('NotificationBanner')
                      .e('Failed to open hymn from notification',
                          error: e, stackTrace: st);
                  if (onDismissed != null) onDismissed!();
                  if (ScaffoldMessenger.maybeOf(context) != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Imeshindikana kufungua tenzi kutoka arifa'),
                      ),
                    );
                  }
                }

                // Do not auto-show interstitials here; they are shown only on
                // explicit leave-from-detail events.
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                        child: Text(hymn.number,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hymn.title.isNotEmpty
                                ? TextUtils.toTitleCase(hymn.title)
                                : 'Tenzi $hymnNumber',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hymn.subtitle.isNotEmpty
                                ? TextUtils.toTitleCase(hymn.subtitle)
                                : (hymn.firstLine.isNotEmpty
                                    ? TextUtils.toTitleCase(hymn.firstLine)
                                    : ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        try {
                          await NotificationService().markAsOpened(hymnNumber);
                        } catch (_) {}
                        if (onDismissed != null) onDismissed!();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
