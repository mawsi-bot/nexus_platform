import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/domain/models.dart';
import 'package:nexus/domain/repository.dart';
import 'package:nexus/presentation/media/media_providers.dart';
import 'package:nexus/presentation/media/media_rules.dart';
import 'package:nexus/presentation/controllers/providers.dart';
import 'package:nexus/presentation/screens/chat_screen.dart';
import 'package:nexus/presentation/theme.dart';
import 'package:nexus/presentation/widgets/composer_sheet.dart';
import 'package:nexus/presentation/widgets/mention.dart';
import 'package:nexus/presentation/widgets/offline_banner.dart';
import 'package:nexus/presentation/widgets/post_card.dart';
import 'package:nexus/presentation/widgets/reactions.dart';
import 'package:nexus/presentation/widgets/stickers.dart';

class WRepo implements NexusRepository {
  final sent = <String>[];
  @override
  bool get isDemo => false;
  @override
  void cancelPending() {}
  @override
  Future<Map<String, dynamic>> deviceLogin(String phone) async => {};
  @override
  Future<void> emailVerify(String phone, String email) async {}
  @override
  Future<void> confirm(String otp) async {}
  @override
  Future<Map<String, dynamic>> register(String p, String e) async => {};
  @override
  Future<bool> restoreSession() async => false;
  @override
  Future<String> uploadMedia(String filePath) async => '/api/v1/media/x';
  @override
  Future<String?> currentDeviceId() async => 'dev';
  @override
  Future<void> logout() async {}
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const {},
  }) async {
    if (path == '/feed/1/comments') {
      return {'items': <dynamic>[], 'next_cursor': ''};
    }
    if (path == '/users/me') return {'id': '7', 'name': 'Me'};
    if (path == '/feed') return {'items': <dynamic>[], 'next_cursor': ''};
    return {'items': <dynamic>[], 'next_cursor': ''};
  }

  @override
  Future<Map<String, dynamic>> send(
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
  }) async {
    sent.add('$method $path');
    return {'id': '1'};
  }
}

class WMedia implements MediaSource {
  WMedia({this.images = const ['/tmp/p.webp']});
  final List<String> images;
  @override
  Future<List<String>> pickImages(int remaining) async => images;
  @override
  Future<String?> pickVideo() async => null;
  @override
  Future<String?> pickOneImage() async => images.isEmpty ? null : images.first;
}

class WCompressor implements ImageCompressor {
  const WCompressor();
  @override
  Future<String> compress(String path) async => path;
}

Widget host(
  Widget child, {
  NexusRepository? repo,
  MediaSource? media,
  ImageCompressor? compressor,
  bool scroll = true,
}) => ProviderScope(
  overrides: [
    repositoryProvider.overrideWithValue(repo ?? WRepo()),
    if (media != null) mediaSourceProvider.overrideWithValue(media),
    if (compressor != null) imageCompressorProvider.overrideWithValue(compressor),
  ],
  child: MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(body: scroll ? SingleChildScrollView(child: child) : child),
  ),
);

void main() {
  const post = Post(
    id: '1',
    kind: 'photo',
    body: 'hello @ann',
    author: 'Ann Lee',
    media: ['/tmp/nx-a.webp', '/tmp/nx-b.webp'],
    reactions: {'love': 3},
  );

  testWidgets('post card renders media carousel and reaction summary',
      (tester) async {
    await tester.pumpWidget(host(const PostCard(post: post)));
    await tester.pump();
    expect(find.textContaining('hello'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('See who reacted'), findsOneWidget);
  });

  testWidgets('comment button opens the inline thread', (tester) async {
    await tester.pumpWidget(host(const PostCard(post: post)));
    await tester.tap(find.byIcon(Icons.chat_bubble_outline).first);
    await tester.pumpAndSettle();
    expect(
      find.text('No comments yet — start the conversation.'),
      findsOneWidget,
    );
  });

  testWidgets('overflow menu reports the post', (tester) async {
    final repo = WRepo();
    await tester.pumpWidget(host(const PostCard(post: post), repo: repo));
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report post'));
    await tester.pumpAndSettle();
    expect(repo.sent.any((e) => e.contains('/report')), isTrue);
  });

  testWidgets('reaction sheet returns the chosen emotion', (tester) async {
    String? picked;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showReactionPicker(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Love'), findsOneWidget);
    await tester.tap(find.text('Hug'));
    await tester.pumpAndSettle();
    expect(picked, 'hug');
  });

  testWidgets('who-reacted sheet lists names', (tester) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showWhoReacted(
              context,
              counts: const {'love': 2},
              load: () async => ['Ann'],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Reactions · 2'), findsOneWidget);
    expect(find.text('Ann'), findsOneWidget);
  });

  testWidgets('sticker picker offers bundled packs', (tester) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showStickerPicker(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Nexus'), findsOneWidget);
    expect(find.text('❤️'), findsOneWidget);
  });

  testWidgets('composer adds a picked photo', (tester) async {
    await tester.pumpWidget(
      host(
        const ComposerSheet(),
        media: WMedia(),
        compressor: const WCompressor(),
      ),
    );
    expect(find.textContaining('Photos 0/4'), findsOneWidget);
    await tester.tap(find.textContaining('Photos 0/4'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Photos 1/4'), findsOneWidget);
  });

  testWidgets('mention input suggests and inserts a handle', (tester) async {
    var value = '';
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: const EdgeInsets.all(12),
            child: MentionInput(
              value: value,
              candidates: const ['Ann Lee'],
              hint: 'Type',
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '@an');
    await tester.pumpAndSettle();
    expect(find.text('Ann'), findsOneWidget);
    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();
    expect(value, '@Ann ');
  });

  testWidgets('offline banner states the queue', (tester) async {
    await tester.pumpWidget(
      host(const OfflineBanner(online: false, queued: 2)),
    );
    expect(find.textContaining('2 changes will sync'), findsOneWidget);
  });

  testWidgets('chat screen exposes photo and sticker attachments',
      (tester) async {
    await tester.pumpWidget(host(const ChatScreen(), scroll: false));
    expect(find.text('Say hello'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Sticker'), findsOneWidget);
  });
}
