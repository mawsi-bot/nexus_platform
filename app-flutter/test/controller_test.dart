import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/api_client.dart';
import 'package:nexus/domain/models.dart';
import 'package:nexus/domain/repository.dart';
import 'package:nexus/presentation/controllers/nexus_controller.dart';
import 'package:nexus/presentation/controllers/offline_providers.dart';
import 'package:nexus/presentation/controllers/providers.dart';

class FakeRepo implements NexusRepository {
  FakeRepo({this.demo = false});
  final bool demo;
  bool failReaction = false;
  bool offlineWrites = false;
  final sent = <String>[];

  @override
  bool get isDemo => demo;
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
  Future<String> uploadMedia(String filePath) async =>
      '/api/v1/media/${'a' * 32}';
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
        return {'id': '7', 'name': 'Me', 'bio': '', 'email_verified': true};
      case '/feed':
        if (query['cursor'] == 'c2') {
          return {
            'items': [
              {'id': '1', 'kind': 'feel', 'body': 'dup', 'author': 'Ann Lee'},
              {'id': '3', 'kind': 'feel', 'body': 'third', 'author': 'Cy'},
            ],
            'next_cursor': '',
          };
        }
        return {
          'items': [
            {'id': '1', 'kind': 'feel', 'body': 'hello', 'author': 'Ann Lee'},
            {'id': '2', 'kind': 'photo', 'body': 'second', 'author': 'Bo'},
          ],
          'next_cursor': 'c2',
        };
      case '/discover':
        return {
          'items': [
            {'id': 'd1', 'title': 'Ann', 'category': 'people'},
          ],
          'next_cursor': '',
        };
      case '/chat/threads':
        return {
          'items': [
            {'id': 't1', 'title': 'Sam'},
          ],
          'next_cursor': '',
        };
      case '/shops':
        return {
          'items': [
            {'id': '9', 'title': 'Cafe'},
          ],
          'next_cursor': '',
        };
      case '/groups':
        return {
          'items': [
            {'id': '3', 'title': 'Runners'},
          ],
          'next_cursor': '',
        };
      case '/shops/9':
        return {'id': '9', 'title': 'Cafe'};
      case '/shops/9/products':
        return {
          'items': [
            {'id': 'p1', 'title': 'Coffee', 'price': '2 K'},
          ],
          'next_cursor': '',
        };
      case '/groups/3':
        return {'id': '3', 'title': 'Runners'};
      case '/chat/threads/t1/messages':
        return {
          'items': [
            {'id': 'm1', 'title': 'Sam', 'body': 'hey'},
          ],
          'next_cursor': '',
        };
      case '/feed/1/comments':
        return {
          'items': [
            {'id': 'c1', 'title': 'Ann', 'body': 'nice'},
          ],
          'next_cursor': '',
        };
      case '/items/1/reactions':
        return {
          'items': [
            {'name': 'Ann'},
          ],
          'next_cursor': '',
        };
      default:
        if (path == '/notifications') return {'items': <dynamic>[]};
        throw ApiException(404, 'MOCK_ROUTE_NOT_FOUND');
    }
  }

  @override
  Future<Map<String, dynamic>> send(
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
  }) async {
    if (offlineWrites) throw const SocketExceptionStub();
    if (failReaction && path.contains('/reaction')) {
      throw ApiException(500, 'REACTION_FAILED');
    }
    sent.add('$method $path');
    if (path == '/feed') return {'id': 'post-9'};
    if (path == '/users/me') return {'id': '7', 'name': 'Me', 'bio': 'new'};
    return {'id': 'ok'};
  }
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}

ProviderContainer makeContainer(NexusRepository repo) {
  final container = ProviderContainer(
    overrides: [repositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('load hydrates every surface and pagination cursor', () async {
    final repo = FakeRepo();
    final container = makeContainer(repo);
    final c = container.read(nexusProvider.notifier);
    await c.load();
    final s = container.read(nexusProvider);
    expect(s.posts.length, 2);
    expect(s.cursor, 'c2');
    expect(s.hasMore, isTrue);
    expect(s.threadName, 'Sam');
    expect(s.messages.length, 1);
    expect(s.shop['id'], '9');
    expect(s.products.length, 1);
    expect(s.group['id'], '3');
    expect(s.mentionCandidates, contains('Ann Lee'));
    expect(s.busy, isFalse);
  });

  test('loadMore appends the next page once and de-duplicates', () async {
    final repo = FakeRepo();
    final container = makeContainer(repo);
    final c = container.read(nexusProvider.notifier);
    await c.load();
    await c.loadMore();
    final s = container.read(nexusProvider);
    expect(s.posts.map((p) => p.id), ['1', '2', '3']);
    expect(s.hasMore, isFalse);
    expect(s.loadingMore, isFalse);
    await c.loadMore();
    expect(container.read(nexusProvider).posts.length, 3);
  });

  test('demo repositories never paginate', () async {
    final container = makeContainer(FakeRepo(demo: true));
    final c = container.read(nexusProvider.notifier);
    await c.loadMore();
    expect(container.read(nexusProvider).hasMore, isFalse);
  });

  test('react is optimistic and rolls back when the server refuses', () async {
    final repo = FakeRepo();
    final container = makeContainer(repo);
    final c = container.read(nexusProvider.notifier);
    await c.load();
    await c.react(container.read(nexusProvider).posts.first, 'love');
    var post = container.read(nexusProvider).posts.first;
    expect(post.reactions['love'], 1);
    expect(post.liked, isTrue);
    expect(post.myReaction, 'love');

    repo.failReaction = true;
    await c.react(container.read(nexusProvider).posts.first, 'hug');
    post = container.read(nexusProvider).posts.first;
    expect(post.reactions['love'], 1);
    expect(post.reactions.containsKey('hug'), isFalse);
    expect(container.read(nexusProvider).error, isNotNull);

    repo.failReaction = false;
    await c.react(container.read(nexusProvider).posts.first, 'love');
    post = container.read(nexusProvider).posts.first;
    expect(post.reactions.containsKey('love'), isFalse);
    expect(post.liked, isFalse);
    expect(repo.sent.where((e) => e.endsWith('/reaction')).length, 2);
  });

  test('hide removes the card and report posts to the API', () async {
    final repo = FakeRepo();
    final container = makeContainer(repo);
    final c = container.read(nexusProvider.notifier);
    await c.load();
    final post = container.read(nexusProvider).posts.first;
    await c.report(post);
    expect(repo.sent, contains('PUT /items/1/report'));
    await c.hide(post);
    expect(container.read(nexusProvider).posts.map((p) => p.id), ['2']);
  });

  test('publish uploads media then prepends the post', () async {
    final repo = FakeRepo();
    final container = makeContainer(repo);
    final c = container.read(nexusProvider.notifier);
    await c.load();
    c.draft('a body for the feed');
    c.addDraftMedia('/tmp/a.webp');
    await c.publish();
    final s = container.read(nexusProvider);
    expect(s.posts.first.id, 'post-9');
    expect(s.posts.first.kind, 'photo');
    expect(s.posts.first.media.single, startsWith('/api/v1/media/'));
    expect(s.draft, isEmpty);
    expect(s.draftMedia, isEmpty);
  });

  test('sticker, image and text messages append optimistically', () async {
    final repo = FakeRepo();
    final container = makeContainer(repo);
    final c = container.read(nexusProvider.notifier);
    await c.load();
    c.messageDraft('hello');
    await c.sendMessage();
    await c.sendSticker('🤗');
    await c.sendImage('/tmp/a.webp');
    final messages = container.read(nexusProvider).messages;
    expect(messages.length, 4);
    expect(messages.last.subtype, 'image');
    expect(messages[2].body, '🤗');
    expect(messages[2].subtype, 'sticker');
  });

  test('a failed message rolls the bubble back', () async {
    final repo = FakeRepo();
    final container = makeContainer(repo);
    final c = container.read(nexusProvider.notifier);
    await c.load();
    repo.offlineWrites = true;
    await c.sendSticker('❤️');
    expect(container.read(nexusProvider).messages.length, 1);
    expect(container.read(nexusProvider).error, isNotNull);
  });

  test('comments load and a new one increments the counter', () async {
    final repo = FakeRepo();
    final container = makeContainer(repo);
    final c = container.read(nexusProvider.notifier);
    await c.load();
    final post = container.read(nexusProvider).posts.first;
    await c.comments(post);
    expect(container.read(nexusProvider).comments['1']?.length, 1);
    c.commentDraft('great');
    await c.sendComment(post);
    expect(container.read(nexusProvider).comments['1']?.length, 2);
    expect(container.read(nexusProvider).posts.first.comments, 1);
  });

  test('reactors and discover search', () async {
    final repo = FakeRepo();
    final container = makeContainer(repo);
    final c = container.read(nexusProvider.notifier);
    await c.load();
    expect(await c.reactors(container.read(nexusProvider).posts.first), ['Ann']);
    await c.query('ann');
    expect(container.read(nexusProvider).discover.length, 1);
  });

  test('syncNow drains queued writes', () async {
    final repo = FakeRepo();
    final container = makeContainer(repo);
    final c = container.read(nexusProvider.notifier);
    await container.read(actionQueueProvider).add(path: '/x', body: const {});
    await c.syncNow();
    expect(await container.read(actionQueueProvider).length(), 0);
    expect(container.read(nexusProvider).queuedCount, 0);
    expect(repo.sent, contains('POST /x'));
  });

  test('cart, join, follow, save and profile edits reach the API', () async {
    final repo = FakeRepo();
    final container = makeContainer(repo);
    final c = container.read(nexusProvider.notifier);
    await c.load();
    final s = container.read(nexusProvider);
    await c.addProduct(s.products.first);
    expect(container.read(nexusProvider).cart['p1'], 1);
    await c.join(true);
    await c.join(false);
    await c.toggleEntry(const Entry(id: 'd1', category: 'groups'));
    await c.toggleEntry(const Entry(id: 'd1', category: 'people'));
    await c.save(s.posts.first);
    await c.like(s.posts.first);
    await c.share(s.posts.first, 'copy');
    await c.saveShop();
    await c.editProfile('new bio');
    expect(container.read(nexusProvider).profile['bio'], 'new');
    expect(repo.sent.any((e) => e.contains('/cart/p1')), isTrue);
    expect(repo.sent.any((e) => e.contains('/users/me')), isTrue);
  });

  test('markRead clears unread notifications', () async {
    final repo = FakeRepo();
    final container = makeContainer(repo);
    final c = container.read(nexusProvider.notifier);
    await c.load();
    await c.markRead(const Entry(id: 'n1', unread: true));
    expect(repo.sent, contains('PATCH /notifications/n1/read'));
  });

  test('openEntry routes to shop and group surfaces', () async {
    final repo = FakeRepo();
    final container = makeContainer(repo);
    final c = container.read(nexusProvider.notifier);
    await c.openEntry(const Entry(id: '9', target: 'business'));
    expect(container.read(nexusProvider).screen, 'business');
    await c.openEntry(const Entry(id: '3', target: 'group'));
    expect(container.read(nexusProvider).screen, 'group');
  });

  test('setOnline flips the banner state', () async {
    final container = makeContainer(FakeRepo());
    final c = container.read(nexusProvider.notifier);
    c.setOnline(false);
    expect(container.read(nexusProvider).online, isFalse);
    c.setOnline(false);
    expect(container.read(nexusProvider).online, isFalse);
  });
}
