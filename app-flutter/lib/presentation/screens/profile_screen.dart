import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/nexus_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/profile_grid.dart';
import '../widgets/states.dart';

/// Instagram-style profile: cover, overlapping ring avatar, stats row, tabbed
/// grid. Settings live on their own screen (§2.5).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(nexusProvider), c = ref.read(nexusProvider.notifier);
    final name = (s.profile['title'] as String?)?.trim() ?? '';
    final handle = (s.profile['handle'] as String?)?.trim() ?? '';
    final bio = (s.profile['bio'] as String?)?.trim() ?? '';
    final stats = (s.profile['stats'] as List?) ?? const [];
    final verified = s.profile['verified'] == true;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: 232,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ScrimmedMedia(height: 196, radius: 0),
              Positioned(
                top: 8,
                right: 10,
                child: Row(
                  children: [
                    _OverlayAction(
                      tooltip: 'Share profile',
                      icon: Icons.ios_share,
                      onTap: () => SharePlus.instance.share(
                        ShareParams(
                          text: name.isEmpty ? 'Nexus profile' : '$name · $handle',
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    _OverlayAction(
                      tooltip: 'Settings',
                      icon: Icons.settings_outlined,
                      onTap: () => c.go('settings'),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 18,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.nx.surface,
                  ),
                  child: Avatar(size: 78, ring: true),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name.isEmpty ? 'Your profile' : name,
                      style: DesignTokens.screenTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (verified) ...[
                    SizedBox(width: 7),
                    VerifiedBadge(size: 17),
                  ],
                ],
              ),
              if (handle.isNotEmpty)
                Text(
                  handle,
                  style: DesignTokens.meta.copyWith(
                    color: context.nx.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (bio.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(bio, style: DesignTokens.body),
              ],
              SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: context.nx.surface,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                  border: Border.all(color: context.nx.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < 3; i++)
                      _Stat(
                        value: i < stats.length ? '${stats[i]}' : '0',
                        label: const ['Following', 'Followers', 'Likes'][i],
                      ),
                  ],
                ),
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => _EditProfile(),
                      ),
                      child: const Text('Edit profile'),
                    ),
                  ),
                  SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => c.go('business'),
                    child: const Text('My shop'),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Segmented(
                items: const ['Videos', 'Liked', 'Saved'],
                value: s.profileTab,
                onSelect: c.profileTab,
              ),
              SizedBox(height: 10),
              ProfileGrid(),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverlayAction extends StatelessWidget {
  const _OverlayAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: context.nx.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 19, color: context.nx.textPrimary),
        ),
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: DesignTokens.itemTitle),
      SizedBox(height: 2),
      Text(
        label,
        style: DesignTokens.meta.copyWith(color: context.nx.textSecondary),
      ),
    ],
  );
}

class _EditProfile extends ConsumerStatefulWidget {
  const _EditProfile();
  @override
  ConsumerState<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends ConsumerState<_EditProfile> {
  late final TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: ref.read(nexusProvider).profile['bio'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.nx.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
    ),
    title: Text('Edit profile', style: DesignTokens.itemTitle),
    content: TextField(
      controller: controller,
      maxLength: 200,
      maxLines: 3,
      decoration: const InputDecoration(hintText: 'Tell people about you'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () async {
          await ref.read(nexusProvider.notifier).editProfile(controller.text);
          if (context.mounted) Navigator.pop(context);
        },
        child: const Text('Save'),
      ),
    ],
  );
}
