import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/domain/repository.dart';
import 'package:nexus/presentation/controllers/auth_controller.dart';
import 'package:nexus/presentation/controllers/providers.dart';

/// Product directive: Device ID is the primary credential, email is recovery.
class FakeAuthRepository implements NexusRepository {
  FakeAuthRepository({this.deviceMatches = true, this.canRestore = false});
  bool deviceMatches;
  bool canRestore;
  int registerCalls = 0;
  int deviceLogins = 0;
  int emailVerifyCalls = 0;

  @override
  bool get isDemo => true;
  @override
  void cancelPending() {}
  @override
  Future<Map<String, dynamic>> deviceLogin(String phone) async {
    deviceLogins++;
    return deviceMatches
        ? {'_status': 200, 'jwt': 'jwt', 'refresh': 'refresh'}
        : {'_status': 202, 'action': 'REQUIRE_EMAIL_VERIFICATION'};
  }

  @override
  Future<void> emailVerify(String phone, String email) async {
    emailVerifyCalls++;
  }

  @override
  Future<void> confirm(String otp) async {}
  @override
  Future<Map<String, dynamic>> register(String phone, String email) async {
    registerCalls++;
    return {'_status': 200, 'jwt': 'jwt', 'refresh': 'refresh'};
  }

  @override
  Future<bool> restoreSession() async => canRestore;
  @override
  Future<String> uploadMedia(String filePath) async => '/api/v1/media/${'0' * 32}';
  @override
  Future<String?> currentDeviceId() async => 'fake-device';
  @override
  Future<void> logout() async {}
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const {},
  }) async => {};
  @override
  Future<Map<String, dynamic>> send(
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
  }) async => {};
}

ProviderContainer container(FakeAuthRepository repo) => ProviderContainer(
  overrides: [repositoryProvider.overrideWithValue(repo)],
);

void main() {
  test('signup signs the device in without an email code', () async {
    final repo = FakeAuthRepository();
    final c = container(repo);
    addTearDown(c.dispose);
    final auth = c.read(authProvider.notifier);
    auth.signup();
    auth.phone('+959123456789');
    auth.email('owner@example.com');
    await auth.submit();
    expect(repo.registerCalls, 1);
    expect(c.read(authProvider).stage, 'home');
    expect(c.read(authProvider).otp, isEmpty);
  });

  test('known device logs in directly', () async {
    final repo = FakeAuthRepository();
    final c = container(repo);
    addTearDown(c.dispose);
    final auth = c.read(authProvider.notifier);
    auth.phone('+959123456789');
    await auth.submit();
    expect(c.read(authProvider).stage, 'home');
    expect(repo.emailVerifyCalls, 0);
  });

  test('unknown device falls back to email recovery only', () async {
    final repo = FakeAuthRepository(deviceMatches: false);
    final c = container(repo);
    addTearDown(c.dispose);
    final auth = c.read(authProvider.notifier);
    auth.phone('+959123456789');
    await auth.submit();
    expect(c.read(authProvider).stage, 'email');
    expect(repo.emailVerifyCalls, 0);
  });

  test('stored session continues at launch without a login screen', () async {
    final repo = FakeAuthRepository(canRestore: true);
    final c = container(repo);
    addTearDown(c.dispose);
    await c.read(authProvider.notifier).restore();
    expect(c.read(authProvider).stage, 'home');
    expect(c.read(authProvider).restoring, isFalse);
  });

  test('no stored session leaves the login screen up', () async {
    final repo = FakeAuthRepository();
    final c = container(repo);
    addTearDown(c.dispose);
    await c.read(authProvider.notifier).restore();
    expect(c.read(authProvider).stage, 'login');
    expect(c.read(authProvider).restoring, isFalse);
  });
}
