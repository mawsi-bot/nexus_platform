import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/api_client.dart';
import 'package:nexus/data/scoped_repository.dart';
import 'package:nexus/domain/repository.dart';


class ScopedRepo implements NexusRepository {
  final calls = <String>[];
  @override
  bool get isDemo => false;
  @override
  void cancelPending() {
    calls.add('cancelPending');
  }
  @override
  Future<Map<String, dynamic>> deviceLogin(String phone) async {
    calls.add('deviceLogin');
    return {'_status': 200};
  }

  @override
  Future<void> emailVerify(String phone, String email) async {
    calls.add('email');
  }
  @override
  Future<void> confirm(String otp) async {
    calls.add('confirm');
  }
  @override
  Future<Map<String, dynamic>> register(String p, String e) async {
    calls.add('register');
    return {};
  }

  @override
  Future<bool> restoreSession() async {
    calls.add('restore');
    return true;
  }

  @override
  Future<String> uploadMedia(String filePath) async {
    calls.add('upload');
    return '/api/v1/media/x';
  }

  @override
  Future<String?> currentDeviceId() async {
    calls.add('device');
    return 'dev';
  }

  @override
  Future<void> logout() async {
    calls.add('logout');
  }
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const {},
  }) async {
    calls.add('get ${path.trim()}');
    return {};
  }

  @override
  Future<Map<String, dynamic>> send(
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
  }) async {
    calls.add('send ${path.trim()}');
    return {'id': '1'};
  }
}

void main() {
  group('ScopedRepository', () {
    test('forwards every call while the account is active', () async {
      final inner = ScopedRepo();
      var active = true;
      final repo = ScopedRepository(inner, () => active);
      expect(repo.isDemo, isFalse);
      repo.cancelPending();
      await repo.deviceLogin('+959');
      await repo.emailVerify('+959', 'a@b.co');
      await repo.confirm('otp');
      await repo.register('+959', 'a@b.co');
      expect(await repo.restoreSession(), isTrue);
      expect(await repo.uploadMedia('/tmp/a.webp'), '/api/v1/media/x');
      expect(await repo.currentDeviceId(), 'dev');
      await repo.get('/feed');
      await repo.send('/feed', const {});
      await repo.logout();
      expect(inner.calls, contains('deviceLogin'));
      expect(inner.calls, contains('send /feed'));
      active = false;
    });

    test('throws RequestCancelled once the account is gone', () async {
      final repo = ScopedRepository(ScopedRepo(), () => false);
      expect(repo.get('/feed'), throwsA(isA<RequestCancelled>()));
      expect(repo.send('/feed', const {}), throwsA(isA<RequestCancelled>()));
      expect(repo.deviceLogin('+959'), throwsA(isA<RequestCancelled>()));
      expect(repo.uploadMedia('/tmp/a'), throwsA(isA<RequestCancelled>()));
      expect(repo.register('+959', 'a@b.co'), throwsA(isA<RequestCancelled>()));
      expect(repo.confirm('x'), throwsA(isA<RequestCancelled>()));
      expect(repo.emailVerify('+959', 'a@b.co'), throwsA(isA<RequestCancelled>()));
    });

    test('cancels a response that lands after the account was dropped', () async {
      var active = true;
      final slow = ScopedRepo();
      final repo = ScopedRepository(slow, () => active);
      final pending = repo.get('/feed');
      active = false;
      await expectLater(pending, throwsA(isA<RequestCancelled>()));
      expect(slow.calls, contains('get /feed'));
    });
  });

}
