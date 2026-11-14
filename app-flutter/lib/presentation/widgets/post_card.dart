import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../controllers/nexus_controller.dart';
import '../theme.dart';
import 'common.dart';
import 'media_carousel.dart';
import 'post_actions.dart';

/// One feed card. Card type is derived from `post.kind` so each production card
/// type (video, feeling/text, location, business promo) has its own hierarchy.
class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post});
  final Post post;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(nexusProvider.notifier);
    final hasMedia = ['video', 'photo', 'loc', 'promo'].contains(post.kind);
    final placeholder = post.media.isEmpty && hasMedia;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: context.nx.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(color: context.nx.border),
        boxShadow: DesignTokens.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(post: post),
            if (post.title.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                post.title,
                style: post.kind == 'feel'
                    ? DesignTokens.meta.copyWith(
                        color: context.nx.accentBrand,
                        letterSpacing: 1.1,
                      )
                    : DesignTokens.itemTitle,
              ),
            ],
            const SizedBox(height: 6),
            _Body(post: post),
            if (post.originalId != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
                decoration: BoxDecoration(
                  color: context.nx.surfaceTint,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
                  border: Border(
                    left: BorderSide(color: context.nx.accentBrand, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Originally by ${post.originalAuthor}',
                      style: DesignTokens.meta.copyWith(
                        color: context.nx.accentBrand,
                      ),
                    ),
                    if (post.originalBody != null) Text(post.originalBody!),
                  ],
                ),
              ),
            ],
            if (post.media.isNotEmpty) ...[
              const SizedBox(height: 12),
              MediaCarousel(
                urls: post.media,
                height: post.kind == 'video' ? 260 : 230,
                onTap: (_) {},
              ),
            ] else if (placeholder) ...[
              const SizedBox(height: 12),
              ScrimmedMedia(
                height: post.kind == 'video' ? 220 : 170,
                child: Stack(
                  children: [
                    if (post.kind == 'video')
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 54,
                          color: Colors.white,
                        ),
                      ),
                    if (post.location.isNotEmpty)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: _GlassPill(
                          icon: Icons.place,
                          label: post.location,
                        ),
                      ),
                    Positioned(
                      right: 10,
                      bottom: 8,
                      child: PostActions(
                        post: post,
                        vertical: true,
                        onMedia: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in post.tags.split(','))
                    if (tag.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: context.nx.surfaceTint,
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radiusPill,
                          ),
                        ),
                        child: Text(
                          '#${tag.trim().replaceAll('#', '')}',
                          style: DesignTokens.meta.copyWith(
                            color: context.nx.textSecondary,
                          ),
                        ),
                      ),
                ],
              ),
            ],
            if (post.music.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.graphic_eq,
                    size: 15,
                    color: context.nx.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      post.music,
                      style: DesignTokens.meta.copyWith(
                        color: context.nx.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (post.kind == 'promo') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => c.go('business'),
                      child: const Text('View shop'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => c.go('business'),
                    child: const Text('Message'),
                  ),
                ],
              ),
            ],
            if (post.kind == 'grpcard') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => c.go('group'),
                      child: const Text('View group'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => c.join(true),
                    child: const Text('Join'),
                  ),
                ],
              ),
            ],
            if (!placeholder) PostActions(post: post),
          ],
        ),
      ),
    );
  }
}

/// Body text with @mentions emphasised.
class _Body extends StatelessWidget {
  const _Body({required this.post});
  final Post post;
  @override
  Widget build(BuildContext context) {
    final style = post.kind == 'feel'
        ? DesignTokens.body.copyWith(fontSize: 17, height: 1.45)
        : DesignTokens.body;
    final matches = RegExp(r'@([A-Za-z0-9_]{2,24})').allMatches(post.body);
    if (matches.isEmpty) return Text(post.body, style: style);
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: post.body.substring(cursor, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(0),
          style: TextStyle(
            color: context.nx.accentBrand,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      cursor = m.end;
    }
    if (cursor < post.body.length) {
      spans.add(TextSpan(text: post.body.substring(cursor)));
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.post});
  final Post post;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Avatar(size: 38),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.author.isEmpty ? 'Nexus member' : post.author,
              style: DesignTokens.itemTitle.copyWith(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              post.subtitle.isEmpty ? post.reason : post.subtitle,
              style: DesignTokens.meta.copyWith(
                color: context.nx.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      if (post.kind != 'video' && post.location.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: context.nx.surfaceTint,
            borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
          ),
          child: Row(
            children: [
              Icon(Icons.place, size: 12, color: context.nx.accentBrand),
              const SizedBox(width: 4),
              Text(
                post.location,
                style: DesignTokens.meta.copyWith(
                  color: context.nx.textSecondary,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0x8C111827),
      borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: DesignTokens.meta.copyWith(color: Colors.white)),
      ],
    ),
  );
}
