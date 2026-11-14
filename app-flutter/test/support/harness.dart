import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/domain/repository.dart';
import 'package:nexus/presentation/controllers/providers.dart';
import 'package:nexus/presentation/theme.dart';

/// Repository that answers every surface the sheet/grid widgets read from, so a
/// widget test exercises the real controller instead of a stub notifier.
class SheetRepo implements NexusRepository {
  SheetRepo({
    this.author = 'Me',
    this.sendThrows = false,
    String? profileTitle,
    this.session = false,
  }) : profileTitle = profileTitle ?? author;
  final bool session;
  final String author;
  final String profileTitle;
  final bool sendThrows;
  final sent = <String>[];
  int uploads = 0;

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
  Future<bool> restoreSession() async => session;
  @override
  Future<String> uploadMedia(String filePath) async {
    uploads++;
    return '/api/v1/media/${'b' * 32}';
  }

  @override
  Future<String?> currentDeviceId() async => 'dev';
  @override
  Future<void> logout() async {}

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const {},
  }) async {
    if (path == '/users/me') {
      return {'id': '7', 'title': profileTitle, 'name': profileTitle, 'bio': 'bio'};
    }
    if (path == '/feed') {
      return {
        'items': [
          {'id': 'p2', 'kind': 'feel', 'body': 'hello world', 'author': author},
        ],
        'next_cursor': '',
      };
    }
    if (path == '/feed/p2/comments') {
      return {
        'items': [
          {
            'id': 'c1',
            'title': 'Ann',
            'body': 'nice',
            'subtitle': '2m',
            'selected': true,
          },
          {'id': 'c2', 'title': 'Bo', 'body': 'agree', 'subtitle': '1m'},
        ],
        'next_cursor': '',
      };
    }
    if (path == '/notifications') {
      return {
        'items': [
          {
            'id': 'n1',
            'title': 'Ann commented',
            'subtitle': '2m',
            'category': 'comment',
            'target': 'p2',
            'unread': true,
          },
          {
            'id': 'n2',
            'title': 'Group invite',
            'subtitle': '3m',
            'category': 'group',
            'unread': true,
          },
          {
            'id': 'n3',
            'title': 'Shop offer',
            'subtitle': '4m',
            'category': 'biz',
          },
          {
            'id': 'n4',
            'title': 'Someone liked',
            'subtitle': '5m',
            'category': 'like',
          },
        ],
        'next_cursor': '',
      };
    }
    return {'items': <dynamic>[], 'next_cursor': ''};
  }

  @override
  Future<Map<String, dynamic>> send(
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
  }) async {
    if (sendThrows) throw StateError('boom');
    sent.add('$method $path');
    if (path == '/users/me') {
      return {'id': '7', 'title': profileTitle, 'bio': 'x'};
    }
    return {'id': 'ok'};
  }
}

ProviderContainer makeContainer(NexusRepository repo) {
  final container = ProviderContainer(
    overrides: [repositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

/// A screen with one button that opens the surface under test, so modal routes
/// have a host route to pop back to.
Widget openerHost(
  ProviderContainer container,
  void Function(BuildContext context) open,
) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);
