import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/auth_controller.dart';
import '../controllers/nexus_controller.dart';
import '../controllers/providers.dart';
import '../theme.dart';

/// Settings live outside the profile grid (§2.5): account security, devices and
/// the recovery address are separate, labelled destinations.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(nexusProvider), c = ref.read(nexusProvider.notifier);
    final email = (s.profile['email'] as String?)?.trim() ?? '';
    final verified = s.profile['email_verified'] == true;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 10),
          color: context.nx.surface,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => c.go('profile'),
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: context.nx.textPrimary,
                ),
              ),
              Expanded(
                child: Text('Settings', style: DesignTokens.screenTitle),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _GroupLabel('Account security'),
              _SettingsTile(
                icon: Icons.lock_outline,
                title: 'Sign-in method',
                subtitle: 'This device is the primary credential',
                trailing: Icon(
                  Icons.check_circle,
                  color: context.nx.accentBrand,
                  size: 18,
                ),
              ),
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'Edit profile',
                subtitle: 'Name, handle and bio',
                onTap: () => c.go('profile'),
              ),
              _GroupLabel('Devices'),
              _DeviceTile(),
              _SettingsTile(
                icon: Icons.logout,
                title: 'Sign out of this device',
                subtitle: 'You will need your recovery email to return',
                danger: true,
                onTap: () => _confirmLogout(context, ref),
              ),
              _GroupLabel('Recovery Gmail'),
              _SettingsTile(
                icon: Icons.alternate_email,
                title: email.isEmpty ? 'No recovery email' : email,
                subtitle: verified
                    ? 'Verified — usable to recover this account'
                    : 'Used for account recovery on a new device',
                trailing: verified
                    ? Icon(
                        Icons.verified,
                        size: 18,
                        color: context.nx.accentBrand,
                      )
                    : null,
              ),
              _SettingsTile(
                icon: Icons.sync_alt,
                title: 'Change recovery email',
                subtitle:
                    'For your protection the change is confirmed with a code sent to the current address',
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: context.nx.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusCard,
                      ),
                    ),
                    title: Text('Recovery email', style: DesignTokens.itemTitle),
                    content: const Text(
                      'Open a recovery request from the login screen. We send a one-time code to the address on file and bind the new device when you redeem it.',
                      style: DesignTokens.body,
                    ),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 22),
              Center(
                child: Column(
                  children: [
                    // Mono mark, per the Logo Kit: single-colour inked context.
                    Image.asset(
                      'assets/brand/nexus-mark-mono.png',
                      height: 26,
                      filterQuality: FilterQuality.high,
                      semanticLabel: 'Nexus',
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Nexus 1.4.2 · Business & Community',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.nx.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: context.nx.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
      ),
      title: Text('Sign out?', style: DesignTokens.itemTitle),
      content: const Text(
        'This removes the session from this device. Your account and posts stay safe.',
        style: DesignTokens.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
  if (ok == true) await ref.read(authProvider.notifier).logout();
}

class _DeviceTile extends ConsumerWidget {
  const _DeviceTile();
  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder<String?>(
    future: ref.read(repositoryProvider).currentDeviceId(),
    builder: (context, snapshot) {
      final id = snapshot.data;
      final label = id == null || id.isEmpty
          ? 'Device identifier unavailable'
          : 'This device · ${id.length > 10 ? '${id.substring(0, 8)}…' : id}';
      return _SettingsTile(
        icon: Icons.smartphone,
        title: 'This device',
        subtitle: label,
        trailing: Icon(
          Icons.check_circle,
          color: context.nx.accentBrand,
          size: 18,
        ),
      );
    },
  );
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
    child: Text(
      text.toUpperCase(),
      style: DesignTokens.meta.copyWith(
        color: context.nx.textSecondary,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  // A Material owns the background and the border so the tile paints its own
  // ink; a decorated Container here would hide ripples and trip a debug assert.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: context.nx.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        side: BorderSide(color: context.nx.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: danger ? context.nx.danger : context.nx.textPrimary,
          size: 21,
        ),
        title: Text(
          title,
          style: DesignTokens.itemTitle.copyWith(
            fontSize: 14,
            color: danger ? context.nx.danger : context.nx.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: DesignTokens.meta.copyWith(
            color: context.nx.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: trailing,
      ),
    ),
  );
}
