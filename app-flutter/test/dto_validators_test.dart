import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/dto_mapper.dart';
import 'package:nexus/domain/models.dart';
import 'package:nexus/domain/repository.dart';

void main() {
  final mapper = DtoMapper();

  test('rejects missing ids instead of inventing one', () {
    expect(() => mapper.id(null), throwsFormatException);
    expect(() => mapper.id(''), throwsFormatException);
    expect(mapper.id(12), '12');
    expect(mapper.id('abc'), 'abc');
  });

  test('maps a profile and remembers its id', () {
    final p = mapper.profile({'id': 5, 'name': 'Ann', 'email_verified': true});
    expect(p['id'], '5');
    expect(p['title'], 'Ann');
    expect(p['email_verified'], isTrue);
    expect(mapper.profileId, '5');
  });

  test('maps a post', () {
    final post = mapper.post({'id': 3, 'body': 'hey', 'author_id': '7'});
    expect(post['kind'], 'feel');
    expect(post['body'], 'hey');
    expect(post['author'], '7');
  });

  test('maps items with price, initials and direction', () {
    final shop = mapper.item({
      'id': 9,
      'kind': 'shop',
      'name': 'Cafe',
      'price_minor': 500,
      'currency': 'MMK',
    });
    expect(shop['price'], '500 K');
    expect(shop['target'], 'business');

    final usd = mapper.item({
      'id': 10,
      'kind': 'shop',
      'price_minor': 250,
      'currency': 'USD',
    });
    expect(usd['price'], '2.50 USD');

    final person = mapper.item({'author_id': 4, 'kind': 'person', 'name': 'Ann Lee'});
    expect(person['id'], '4');
    expect(person['icon'], 'AL');

    mapper.profile({'id': 7});
    final mine = mapper.item({
      'id': 11,
      'kind': 'message',
      'author_id': '7',
    });
    expect(mine['outgoing'], isTrue);
  });

  test('maps activity, detail and pages', () {
    final note = mapper.activity({
      'id': 2,
      'kind': 'like',
      'body': 'Ann liked',
      'read': false,
    });
    expect(note['title'], 'Ann liked');
    expect(note['unread'], isTrue);
    expect(note['category'], 'like');

    final full = mapper.activity({'id': 3, 'kind': 'follow', 'actor_id': '9'});
    expect(full['title'], 'follow · 9');
    expect(full['unread'], isTrue);

    final shop = mapper.detail({'id': 4, 'visibility': 'public'}, shop: true);
    expect(shop['reviews'], isEmpty);
    final group = mapper.detail({'id': 5}, shop: false);
    expect(group['rules'], isEmpty);

    final page = mapper.page(
      {
        'items': [
          {'id': 1, 'body': 'a'},
        ],
        'next_cursor': 'c2',
      },
      mapper.post,
    );
    expect((page['items'] as List).length, 1);
    expect(page['next_cursor'], 'c2');
  });

  test('validators', () {
    expect(validatePhone('+959123456789'), isNull);
    expect(validatePhone('0912345'), isNotNull);
    expect(validateEmail('a@b.co'), isNull);
    expect(validateEmail('nope'), isNotNull);
    expect(validateEmail('${'a' * 250}@b.co'), isNotNull);
    expect(validateOtp('${'a' * 22}.${'b' * 43}'), isNull);
    expect(validateOtp('short'), isNotNull);
  });

  test('ranking prefers friends for nearby and sorts by score', () {
    final posts = [
      const Post(id: '1', kind: 'feel', body: 'a', score: 10),
      const Post(id: '2', kind: 'feel', body: 'b', score: 50, friend: true),
      const Post(id: '3', kind: 'feel', body: 'c', score: 30, nearby: true),
    ];
    expect(rankPosts(posts, 'foryou').map((p) => p.id), ['2', '3', '1']);
    expect(rankPosts(posts, 'nearby').map((p) => p.id), ['2', '3']);
  });
}
