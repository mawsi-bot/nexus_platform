import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/nexus_controller.dart';
import '../controllers/providers.dart';
import '../controllers/device_actions.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/shop_content.dart';
import '../widgets/states.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(nexusProvider), c = ref.read(nexusProvider.notifier);
    final demo = ref.watch(repositoryProvider).isDemo;
    final title = (s.shop['title'] as String?)?.trim() ?? '';
    final verified = s.shop['verified'] == true;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: 214,
                child: Stack(
                  children: [
                    ScrimmedMedia(height: 190, radius: 0),
                    Positioned(
                      top: 10,
                      left: 12,
                      child: Material(
                        color: context.nx.surface,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed: () => c.go('discover'),
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            size: 17,
                            color: context.nx.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      bottom: 0,
                      child: Container(
                        width: 78,
                        height: 78,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.nx.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: context.nx.surface,
                            width: 3,
                          ),
                          boxShadow: DesignTokens.cardShadow,
                        ),
                        child: BrandMark(size: 40),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title.isEmpty ? 'Business' : title,
                            style: DesignTokens.screenTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (verified) ...[
                          SizedBox(width: 7),
                          VerifiedBadge(size: 18),
                        ],
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Verified business on Nexus',
                      style: DesignTokens.meta.copyWith(
                        color: context.nx.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: demo ? () => c.guard(callShop) : null,
                            icon: const Icon(Icons.call, size: 17),
                            label: const Text('Call'),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: demo ? () => c.guard(directions) : null,
                            icon: const Icon(Icons.directions, size: 17),
                            label: const Text('Directions'),
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton.outlined(
                          tooltip: 'Save shop',
                          onPressed: c.saveShop,
                          icon: const Icon(Icons.bookmark_border),
                        ),
                      ],
                    ),
                    ShopContent(),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (s.cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            decoration: BoxDecoration(
              color: context.nx.surface,
              border: Border(top: BorderSide(color: context.nx.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${s.cart.values.fold<int>(0, (a, b) => a + b)} item(s) in cart',
                    style: DesignTokens.itemTitle,
                  ),
                ),
                FilledButton(onPressed: () {}, child: const Text('Checkout')),
              ],
            ),
          ),
      ],
    );
  }
}
