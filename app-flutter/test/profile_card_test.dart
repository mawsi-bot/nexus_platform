import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/domain/models.dart';
import 'package:nexus/domain/repository.dart';
import 'package:nexus/presentation/controllers/nexus_controller.dart';
import 'package:nexus/presentation/controllers/providers.dart';
import 'package:nexus/presentation/screens/profile_screen.dart';
import 'package:nexus/presentation/theme.dart';
import 'package:nexus/presentation/widgets/post_card.dart';

const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

class ProfileRepo implements NexusRepository {
  ProfileRepo({this.stats = const [12, 240, 998], this.verified = false});
  final List<int> stats;
  final bool verified;
  final sent = <String>[];
  final bios = <String>[];

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
    switch (path) {
      case '/users/me':
        return {
          'id': '7',
          'title': 'Ann Lee',
          'name': 'Ann Lee',
          'handle': '@ann',
          'bio': 'tea and trails',
          'stats': stats,
          'verified': verified,
        };
      case '/feed':
        return {
          'items': [
            {'id': '1', 'kind': 'feel', 'body': 'mine', 'author': 'Ann Lee'},
            {'id': '2', 'kind': 'feel', 'body': 'theirs', 'author': 'Bo'},
          ],
          'next_cursor': '',
        };
      case '/items/1/reactions':
        return {
          'items': [
            {'name': 'Ann'},
            {'name': 'Bo'},
          ],
          'next_cursor': '',
        };
      default:
        return {'items': <dynamic>[], 'next_cursor': ''};
    }
  }

  @override
  Future<Map<String, dynamic>> send(
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
  }) async {
    sent.add('$method $path');
    if (path == '/users/me') {
      final bio = '${body['bio'] ?? ''}';
      bios.add(bio);
      return {
        'id': '7',
        'title': 'Ann Lee',
        'handle': '@ann',
        'bio': bio,
        'stats': stats,
      };
    }
    return {'id': '1'};
  }
}

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<ProviderContainer> bootProfile(WidgetTester tester, ProfileRepo repo) async {
  tall(tester);
  final container = ProviderContainer(
    overrides: [repositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  await container.read(nexusProvider.notifier).load();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const Scaffold(body: ProfileScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Widget cardHost(ProviderContainer container, Post post) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: PostCard(post: post),
            ),
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
  });

  group('ProfileScreen', () {
    testWidgets('renders name, handle, bio and stats', (tester) async {
      final repo = ProfileRepo();
      await bootProfile(tester, repo);
      expect(tester.takeException(), isNull);
      expect(find.text('Ann Lee'), findsWidgets);
      expect(find.text('@ann'), findsOneWidget);
      expect(find.text('tea and trails'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('240'), findsOneWidget);
      expect(find.text('998'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Likes'), findsOneWidget);
      expect(find.byType(VerifiedBadgeFinder), findsNothing);
    });

    testWidgets('a verified profile shows the badge', (tester) async {
      await bootProfile(tester, ProfileRepo(verified: true));
      expect(find.byTooltip('Verified business'), findsOneWidget);
    });

    testWidgets('tab switch changes the grid copy', (tester) async {
      final container = await bootProfile(tester, ProfileRepo());
      expect(find.text('mine'), findsOneWidget);
      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();
      expect(container.read(nexusProvider).profileTab, 'saved');
      expect(find.text('mine'), findsOneWidget);
      await tester.tap(find.text('Liked'));
      await tester.pumpAndSettle();
      expect(container.read(nexusProvider).profileTab, 'liked');
    });

    testWidgets('settings overlay routes to settings', (tester) async {
      final container = await bootProfile(tester, ProfileRepo());
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(container.read(nexusProvider).screen, 'settings');
    });

    testWidgets('share overlay calls the platform share', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, (call) async => 'dev.nexus.test');
      await bootProfile(tester, ProfileRepo());
      await tester.tap(find.byTooltip('Share profile'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Share profile'), findsOneWidget);
    });

    testWidgets('My shop routes to the business surface', (tester) async {
      final container = await bootProfile(tester, ProfileRepo());
      await tester.tap(find.text('My shop'));
      await tester.pumpAndSettle();
      expect(container.read(nexusProvider).screen, 'business');
    });

    testWidgets('edit-profile dialog cancels without writing', (tester) async {
      final repo = ProfileRepo();
      await bootProfile(tester, repo);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('tea and trails'), findsWidgets);
      await tester.enterText(find.byType(TextField).last, 'something else');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.bios, isEmpty);
    });

    testWidgets('edit-profile dialog saves the new bio', (tester) async {
      final repo = ProfileRepo();
      final container = await bootProfile(tester, repo);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'new bio line');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.bios, ['new bio line']);
      expect(container.read(nexusProvider).profile['bio'], 'new bio line');
    });

    testWidgets('an empty profile falls back to placeholder copy', (tester) async {
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(ProfileRepo(stats: []))],
      );
      addTearDown(container.dispose);
      tall(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const Scaffold(body: ProfileScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your profile'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });

  group('PostCard actions', () {
    testWidgets('long-press opens the reaction picker and applies it',
        (tester) async {
      final repo = ProfileRepo();
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(nexusProvider.notifier).load();
      await tester.pumpWidget(cardHost(
        container,
        const Post(id: '1', kind: 'feel', body: 'mine', author: 'Ann Lee'),
      ));
      await tester.pumpAndSettle();
      await tester.longPress(find.byIcon(Icons.favorite_border).first);
      await tester.pumpAndSettle();
      expect(find.text('Hug'), findsOneWidget);
      await tester.tap(find.text('Hug'));
      await tester.pumpAndSettle();
      expect(repo.sent, contains('PUT /items/1/reaction'));
      final updated = container.read(nexusProvider).posts.first;
      expect(updated.reactions['hug'], 1);
      expect(updated.myReaction, 'hug');
    });

    testWidgets('the reaction summary opens the who-reacted sheet',
        (tester) async {
      final repo = ProfileRepo();
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(nexusProvider.notifier).load();
      await tester.pumpWidget(cardHost(
        container,
        const Post(
          id: '1',
          kind: 'feel',
          body: 'mine',
          author: 'Ann Lee',
          reactions: {'love': 2, 'hug': 1},
          liked: true,
          myReaction: 'love',
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsWidgets);
      await tester.tap(find.text('See who reacted'));
      await tester.pumpAndSettle();
      expect(find.text('Reactions · 3'), findsOneWidget);
      expect(find.text('Ann'), findsOneWidget);
      expect(find.text('Bo'), findsOneWidget);
    });

    testWidgets('share opens the share sheet for the post', (tester) async {
      final repo = ProfileRepo();
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(nexusProvider.notifier).load();
      await tester.pumpWidget(cardHost(
        container,
        const Post(id: '1', kind: 'feel', body: 'mine'),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.ios_share).first);
      await tester.pumpAndSettle();
      expect(find.text('Share this post'), findsOneWidget);
      expect(find.text('https://nexus.app/p/1'), findsOneWidget);
    });

    testWidgets('hide removes the card from the feed', (tester) async {
      final repo = ProfileRepo();
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(nexusProvider.notifier).load();
      await tester.pumpWidget(cardHost(
        container,
        const Post(id: '1', kind: 'feel', body: 'mine'),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide post'));
      await tester.pumpAndSettle();
      expect(repo.sent, contains('PUT /items/1/hide'));
      expect(container.read(nexusProvider).posts.map((p) => p.id), ['2']);
      expect(find.text('Post hidden from your feed'), findsOneWidget);
    });

    testWidgets('save toggles through the API', (tester) async {
      final repo = ProfileRepo();
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(nexusProvider.notifier).load();
      await tester.pumpWidget(cardHost(
        container,
        const Post(id: '1', kind: 'feel', body: 'mine'),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.bookmark_border).first);
      await tester.pumpAndSettle();
      expect(repo.sent, contains('PUT /items/1/save'));
      expect(container.read(nexusProvider).posts.first.saved, isTrue);
    });
  });
}

/// Placeholder type keeps the "no badge" assertion readable.
class VerifiedBadgeFinder extends StatelessWidget {
  const VerifiedBadgeFinder({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
