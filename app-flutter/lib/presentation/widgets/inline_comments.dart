import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../controllers/nexus_controller.dart';
import '../theme.dart';
import 'mention.dart';

/// Comment thread rendered inside the card itself — no sheet, no navigation
/// (§3.2). Opening it fetches once, then each send appends optimistically.
class InlineComments extends ConsumerStatefulWidget {
  const InlineComments({super.key, required this.post, this.maxVisible = 3});
  final Post post;
  final int maxVisible;
  @override
  ConsumerState<InlineComments> createState() => _InlineCommentsState();
}

class _InlineCommentsState extends ConsumerState<InlineComments> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(nexusProvider.notifier).comments(widget.post),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(nexusProvider);
    final c = ref.read(nexusProvider.notifier);
    final all = s.comments[widget.post.id] ?? const <Entry>[];
    final visible = all.take(widget.maxVisible).toList();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: context.nx.surfaceTint,
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'No comments yet — start the conversation.',
                style: DesignTokens.meta.copyWith(
                  color: context.nx.textSecondary,
                ),
              ),
            ),
          for (final entry in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: context.nx.surface,
                    child: Text(
                      entry.title.isEmpty ? '?' : entry.title[0].toUpperCase(),
                      style: DesignTokens.meta.copyWith(
                        color: context.nx.accentBrand,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: DesignTokens.meta.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.nx.textPrimary,
                          ),
                        ),
                        Text(entry.body, style: DesignTokens.body),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: entry.selected ? 'Unlike comment' : 'Like comment',
                    onPressed: () => c.likeComment(widget.post, entry),
                    icon: Icon(
                      entry.selected
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 15,
                      color: entry.selected
                          ? context.nx.danger
                          : context.nx.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          if (all.length > widget.maxVisible)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'and ${all.length - widget.maxVisible} more',
                style: DesignTokens.meta.copyWith(
                  color: context.nx.textSecondary,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: MentionInput(
                  controller: _controller,
                  value: s.commentDraft,
                  onChanged: c.commentDraft,
                  hint: 'Write a comment…',
                  candidates: s.mentionCandidates,
                  onSubmitted: () {
                    c.sendComment(widget.post);
                    _controller.clear();
                  },
                ),
              ),
              IconButton(
                tooltip: 'Post comment',
                onPressed: () {
                  c.sendComment(widget.post);
                  _controller.clear();
                },
                icon: Icon(
                  Icons.send,
                  size: 18,
                  color: context.nx.accentBrand,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
