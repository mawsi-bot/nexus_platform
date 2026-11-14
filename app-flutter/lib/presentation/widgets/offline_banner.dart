import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/nexus_controller.dart';
import '../controllers/offline_providers.dart';
import '../theme.dart';

/// Wraps the app: tells the controller when the device goes offline, drains the
/// write queue when it comes back, and shows the status strip (§8).
class OfflineScope extends ConsumerWidget {
  const OfflineScope({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider).value ?? true;
    ref.listen(onlineProvider, (previous, next) {
      final value = next.value;
      if (value == null) return;
      ref.read(nexusProvider.notifier).setOnline(value);
      if (value) ref.invalidate(pendingWritesProvider);
    });
    final s = ref.watch(nexusProvider);
    final pending =
        ref.watch(pendingWritesProvider).value ?? s.queuedCount;
    return Column(
      children: [
        if (!online || pending > 0)
          OfflineBanner(online: online, queued: pending),
        Expanded(child: child),
      ],
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.online, required this.queued});
  final bool online;
  final int queued;
  @override
  Widget build(BuildContext context) {
    final offline = !online;
    return Material(
      color: offline ? context.nx.textPrimary : context.nx.accentBrand,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            children: [
              Icon(
                offline ? Icons.cloud_off : Icons.cloud_done,
                size: 15,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  offline
                      ? (queued > 0
                            ? 'Offline — $queued change${queued == 1 ? '' : 's'} will sync when you reconnect'
                            : 'Offline — showing your cached feed')
                      : 'Back online — sending $queued queued change${queued == 1 ? '' : 's'}…',
                  style: DesignTokens.meta.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
