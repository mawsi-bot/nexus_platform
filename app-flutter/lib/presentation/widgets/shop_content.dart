import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../controllers/nexus_controller.dart';
import '../theme.dart';
import 'common.dart';

/// Business profile body: contact rows, a 2-column product grid with explicit
/// add-to-cart affordances, photos, and a structured reviews section (§2.3).
class ShopContent extends ConsumerWidget {
  const ShopContent({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(nexusProvider);
    final contact = (s.shop['contact'] as List?) ?? const [];
    final reviews = (s.shop['reviews'] as List?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (contact.isNotEmpty) SectionTitle('Contact & hours'),
        for (final row in contact)
          _Surface(
            child: Row(
              children: [
                IconTile(Icons.info_outline, size: 36),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row['title']}',
                        style: DesignTokens.itemTitle.copyWith(fontSize: 13.5),
                      ),
                      Text(
                        '${row['subtitle']}',
                        style: DesignTokens.meta.copyWith(
                          color: context.nx.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        SectionTitle('Products'),
        if (s.products.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'This shop has not published products yet.',
              style: TextStyle(color: context.nx.textSecondary),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: s.products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (_, i) => _ProductTile(product: s.products[i]),
          ),
        SectionTitle('Photos'),
        Row(
          spacing: 6,
          children: [
            Expanded(child: Photo(height: 76, radius: 12)),
            Expanded(
              child: Photo(
                height: 76,
                radius: 12,
                alignment: Alignment(-.24, .24),
              ),
            ),
            Expanded(
              child: Photo(
                height: 76,
                radius: 12,
                alignment: Alignment(.4, -.4),
              ),
            ),
          ],
        ),
        SectionTitle('Reviews'),
        if (reviews.isEmpty)
          Text(
            'No reviews yet. Be the first to review this business.',
            style: TextStyle(color: context.nx.textSecondary),
          )
        else
          for (final review in reviews)
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${review['title']}',
                          style: DesignTokens.itemTitle.copyWith(fontSize: 13.5),
                        ),
                      ),
                      if (review['rating'] is num)
                        _Stars(rating: (review['rating'] as num).toDouble()),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '${review['body'] ?? review['subtitle'] ?? ''}',
                    style: DesignTokens.body.copyWith(
                      color: context.nx.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.product});
  final Entry product;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(nexusProvider),
        c = ref.read(nexusProvider.notifier);
    final count = s.cart[product.id] ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: context.nx.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(color: context.nx.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Photo(width: double.infinity, radius: 0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DesignTokens.itemTitle.copyWith(fontSize: 13),
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.price,
                        style: DesignTokens.itemTitle.copyWith(
                          color: context.nx.accentBrand,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: Material(
                        color: context.nx.accentBrand,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => c.addProduct(product),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.add,
                                size: 18,
                                color: Colors.white,
                              ),
                              if (count > 0)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: context.nx.textPrimary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$count',
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});
  final double rating;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          rating >= i
              ? Icons.star_rounded
              : rating >= i - .5
              ? Icons.star_half_rounded
              : Icons.star_outline_rounded,
          size: 15,
          color: context.nx.accentBrand,
        ),
    ],
  );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.nx.surface,
      borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
      border: Border.all(color: context.nx.border),
    ),
    child: child,
  );
}
