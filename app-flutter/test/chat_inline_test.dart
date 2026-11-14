import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/domain/models.dart';
import 'package:nexus/presentation/controllers/nexus_controller.dart';
import 'package:nexus/presentation/media/media_providers.dart';
import 'package:nexus/presentation/media/media_rules.dart';
import 'package:nexus/presentation/screens/chat_screen.dart';
import 'package:nexus/presentation/theme.dart';
import 'package:nexus/presentation/widgets/post_actions.dart';

import 'support/harness.dart';

class ChatMedia implements MediaSource {
  @override
  Future<List<String>> pickImages(int remaining) async => const ['/tmp/a.webp'];
  @override
  Future<String?> pickVideo() async => null;
  @override
  Future<String?> pickOneImage() async => '/tmp/chat.webp';
}

class IdentityCompressor implements ImageCompressor {
  const IdentityCompressor();
  @override
  Future<String> compress(String path) async => path;
}

Widget chatHost(
  ProviderContainer container, {
  MediaSource? media,
  ImageCompressor? compressor,
}) {
  final merged = ProviderContainer(
    parent: container,
    overrides: [
      if (media != null) mediaSourceProvider.overrideWithValue(media),
      if (compressor != null)
        imageCompressorProvider.overrideWithValue(compressor),
    ],
  );
  addTearDown(merged.dispose);
  return UncontrolledProviderScope(
    container: merged,
    child: MaterialApp(
      theme: buildTheme(Brightness.light),
      home: const Scaffold(body: ChatScreen()),
    ),
  );
}

void main() {
  const post = Post(id: 'p2', kind: 'feel', body: 'hello world');

  testWidgets('chat sends typed text and shows the bubble', (tester) async {
    final repo = SheetRepo();
    final container = makeContainer(repo);
    await container.read(nexusProvider.notifier).load();
    await tester.pumpWidget(chatHost(container));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'hello there');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('hello there'), findsWidgets);
    expect(repo.sent.any((e) => e.contains('/messages')), isTrue);
  });

  testWidgets('chat attaches a photo through the compressor pipeline', (
    tester,
  ) async {
    final repo = SheetRepo();
    final container = makeContainer(repo);
    await container.read(nexusProvider.notifier).load();
    await tester.pumpWidget(
      chatHost(container, media: ChatMedia(), compressor: const IdentityCompressor()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsWidgets);
    expect(repo.sent.any((e) => e.contains('/messages')), isTrue);
  });

  testWidgets('chat sends a sticker from the bundled picker', (tester) async {
    final repo = SheetRepo();
    final container = makeContainer(repo);
    await container.read(nexusProvider.notifier).load();
    await tester.pumpWidget(chatHost(container));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sticker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('❤️').first);
    await tester.pumpAndSettle();
    expect(find.text('❤️'), findsWidgets);
    expect(repo.sent.any((e) => e.contains('/messages')), isTrue);
  });

  testWidgets('dismissing the attachment sheet sends nothing', (tester) async {
    final repo = SheetRepo();
    final container = makeContainer(repo);
    await container.read(nexusProvider.notifier).load();
    await tester.pumpWidget(chatHost(container));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(repo.sent, isEmpty);
  });

  testWidgets('inline thread lists, sends and likes a comment', (tester) async {
    final repo = SheetRepo();
    final container = makeContainer(repo);
    await container.read(nexusProvider.notifier).load();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: PostActions(post: post),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chat_bubble_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('nice'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'good stuff');
    await tester.tap(find.byTooltip('Post comment'));
    await tester.pumpAndSettle();
    expect(repo.sent.any((e) => e.contains('/feed/p2/comments')), isTrue);

    await tester.tap(find.byTooltip('Unlike comment').first);
    await tester.pumpAndSettle();
    expect(repo.sent.any((e) => e.endsWith('/like')), isTrue);
  });

  test('media contracts', () async {
    expect(await ChatMedia().pickOneImage(), '/tmp/chat.webp');
    expect(await const IdentityCompressor().compress('/tmp/a.webp'), '/tmp/a.webp');
    expect(MediaRules.maxImages, 4);
  });
}
