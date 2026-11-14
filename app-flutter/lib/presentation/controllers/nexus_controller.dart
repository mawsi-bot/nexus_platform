import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api_client.dart';
import '../../data/location_service.dart';
import '../../data/offline/action_queue.dart';
import '../../data/scoped_repository.dart';
import '../../domain/models.dart';
import '../../domain/repository.dart';
import '../widgets/states.dart';
import 'offline_providers.dart';
import 'providers.dart';

final nexusProvider = NotifierProvider<NexusController, NexusState>(
  NexusController.new,
);
final rankedPostsProvider = Provider((ref) {
  final s = ref.watch(nexusProvider);
  return ref.watch(repositoryProvider).isDemo
      ? rankPosts(s.posts, s.filter)
      : s.posts;
});
final discoverResultsProvider = Provider((ref) {
  final s = ref.watch(nexusProvider);
  return s.discover
      .where((e) => (s.subtype == 'all' || e.subtype == s.subtype))
      .toList();
});
final canPostProvider = Provider(
  (ref) => ref.watch(
    nexusProvider.select(
      (s) => s.draft.trim().length >= 3 && s.draft.length <= 200 && !s.busy,
    ),
  ),
);

class NexusController extends Notifier<NexusState> {
  late NexusRepository repo;
  int _discoverRevision = 0;
  @override
  NexusState build() {
    var active = true;
    ref.onDispose(() {
      active = false;
    });
    repo = ScopedRepository(ref.read(repositoryProvider), () => active);
    return const NexusState();
  }

  /// Decodes a post plus the reaction summary and media list the API returns
  /// alongside it.
  Post postFrom(Map<String, dynamic> json) {
    final summary = json['reactions'];
    final counts = summary is Map ? summary['counts'] : null;
    return Post.fromJson(json).copyWith(
      media: ((json['media'] as List?) ?? const []).map((e) => '$e').toList(),
      reactions: counts is Map
          ? counts.map((k, v) => MapEntry('$k', (v as num).toInt()))
          : const <String, int>{},
    );
  }

  List<Entry> entries(dynamic data) => (data as List? ?? [])
      .map((e) => Entry.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  Future<void> guard(Future<void> Function() action) async {
    if (!ref.mounted) return;
    state = state.copyWith(error: null);
    try {
      await action();
    } on RequestCancelled {
      return;
    } catch (e) {
      if (ref.mounted) state = state.copyWith(error: friendlyError(e));
    }
  }

  Future<void> load() => guard(() async {
    state = state.copyWith(busy: true);
    try {
      final profile = await repo.get('/users/me');
      final data = await Future.wait([
        repo.get('/feed'),
        repo.get('/discover', query: {'type': state.category}),
        repo.get('/chat/threads'),
        repo.get('/shops'),
        repo.get('/groups'),
      ]);
      final threads = entries(data[2]['items']),
          shops = entries(data[3]['items']),
          groups = entries(data[4]['items']);
      final loaded = (data[0]['items'] as List? ?? [])
          .map((p) => postFrom(Map<String, dynamic>.from(p as Map)))
          .toList();
      final nextCursor = '${data[0]['next_cursor'] ?? ''}';
      state = state.copyWith(
        profile: profile,
        posts: loaded,
        cursor: nextCursor,
        hasMore: nextCursor.isNotEmpty,
        mentionCandidates: [
          for (final p in loaded)
            if (p.author.isNotEmpty) p.author,
        ],
        discover: entries(data[1]['items']),
        threadId: threads.isEmpty ? '' : threads.first.id,
        threadName: threads.isEmpty ? '' : threads.first.title,
      );
      if (shops.isNotEmpty) await openShop(shops.first.id);
      if (groups.isNotEmpty) await openGroup(groups.first.id);
      if (state.threadId.isNotEmpty) {
        final messages = await repo.get(
          '/chat/threads/${state.threadId}/messages',
        );
        state = state.copyWith(messages: entries(messages['items']));
      }
      // Activity is optional in Go; a 404 is displayed, never replaced with demo data.
      try {
        final notes = await repo.get('/notifications');
        state = state.copyWith(notifications: entries(notes['items']));
      } on ApiException catch (e) {
        if (e.status == 404) {
          state = state.copyWith(
            error:
                'Notifications unavailable: backend ActivityStore route is not deployed. ${e.requestId ?? ''}',
          );
        } else {
          rethrow;
        }
      }
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  });
  Future<void> openShop(String id) async {
    final shop = await repo.get('/shops/$id');
    final products = await repo.get('/shops/$id/products');
    state = state.copyWith(shop: shop, products: entries(products['items']));
  }

  Future<void> openGroup(String id) async {
    final group = await repo.get('/groups/$id');
    state = state.copyWith(group: group);
  }

  Future<void> openEntry(Entry entry) => guard(() async {
    if (entry.target == 'business') {
      await openShop(entry.id);
      go('business');
    } else if (entry.target == 'group') {
      await openGroup(entry.id);
      go('group');
    }
  });
  void go(String screen) => state = state.copyWith(screen: screen);
  void filter(String value) => state = state.copyWith(filter: value);
  Future<void> _discover() async {
    final revision = ++_discoverRevision;
    final category = state.category, query = state.query;
    final result = await repo.get(
      '/discover',
      query: {'type': category, 'q': query},
    );
    if (revision == _discoverRevision) {
      state = state.copyWith(discover: entries(result['items']));
    }
  }

  Future<void> category(String value) => guard(() async {
    state = state.copyWith(category: value, subtype: 'all', discover: []);
    await _discover();
  });
  void subtype(String value) => state = state.copyWith(subtype: value);
  Future<void> query(String value) => guard(() async {
    state = state.copyWith(query: value);
    await _discover();
  });
  void profileTab(String value) => state = state.copyWith(profileTab: value);
  void draft(String value) => state = state.copyWith(draft: value);
  void kind(String value) => state = state.copyWith(kind: value);
  void mood(String value) => state = state.copyWith(mood: value);
  void messageDraft(String value) =>
      state = state.copyWith(messageDraft: value);
  void commentDraft(String value) =>
      state = state.copyWith(commentDraft: value);
  void reply(Entry entry) => state = state.copyWith(replyTo: entry.title);
  void repost(Post? post) => state = state.copyWith(repost: post, draft: '');
  void clearError() => state = state.copyWith(error: null);
  void updatePost(Post post) => state = state.copyWith(
    posts: state.posts.map((p) => p.id == post.id ? post : p).toList(),
  );
  Future<void> like(Post post) => guard(() async {
    await repo.send(
      '/items/${post.id}/like',
      {},
      method: post.liked ? 'DELETE' : 'PUT',
    );
    updatePost(
      post.copyWith(
        liked: !post.liked,
        likes: post.likes + (post.liked ? -1 : 1),
      ),
    );
  });
  Future<void> save(Post post) => guard(() async {
    await repo.send(
      '/items/${post.id}/save',
      {},
      method: post.saved ? 'DELETE' : 'PUT',
    );
    updatePost(post.copyWith(saved: !post.saved));
  });
  Future<void> publish() => guard(() async {
    if (state.busy ||
        state.draft.trim().length < 3 ||
        state.draft.length > 200) {
      return;
    }
    final draft = state.draft.trim();
    final repost = state.repost;
    final mood = state.mood;
    final picked = state.draftMedia;
    state = state.copyWith(busy: true);
    try {
      // Upload first: a queued post must reference media the server already has.
      final uploaded = <String>[];
      for (final path in picked) {
        uploaded.add(await repo.uploadMedia(path));
      }
      final fix = ref.read(placeFixProvider).asData?.value;
      final data = await repo.send('/feed', {
        'name': repo.isDemo ? mood : '',
        'place_name': fix?.label ?? '',
        'lat': fix?.lat,
        'lng': fix?.lng,
        'body': draft,
        'visibility': 'public',
        if (uploaded.isNotEmpty) 'media': uploaded,
      });
      final queued = data['_queued'] == true;
      final post = Post(
        id: queued
            ? 'local-${DateTime.now().microsecondsSinceEpoch}'
            : data['id'].toString(),
        kind: uploaded.isEmpty ? 'feel' : 'photo',
        body: draft,
        title: repo.isDemo ? mood.toUpperCase() : '',
        author: state.profile['title'] as String? ?? '',
        media: uploaded,
        score: 99,
        originalId: repost?.id,
        originalAuthor: repost?.author,
        originalBody: repost?.body,
      );
      state = state.copyWith(
        posts: [post, ...state.posts],
        screen: 'feed',
        draft: '',
        draftMedia: const [],
        repost: null,
      );
      if (queued) await syncNow();
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  });
  Future<void> comments(Post post) => guard(() async {
    final data = await repo.get('/feed/${post.id}/comments');
    state = state.copyWith(
      comments: {...state.comments, post.id: entries(data['items'])},
      replyTo: '',
    );
  });
  Future<void> sendComment(Post post) => guard(() async {
    if (state.commentDraft.trim().isEmpty) return;
    final body = state.commentDraft.trim();
    final result = await repo.send('/feed/${post.id}/comments', {'body': body});
    state = state.copyWith(
      comments: {
        ...state.comments,
        post.id: [
          ...?state.comments[post.id],
          Entry(
            id: result['id'].toString(),
            title: state.profile['title'] as String? ?? '',
            body: body,
            subtitle: 'now',
          ),
        ],
      },
      commentDraft: '',
      replyTo: '',
    );
    final current = state.posts.firstWhere((p) => p.id == post.id);
    updatePost(current.copyWith(comments: current.comments + 1));
  });
  Future<void> likeComment(Post post, Entry entry) => guard(() async {
    await repo.send(
      '/items/${entry.id}/like',
      {},
      method: entry.selected ? 'DELETE' : 'PUT',
    );
    state = state.copyWith(
      comments: {
        ...state.comments,
        post.id: state.comments[post.id]!
            .map(
              (e) => e.id == entry.id ? e.copyWith(selected: !e.selected) : e,
            )
            .toList(),
      },
    );
  });
  Future<void> sendMessage() async {
    final body = state.messageDraft.trim();
    if (body.isEmpty) return;
    state = state.copyWith(messageDraft: '');
    await _appendMessage(body);
  }

  Future<void> sendImage(String path) => guard(() async {
    final url = await repo.uploadMedia(path);
    await _appendMessage(url, subtype: 'image');
  });

  Future<void> sendSticker(String glyph) =>
      guard(() => _appendMessage(glyph, subtype: 'sticker'));

  Future<void> _appendMessage(String body, {String subtype = ''}) async {
    final local = Entry(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      title: 'You',
      body: body,
      subtitle: 'now',
      outgoing: true,
      subtype: subtype,
    );
    final before = state.messages;
    state = state.copyWith(messages: [...state.messages, local]);
    await guard(() async {
      await repo.send('/chat/threads/${state.threadId}/messages', {
        'body': body,
        if (subtype.isNotEmpty) 'kind': subtype,
      });
    });
    if (state.error != null && ref.mounted) {
      state = state.copyWith(messages: before);
    }
  }

  /// Reacts optimistically and rolls the card back if the write fails, so a
  /// heart never appears for a reaction the server did not store.
  Future<void> react(Post post, String emotion) async {
    final before = post;
    final counts = <String, int>{...post.reactions};
    final was = post.myReaction;
    final removing = was == emotion;
    if (was.isNotEmpty) {
      final left = (counts[was] ?? 1) - 1;
      if (left <= 0) {
        counts.remove(was);
      } else {
        counts[was] = left;
      }
    }
    if (!removing) counts[emotion] = (counts[emotion] ?? 0) + 1;
    updatePost(
      post.copyWith(
        reactions: counts,
        myReaction: removing ? '' : emotion,
        liked: !removing,
        likes: before.likes + (removing ? -1 : (was.isEmpty ? 1 : 0)),
      ),
    );
    await guard(() async {
      if (removing) {
        await repo.send('/items/${post.id}/reaction', {}, method: 'DELETE');
      } else {
        await repo.send(
          '/items/${post.id}/reaction',
          {'emotion': emotion},
          method: 'PUT',
        );
      }
    });
    if (state.error != null) updatePost(before);
  }

  Future<void> report(Post post, {String reason = 'community_guidelines'}) =>
      guard(() async {
        await repo.send(
          '/items/${post.id}/report',
          {'reason': reason},
          method: 'PUT',
        );
      });

  Future<void> hide(Post post) => guard(() async {
    await repo.send('/items/${post.id}/hide', {}, method: 'PUT');
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != post.id).toList(),
    );
  });

  Future<List<String>> reactors(Post post) async {
    try {
      final data = await repo.get(
        '/items/${post.id}/reactions',
        query: {'who': '1'},
      );
      return (data['items'] as List? ?? const [])
          .map((e) => '${(e as Map)['name'] ?? e['actor_id'] ?? ''}')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Next feed page (§5). Demo data is a single page, so it stops immediately.
  Future<void> loadMore() async {
    if (repo.isDemo) {
      if (state.hasMore) state = state.copyWith(hasMore: false);
      return;
    }
    if (!state.hasMore || state.loadingMore || state.busy) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await repo.get(
        '/feed',
        query: {'cursor': state.cursor, 'limit': '20'},
      );
      final known = state.posts.map((p) => p.id).toSet();
      final next = (page['items'] as List? ?? [])
          .map((p) => postFrom(Map<String, dynamic>.from(p as Map)))
          .where((p) => !known.contains(p.id))
          .toList();
      final cursor = '${page['next_cursor'] ?? ''}';
      state = state.copyWith(
        posts: [...state.posts, ...next],
        cursor: cursor,
        hasMore: cursor.isNotEmpty,
        loadingMore: false,
      );
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(loadingMore: false, error: friendlyError(e));
      }
    }
  }

  void setOnline(bool value) {
    if (state.online == value) return;
    state = state.copyWith(online: value);
    if (value) unawaited(syncNow());
  }

  /// Replays writes made while offline, oldest first.
  Future<void> syncNow() async {
    final queue = ref.read(actionQueueProvider);
    final pending = await queue.length();
    if (ref.mounted) state = state.copyWith(queuedCount: pending);
    if (pending == 0) return;
    await ActionQueuePump(queue: queue, repo: repo).drain();
    final left = await queue.length();
    if (ref.mounted) state = state.copyWith(queuedCount: left);
  }

  void addDraftMedia(String path) =>
      state = state.copyWith(draftMedia: [...state.draftMedia, path]);

  void removeDraftMedia(String path) => state = state.copyWith(
    draftMedia: state.draftMedia.where((p) => p != path).toList(),
  );

  void clearDraftMedia() => state = state.copyWith(draftMedia: const []);

  Future<void> toggleEntry(Entry entry) => guard(() async {
    if (entry.category == 'groups') {
      await repo.send(
        '/groups/${entry.id}/join',
        {},
        method: entry.selected ? 'DELETE' : 'POST',
      );
    } else {
      await repo.send(
        entry.category == 'people'
            ? '/users/${entry.id}/follow'
            : '/items/${entry.id}/follow',
        {},
        method: entry.selected ? 'DELETE' : 'PUT',
      );
    }
    state = state.copyWith(
      discover: state.discover
          .map((e) => e.id == entry.id ? e.copyWith(selected: !e.selected) : e)
          .toList(),
    );
  });
  Future<void> join(bool joined) => guard(() async {
    final id = state.group['id'];
    if (id == null) throw StateError('No backend group available');
    await repo.send('/groups/$id/join', {}, method: joined ? 'POST' : 'DELETE');
    state = state.copyWith(joined: joined);
  });
  Future<void> addProduct(Entry product) => guard(() async {
    final quantity = (state.cart[product.id] ?? 0) + 1;
    await repo.send('/cart/${product.id}', {
      'quantity': quantity,
    }, method: 'PUT');
    state = state.copyWith(cart: {...state.cart, product.id: quantity});
  });
  Future<void> markRead([Entry? entry]) => guard(() async {
    final list = entry == null
        ? state.notifications.where((e) => e.unread).toList()
        : [entry];
    for (final n in list) {
      await repo.send('/notifications/${n.id}/read', {}, method: 'PATCH');
      state = state.copyWith(
        notifications: state.notifications
            .map((e) => e.id == n.id ? e.copyWith(unread: false) : e)
            .toList(),
      );
    }
  });
  Future<void> share(Post post, String channel) => guard(() async {
    await repo.send('/items/${post.id}/shares', {});
    updatePost(post.copyWith(shares: post.shares + 1));
  });
  Future<void> editProfile(String bio) => guard(() async {
    final profile = await repo.send('/users/me', {'bio': bio}, method: 'PATCH');
    state = state.copyWith(
      profile: repo.isDemo ? {...state.profile, 'bio': bio} : profile,
    );
  });
  Future<void> saveShop() => guard(() async {
    final id = state.shop['id'];
    if (id == null) throw StateError('No backend shop available');
    await repo.send('/items/$id/save', {}, method: 'PUT');
  });
}
