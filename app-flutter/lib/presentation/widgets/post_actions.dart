import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../controllers/nexus_controller.dart';
import '../theme.dart';
import 'comments_sheet.dart';
import 'inline_comments.dart';
import 'reactions.dart';
import 'share_sheet.dart';
import 'sheets.dart';

/// One flat action row (§1.1): react · comment · share · save · more.
///
/// Over media it falls back to the floating vertical rail, where the comment
/// button opens the sheet instead of an inline field.
class PostActions extends ConsumerStatefulWidget {
  const PostActions({
    super.key,
    required this.post,
    this.vertical = false,
    this.onMedia = false,
  });
  final Post post;
  final bool vertical;
  final bool onMedia;
  @override
  ConsumerState<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends ConsumerState<PostActions> {
  bool _inline = false;

  Future<void> _react() async {
    final c = ref.read(nexusProvider.notifier);
    final choice = await showReactionPicker(
      context,
      current: widget.post.myReaction,
    );
    if (choice == null) return;
    await c.react(widget.post, choice);
    if (!mounted) return;
    final error = ref.read(nexusProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _comment() {
    if (widget.vertical || widget.onMedia) {
      ref.read(nexusProvider.notifier).comments(widget.post);
      openSheet(context, CommentsSheet(post: widget.post));
      return;
    }
    setState(() => _inline = !_inline);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final c = ref.read(nexusProvider.notifier);
    final mine = post.myReaction;
    if (widget.vertical || widget.onMedia) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final child in [
            _Rail(
              icon: mine.isEmpty ? Icons.favorite_border : Icons.favorite,
              label: '${post.likes}',
              active: post.liked,
              onTap: _react,
            ),
            _Rail(
              icon: Icons.chat_bubble_outline,
              label: '${post.comments}',
              onTap: _comment,
            ),
            _Rail(
              icon: Icons.ios_share,
              label: 'Share',
              onTap: () => openSheet(context, ShareSheet(post: post)),
            ),
            _Rail(
              icon: post.saved ? Icons.bookmark : Icons.bookmark_border,
              label: 'Save',
              active: post.saved,
              onTap: () => c.save(post),
            ),
          ])
            Padding(padding: const EdgeInsets.only(bottom: 10), child: child),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReactionSummaryBar(
          counts: post.reactions,
          onTap: () => showWhoReacted(
            context,
            counts: post.reactions,
            load: () => ref.read(nexusProvider.notifier).reactors(post),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: _Flat(
                  icon: post.liked
                      ? (mine.isEmpty ? Icons.favorite : Icons.favorite)
                      : Icons.favorite_border,
                  label: '${post.likes}',
                  active: post.liked,
                  emoji: mine.isEmpty ? null : reactionEmoji(mine),
                  onTap: _react,
                  onLongPress: _react,
                ),
              ),
              Expanded(
                child: _Flat(
                  icon: Icons.chat_bubble_outline,
                  label: '${post.comments}',
                  active: _inline,
                  onTap: _comment,
                ),
              ),
              Expanded(
                child: _Flat(
                  icon: Icons.ios_share,
                  label: '${post.shares}',
                  onTap: () => openSheet(context, ShareSheet(post: post)),
                ),
              ),
              Expanded(
                child: _Flat(
                  icon: post.saved ? Icons.bookmark : Icons.bookmark_border,
                  label: 'Save',
                  active: post.saved,
                  onTap: () => c.save(post),
                ),
              ),
              _More(post: post),
            ],
          ),
        ),
        if (_inline) InlineComments(post: post),
      ],
    );
  }
}

class _Flat extends StatelessWidget {
  const _Flat({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
    this.onLongPress,
    this.emoji,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? emoji;
  @override
  Widget build(BuildContext context) {
    final color = active ? context.nx.accentBrand : context.nx.textSecondary;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (emoji != null)
              Text(emoji!, style: const TextStyle(fontSize: 15))
            else
              Icon(icon, size: 19, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: DesignTokens.meta.copyWith(
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Material(
        color: context.nx.surface,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.nx.surface,
              boxShadow: DesignTokens.railShadow,
            ),
            child: Icon(
              icon,
              size: 20,
              color: active ? context.nx.danger : context.nx.textPrimary,
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          label,
          style: DesignTokens.meta.copyWith(color: Colors.white),
        ),
      ),
    ],
  );
}

class _More extends ConsumerWidget {
  const _More({required this.post});
  final Post post;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(nexusProvider.notifier);
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: Icon(Icons.more_horiz, size: 19, color: context.nx.textSecondary),
      onSelected: (value) async {
        if (value == 'hide') {
          await c.hide(post);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post hidden from your feed')),
          );
        } else if (value == 'report') {
          await c.report(post);
          if (!context.mounted) return;
          final error = ref.read(nexusProvider).error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error ?? 'Reported. Our team reviews it within 24 hours.',
              ),
            ),
          );
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'report', child: Text('Report post')),
        PopupMenuItem(value: 'hide', child: Text('Hide post')),
      ],
    );
  }
}
