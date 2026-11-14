import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/location_service.dart';

/// Shows the current GPS fix for a new post, or an honest "no fix" state.
class LocationTile extends ConsumerWidget {
  const LocationTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fix = ref.watch(placeFixProvider);
    return fix.when(
      loading: () => const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.place),
        title: Text('Finding your location…'),
      ),
      error: (e, _) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.place_outlined),
        title: const Text('Location unavailable'),
        subtitle: Text('$e'),
      ),
      data: (value) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.place),
        title: Text(value == null ? 'No location — tap Enable' : value.label),
        subtitle: Text(
          value == null
              ? 'Posts have no place until location access is granted'
              : 'Shown to people nearby',
        ),
        trailing: TextButton(
          onPressed: () => ref.invalidate(placeFixProvider),
          child: Text(value == null ? 'Enable' : 'Refresh'),
        ),
      ),
    );
  }
}
