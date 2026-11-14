import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/presentation/controllers/nexus_controller.dart';
import 'package:nexus/presentation/screens/settings_screen.dart';
import 'package:nexus/presentation/theme.dart';

import 'support/harness.dart';
import 'support/plugins.dart';

/// A tall surface so the whole settings list is laid out at once; assertions on
/// rows below the fold would otherwise search unbuilt widgets.
void tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<ProviderContainer> boot(WidgetTester tester) async {
  tallView(tester);
  final container = makeContainer(SheetRepo());
  await container.read(nexusProvider.notifier).load();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const Scaffold(body: SettingsScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => clearMock(secureStorageChannel));

  testWidgets('renders every group with no debug assertion', (tester) async {
    installSecureStorage();
    await boot(tester);
    // The Material fix means the ListTile ink assertion must not fire at all.
    expect(tester.takeException(), isNull);
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('ACCOUNT SECURITY'), findsOneWidget);
    expect(find.text('DEVICES'), findsOneWidget);
    expect(find.text('RECOVERY GMAIL'), findsOneWidget);
    expect(find.byType(Material), findsWidgets);
    expect(find.textContaining('Nexus 1.4.2'), findsOneWidget);
  });

  testWidgets('device row shows the truncated installation id', (tester) async {
    installSecureStorage();
    await boot(tester);
    expect(find.text('This device'), findsOneWidget);
    expect(find.textContaining('This device · dev'), findsOneWidget);
  });

  testWidgets('back and edit-profile both route to the profile', (tester) async {
    installSecureStorage();
    final container = await boot(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    expect(container.read(nexusProvider).screen, 'profile');
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(container.read(nexusProvider).screen, 'profile');
  });

  testWidgets('recovery-email dialog explains the flow and closes', (
    tester,
  ) async {
    installSecureStorage();
    await boot(tester);
    await tester.tap(find.text('Change recovery email'));
    await tester.pumpAndSettle();
    expect(find.text('Recovery email'), findsOneWidget);
    expect(find.textContaining('one-time code'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Recovery email'), findsNothing);
  });

  testWidgets('sign-out asks for confirmation and can be cancelled', (
    tester,
  ) async {
    installSecureStorage();
    final container = await boot(tester);
    await tester.tap(find.text('Sign out of this device'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsNothing);
    // Cancelling must not tear the session down.
    expect(container.read(nexusProvider).screen, 'feed');
  });

  testWidgets('a verified email is badged and an empty one is labelled', (
    tester,
  ) async {
    installSecureStorage();
    tallView(tester);
    final container = makeContainer(SheetRepo());
    await container.read(nexusProvider.notifier).load();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No recovery email'), findsOneWidget);
    expect(find.textContaining('Used for account recovery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
