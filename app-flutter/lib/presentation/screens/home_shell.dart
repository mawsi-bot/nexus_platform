import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/nexus_controller.dart';
import '../theme.dart';
import '../widgets/sheets.dart';
import '../widgets/states.dart';
import 'feed_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'discover_screen.dart';
import 'shop_screen.dart';
import 'group_screen.dart';
import 'settings_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(nexusProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(nexusProvider), c = ref.read(nexusProvider.notifier);
    return Scaffold(
      backgroundColor: context.nx.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (s.error != null && s.posts.isNotEmpty)
              MaterialBanner(
                backgroundColor: context.nx.surface,
                content: Text(
                  friendlyError(s.error!),
                  style: DesignTokens.body,
                ),
                actions: [
                  TextButton(onPressed: c.load, child: const Text('Retry')),
                  TextButton(
                    onPressed: c.clearError,
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            Expanded(
              child: switch (s.screen) {
                'chat' => ChatScreen(),
                'profile' => ProfileScreen(),
                'settings' => SettingsScreen(),
                'discover' => DiscoverScreen(),
                'business' => ShopScreen(),
                'group' => const GroupScreen(),
                _ => FeedScreen(),
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.nx.surface,
          border: Border(top: BorderSide(color: context.nx.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final item in const [
                  ('feed', Icons.home_outlined, Icons.home, 'Home'),
                  ('discover', Icons.search, Icons.search, 'Discover'),
                  ('create', Icons.add_box_outlined, Icons.add_box, 'Create'),
                  ('chat', Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat'),
                  (
                    'profile',
                    Icons.person_outline,
                    Icons.person,
                    'Profile',
                  ),
                ])
                  _NavItem(
                    label: item.$4,
                    icon: s.screen == item.$1 ? item.$3 : item.$2,
                    active: s.screen == item.$1,
                    onTap: () => item.$1 == 'create'
                        ? openComposer(context, ref)
                        : c.go(item.$1),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 23,
            color: active
                ? context.nx.accentBrand
                : context.nx.textSecondary,
          ),
          SizedBox(height: 3),
          Text(
            label,
            style: DesignTokens.meta.copyWith(
              fontSize: 10,
              color: active
                  ? context.nx.accentBrand
                  : context.nx.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}
