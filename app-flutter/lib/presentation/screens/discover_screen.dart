import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../controllers/nexus_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/states.dart';

/// Utility, not a dating app: a clean list with explicit distances (§2.2).
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(nexusProvider),
        c = ref.read(nexusProvider.notifier),
        entries = ref.watch(discoverResultsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Discover', style: DesignTokens.screenTitle),
              ),
              IconButton(
                tooltip: 'Back to feed',
                onPressed: () => c.go('feed'),
                icon: Icon(Icons.close, color: context.nx.textPrimary),
              ),
            ],
          ),
          SizedBox(height: 12),
          NativeInput(
            value: s.query,
            onChanged: c.query,
            hint: 'Groups, people, places near you',
            prefixIcon: Icons.search,
          ),
          SizedBox(height: 12),
          Segmented(
            items: const ['Groups', 'People', 'Places', 'Business'],
            value: s.category,
            onSelect: c.category,
          ),
          if (s.category == 'business') ...[
            SizedBox(height: 8),
            ChoiceRow(
              items: const ['All', 'Cafe', 'Food', 'Service', 'Fashion'],
              value: s.subtype,
              onSelect: c.subtype,
            ),
          ],
          SizedBox(height: 12),
          Expanded(
            child: entries.isEmpty && s.busy
                ? ListView(
                    children: [
                      SkeletonCard(media: false),
                      SkeletonCard(media: false),
                    ],
                  )
                : entries.isEmpty
                ? EmptyState(
                    icon: Icons.travel_explore,
                    title: 'Nothing nearby yet',
                    message:
                        'No ${s.category} match this search. Try a wider area or a different filter.',
                    ctaLabel: 'Show everything',
                    onCta: () => c.query(''),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ResultRow(entry: entries[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends ConsumerWidget {
  const _ResultRow({required this.entry});
  final Entry entry;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(nexusProvider.notifier);
    final toggleable = entry.category == 'people' || entry.category == 'groups';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.nx.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(color: context.nx.border),
      ),
      child: Row(
        children: [
          IconTile(
            switch (entry.category) {
              'groups' => Icons.diversity_3,
              'people' => Icons.person,
              'business' => Icons.storefront,
              _ => Icons.place,
            },
            label: entry.category == 'people' && entry.icon.isNotEmpty
                ? entry.icon
                : null,
          ),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: DesignTokens.itemTitle),
                SizedBox(height: 3),
                Text(
                  entry.subtitle,
                  style: DesignTokens.meta.copyWith(
                    color: context.nx.textSecondary,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          if (toggleable)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                foregroundColor: entry.selected
                    ? context.nx.textSecondary
                    : context.nx.accentBrand,
                side: BorderSide(
                  color: entry.selected
                      ? context.nx.border
                      : context.nx.accentBrand,
                ),
              ),
              onPressed: () => c.toggleEntry(entry),
              child: Text(
                entry.category == 'groups'
                    ? (entry.selected ? 'Joined' : 'Join')
                    : (entry.selected ? 'Following' : 'Follow'),
              ),
            )
          else
            IconButton(
              tooltip: 'Open',
              onPressed: () => c.openEntry(entry),
              icon: Icon(
                Icons.chevron_right,
                color: context.nx.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
