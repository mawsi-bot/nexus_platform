import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/domain/repository.dart';
import 'package:nexus/presentation/controllers/providers.dart';
import 'package:nexus/presentation/screens/discover_screen.dart';
import 'package:nexus/presentation/screens/group_screen.dart';
import 'package:nexus/presentation/screens/home_shell.dart';
import 'package:nexus/presentation/screens/profile_screen.dart';
import 'package:nexus/presentation/screens/shop_screen.dart';
import 'package:nexus/presentation/theme.dart';

class SRepo implements NexusRepository {
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
    if (path == '/users/me') {
      return {'id': '7', 'name': 'Me', 'bio': 'bio', 'handle': '@me'};
    }
    if (path == '/shops/9' || path == '/groups/3') {
      return {'id': path.endsWith('9') ? '9' : '3', 'title': 'Nexus place'};
    }
    return {'items': <dynamic>[], 'next_cursor': ''};
  }

  @override
  Future<Map<String, dynamic>> send(
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
  }) async => {'id': '1'};
}

Widget wrap(Widget child) => ProviderScope(
  overrides: [repositoryProvider.overrideWithValue(SRepo())],
  child: MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(body: child),
  ),
);

void main() {
  final screens = <(String, Widget)>[
    ('home shell', const HomeShell()),
    ('discover', const DiscoverScreen()),
    ('shop', const ShopScreen()),
    ('profile', const ProfileScreen()),
    ('group', const GroupScreen()),
  ];
  for (final (name, screen) in screens) {
    testWidgets('$name builds without an exception', (tester) async {
      await tester.pumpWidget(wrap(screen));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsWidgets);
    });
  }

}
