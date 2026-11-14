import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/domain/models.dart';
import 'package:nexus/presentation/controllers/nexus_controller.dart';
import 'package:nexus/presentation/widgets/comments_sheet.dart';
import 'package:nexus/presentation/widgets/notifications.dart';
import 'package:nexus/presentation/widgets/profile_grid.dart';
import 'package:nexus/presentation/widgets/share_sheet.dart';
import 'package:nexus/presentation/widgets/sheets.dart';
import 'package:nexus/presentation/theme.dart';

import 'support/harness.dart';

const post = Post(id: 'p2', kind: 'feel', body: 'hello world');

void main() {
  testWidgets('comments sheet lists entries, replies, likes and sends', (
    tester,
  ) async {
    final repo = SheetRepo();
    final container = makeContainer(repo);
    await container.read(nexusProvider.notifier).load();
    await container.read(nexusProvider.notifier).comments(post);

    await tester.pumpWidget(
      openerHost(
        container,
        (context) => openSheet(context, const CommentsSheet(post: post)),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Comments (2)'), findsOneWidget);
    expect(find.text('nice'), findsOneWidget);
    expect(find.text('Liked'), findsOneWidget);

    await tester.tap(find.text('Reply').first);
    await tester.pumpAndSettle();
    expect(find.text('Replying to Ann'), findsOneWidget);

    await tester.tap(find.text('Like').first);
    await tester.pumpAndSettle();
    expect(repo.sent, contains('PUT /items/c2/like'));

    await tester.enterText(find.byType(TextFormField), 'my reply');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Send reply'));
    await tester.pumpAndSettle();
    expect(repo.sent.any((e) => e.contains('/feed/p2/comments')), isTrue);
  });

  testWidgets('share sheet copies the link and text, saves, shows a QR', (
    tester,
  ) async {
    final repo = SheetRepo();
    final container = makeContainer(repo);
    await container.read(nexusProvider.notifier).load();

    await tester.pumpWidget(
      openerHost(
        container,
        (context) => openSheet(context, const ShareSheet(post: post)),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('https://nexus.app/p/p2'), findsOneWidget);
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy text'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save post'));
    await tester.pumpAndSettle();
    expect(repo.sent, contains('PUT /items/p2/save'));

    await tester.tap(find.text('QR code'));
    await tester.pumpAndSettle();
    expect(find.text('QR code'), findsWidgets);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
  });

  testWidgets('share sheet can repost to the composer', (tester) async {
    final container = makeContainer(SheetRepo());
    await container.read(nexusProvider.notifier).load();
    await tester.pumpWidget(
      openerHost(
        container,
        (context) => openSheet(context, const ShareSheet(post: post)),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share to your profile'));
    await tester.pumpAndSettle();
    expect(container.read(nexusProvider).repost?.id, 'p2');
    expect(find.text('Share to your profile'), findsWidgets);
  });

  testWidgets('notifications panel marks read, routes and opens comments', (
    tester,
  ) async {
    final repo = SheetRepo();
    final container = makeContainer(repo);
    await container.read(nexusProvider.notifier).load();

    await tester.pumpWidget(
      openerHost(
        container,
        (context) => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const SizedBox(
            height: 600,
            child: NotificationsPanel(),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Ann commented'), findsOneWidget);
    expect(find.text('Shop offer'), findsOneWidget);

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(repo.sent.where((e) => e.endsWith('/read')).length, 2);

    await tester.tap(find.text('Group invite'));
    await tester.pumpAndSettle();
    expect(container.read(nexusProvider).screen, 'group');
  });

  testWidgets('a commented notification opens its thread', (tester) async {
    final repo = SheetRepo();
    final container = makeContainer(repo);
    await container.read(nexusProvider.notifier).load();
    await tester.pumpWidget(
      openerHost(
        container,
        (context) => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const SizedBox(
            height: 600,
            child: NotificationsPanel(),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ann commented'));
    await tester.pumpAndSettle();
    expect(container.read(nexusProvider).comments['p2'], isNotNull);
  });

  testWidgets('business and generic notifications route or toast', (
    tester,
  ) async {
    final repo = SheetRepo();
    final container = makeContainer(repo);
    await container.read(nexusProvider.notifier).load();
    await tester.pumpWidget(
      openerHost(
        container,
        (context) => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const SizedBox(
            height: 600,
            child: NotificationsPanel(),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Someone liked'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('profile grid shows the empty state per tab', (tester) async {
    final repo = SheetRepo(profileTitle: 'Nobody');
    final container = makeContainer(repo);
    await container.read(nexusProvider.notifier).load();
    await tester.pumpWidget(
      openerHost(
        container,
        (_) {},
      ),
    );
    await tester.pumpWidget(
      UncontrolledGrid(container: container),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.textContaining('videos will appear'), findsOneWidget);
  });

  testWidgets('profile grid renders my posts and its CTA opens the composer', (
    tester,
  ) async {
    final container = makeContainer(SheetRepo());
    await container.read(nexusProvider.notifier).load();
    await tester.pumpWidget(UncontrolledGrid(container: container));
    await tester.pumpAndSettle();
    expect(find.text('hello world'), findsOneWidget);
  });
}

/// Grid host: ProfileGrid expands, so it needs a full-height parent and the
/// live container the controller was loaded through.
class UncontrolledGrid extends StatelessWidget {
  const UncontrolledGrid({super.key, required this.container});
  final ProviderContainer container;
  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: buildTheme(Brightness.light),
      home: const Scaffold(body: SingleChildScrollView(child: ProfileGrid())),
    ),
  );
}
