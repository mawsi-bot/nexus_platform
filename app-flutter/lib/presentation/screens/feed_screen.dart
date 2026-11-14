import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/nexus_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/notifications.dart';
import '../widgets/post_card.dart';
import '../widgets/states.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(nexusProvider),
        c = ref.read(nexusProvider.notifier),
        posts = ref.watch(rankedPostsProvider);
    return Column(
      children: [
        Container(
          color: context.nx.bgPrimary,
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: BrandMark(size: 26),
              ),
              Expanded(
                child: Segmented(
                  items: const ['For You', 'Nearby'],
                  value: s.filter,
                  onSelect: c.filter,
                ),
              ),
              IconButton(
                tooltip: 'Search',
                onPressed: () => c.go('discover'),
                icon: Icon(Icons.search, color: context.nx.textPrimary),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: context.nx.surface,
                  builder: (_) => const FractionallySizedBox(
                    heightFactor: .92,
                    child: NotificationsPanel(),
                  ),
                ),
                icon: Badge(
                  isLabelVisible: s.notifications.any((n) => n.unread),
                  backgroundColor: context.nx.danger,
                  child: Icon(
                    Icons.notifications_none,
                    color: context.nx.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: s.error != null && posts.isEmpty
              ? ErrorState(error: s.error!, onRetry: c.load)
              : posts.isEmpty && s.busy
              ? ListView(
                  padding: const EdgeInsets.only(top: 4),
                  children: const [
                    SkeletonCard(),
                    SkeletonCard(),
                    SkeletonCard(media: false),
                  ],
                )
              : posts.isEmpty
              ? EmptyState(
                  icon: Icons.dynamic_feed_outlined,
                  title: 'Your feed is quiet',
                  message:
                      'Follow a few people or businesses and their posts will appear here.',
                  ctaLabel: 'Find people to follow',
                  onCta: () => c.go('discover'),
                )
              : RefreshIndicator(
                  color: context.nx.accentBrand,
                  onRefresh: c.load,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // Prefetch one screen ahead so the list never stalls.
                      final metrics = notification.metrics;
                      if (metrics.pixels >= metrics.maxScrollExtent - 400) {
                        c.loadMore();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 2, bottom: 8),
                      itemCount: posts.length + (s.loadingMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= posts.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        return PostCard(post: posts[i]);
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
