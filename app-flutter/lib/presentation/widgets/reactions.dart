import 'package:flutter/material.dart';

import '../theme.dart';

/// Reaction vocabulary (§3.1). The keys are the wire values the API stores.
const Map<String, String> kReactions = {
  'love': '❤️',
  'hug': '🤗',
  'strong': '💪',
};
const List<String> kReactionOrder = ['love', 'hug', 'strong'];

String reactionEmoji(String emotion) => kReactions[emotion] ?? '❤️';

String reactionLabel(String emotion) => switch (emotion) {
  'love' => 'Love',
  'hug' => 'Hug',
  'strong' => 'Strong',
  _ => 'Like',
};

int reactionTotal(Map<String, int> counts) =>
    counts.values.fold<int>(0, (a, b) => a + b);

/// `❤️ 128 · 🤗 24 · 💪 12` — the compact summary above the action bar.
class ReactionSummaryBar extends StatelessWidget {
  const ReactionSummaryBar({super.key, required this.counts, this.onTap});
  final Map<String, int> counts;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) return const SizedBox.shrink();
    final shown = [
      for (final key in kReactionOrder)
        if ((counts[key] ?? 0) > 0) (key, counts[key]!),
    ];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 2),
        child: Row(
          children: [
            for (var i = 0; i < shown.length; i++)
              Transform.translate(
                offset: Offset(i == 0 ? 0 : -5.0 * i, 0),
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.nx.surfaceTint,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.nx.surface, width: 1.4),
                  ),
                  child: Text(
                    reactionEmoji(shown[i].$1),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Text(
              '${reactionTotal(counts)}',
              style: DesignTokens.meta.copyWith(
                color: context.nx.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (onTap != null)
              Text(
                'See who reacted',
                style: DesignTokens.meta.copyWith(
                  color: context.nx.accentBrand,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Long-press target. Returns the chosen emotion, or null when dismissed.
Future<String?> showReactionPicker(
  BuildContext context, {
  String? current,
}) => showModalBottomSheet<String>(
  context: context,
  backgroundColor: context.nx.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (sheet) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: sheet.nx.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final key in kReactionOrder)
                _ReactionButton(
                  emotion: key,
                  selected: current == key,
                  onTap: () => Navigator.pop(sheet, key),
                ),
            ],
          ),
        ],
      ),
    ),
  ),
);

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.emotion,
    required this.selected,
    required this.onTap,
  });
  final String emotion;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? context.nx.surfaceTint : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? context.nx.accentBrand : Colors.transparent,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(reactionEmoji(emotion), style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 6),
          Text(
            reactionLabel(emotion),
            style: DesignTokens.meta.copyWith(
              color: context.nx.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Who-reacted sheet. Loads names through [load] so the caller owns the fetch.
Future<void> showWhoReacted(
  BuildContext context, {
  required Map<String, int> counts,
  required Future<List<String>> Function() load,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: context.nx.surface,
  builder: (sheet) => _WhoReacted(counts: counts, load: load),
);

class _WhoReacted extends StatefulWidget {
  const _WhoReacted({required this.counts, required this.load});
  final Map<String, int> counts;
  final Future<List<String>> Function() load;
  @override
  State<_WhoReacted> createState() => _WhoReactedState();
}

class _WhoReactedState extends State<_WhoReacted> {
  String _filter = 'all';
  late final Future<List<String>> _future = widget.load();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reactions · ${reactionTotal(widget.counts)}',
            style: DesignTokens.itemTitle,
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final key in ['all', ...kReactionOrder])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selected: _filter == key,
                      onSelected: (_) => setState(() => _filter = key),
                      label: Text(
                        key == 'all'
                            ? 'All'
                            : '${reactionEmoji(key)} ${widget.counts[key] ?? 0}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: FutureBuilder<List<String>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final names = snap.data ?? const <String>[];
                if (names.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('Nobody yet — be the first.'),
                  );
                }
                return ListView(
                  shrinkWrap: true,
                  children: [
                    for (final name in names)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: context.nx.surfaceTint,
                          child: Text(
                            name.isEmpty ? '?' : name[0].toUpperCase(),
                            style: DesignTokens.meta.copyWith(
                              color: context.nx.accentBrand,
                            ),
                          ),
                        ),
                        title: Text(name, style: DesignTokens.body),
                        subtitle: Text(
                          _filter == 'all'
                              ? 'Reacted'
                              : reactionLabel(_filter),
                          style: DesignTokens.meta.copyWith(
                            color: context.nx.textSecondary,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
