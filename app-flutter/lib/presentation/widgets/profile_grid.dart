import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../controllers/nexus_controller.dart';
import '../theme.dart';
import 'common.dart';
import 'sheets.dart';
import 'states.dart';

/// Media grid for the profile tabs. Shows only real posts; with nothing to show
/// it renders the illustrated empty state instead of fabricated tiles (§3, §4).
class ProfileGrid extends ConsumerWidget {
  const ProfileGrid({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(nexusProvider);
    final name = (s.profile['title'] as String?)?.trim() ?? '';
    final mine = name.isEmpty
        ? const <Post>[]
        : s.posts.where((p) => p.author == name).toList();
    if (mine.isEmpty) {
      return EmptyState(
        icon: Icons.grid_view_rounded,
        title: 'Nothing here yet',
        message: s.profileTab == 'videos'
            ? 'Your videos will appear here once you publish one.'
            : s.profileTab == 'liked'
            ? 'Posts you like are collected here.'
            : 'Save a post to find it here later.',
        ctaLabel: 'Share something',
        onCta: () => openComposer(context, ref),
      );
    }
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 3,
      mainAxisSpacing: 3,
      childAspectRatio: 3 / 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final post in mine)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Photo(),
                DecoratedBox(
                  decoration: BoxDecoration(gradient: DesignTokens.mediaScrim),
                ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Text(
                    post.title.isEmpty ? post.body : post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DesignTokens.meta.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
