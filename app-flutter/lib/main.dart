import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/api_client.dart';
import 'data/mock_repository.dart';
import 'data/offline/bootstrap.dart';
import 'data/offline/connectivity.dart';
import 'data/offline/offline_repository.dart';
import 'data/real_repository.dart';
import 'data/telemetry.dart';
import 'data/vault.dart';
import 'domain/repository.dart';
import 'presentation/controllers/auth_controller.dart';
import 'presentation/controllers/offline_providers.dart';
import 'presentation/controllers/providers.dart';
import 'presentation/controllers/theme_mode.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/theme.dart';
import 'presentation/widgets/offline_banner.dart';

Future<void> main() => startTelemetry(() async {
  WidgetsFlutterBinding.ensureInitialized();
  const mock = bool.fromEnvironment('NEXUS_MOCK', defaultValue: false);
  const base = String.fromEnvironment('NEXUS_API_URL');
  final storage = await openOfflineStorage();
  final NexusRepository inner = mock
      ? await MockRepository.load()
      : RealRepository(ApiClient(base, SecureVault()));
  // Demo data is local, so it needs no cache or queue in front of it.
  final NexusRepository repo = mock
      ? inner
      : OfflineRepository(inner, cache: storage.cache, queue: storage.queue);
  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        cacheStoreProvider.overrideWithValue(storage.cache),
        actionQueueProvider.overrideWithValue(storage.queue),
        connectivityProvider.overrideWithValue(PluginConnectivityMonitor()),
      ],
      child: const NexusApp(),
    ),
  );
});

class NexusApp extends ConsumerStatefulWidget {
  const NexusApp({super.key});
  @override
  ConsumerState<NexusApp> createState() => _NexusAppState();
}

class _NexusAppState extends ConsumerState<NexusApp> {
  @override
  void initState() {
    super.initState();
    // Auto login: continue a stored session before the login form can flash.
    Future.microtask(() => ref.read(authProvider.notifier).restore());
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Nexus',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: ref.watch(themeModeProvider),
    builder: (context, child) =>
        OfflineScope(child: child ?? const SizedBox.shrink()),
    home: Consumer(
      builder: (context, ref, _) {
        final auth = ref.watch(authProvider);
        if (auth.restoring) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: context.nx.accentBrand,
              ),
            ),
          );
        }
        return auth.stage == 'home' ? const HomeShell() : const AuthScreen();
      },
    ),
  );
}
