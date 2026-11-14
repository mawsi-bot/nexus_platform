import 'models.dart';

abstract interface class NexusRepository {
  bool get isDemo;
  void cancelPending();
  Future<Map<String, dynamic>> deviceLogin(String phone);
  Future<void> emailVerify(String phone, String email);
  Future<void> confirm(String otp);
  Future<Map<String, dynamic>> register(String phone, String email);
  /// Silently continues a stored session at app launch. Returns false when the
  /// device has no usable session, so the caller shows the login screen.
  Future<bool> restoreSession();
  Future<void> logout();

  /// Uploads a local file and returns the media reference to attach to a post
  /// or message (`/api/v1/media/<id>`).
  Future<String> uploadMedia(String filePath);

  /// Installation id for the current device (Settings → Devices).
  Future<String?> currentDeviceId();
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const {},
  });
  Future<Map<String, dynamic>> send(
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
  });
}

List<Post> rankPosts(List<Post> posts, String filter) {
  final list = posts
      .where((p) => filter != 'nearby' || p.nearby || p.friend)
      .toList();
  list.sort((a, b) {
    if (filter == 'nearby' && a.friend != b.friend) return a.friend ? -1 : 1;
    return b.score.compareTo(a.score);
  });
  return List.unmodifiable(list);
}

String? validatePhone(String phone) =>
    RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)
    ? null
    : 'Enter an international phone number, starting with +.';
String? validateEmail(String email) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) && email.length <= 254
    ? null
    : 'Enter a valid recovery email.';
String? validateOtp(String otp) =>
    RegExp(r'^[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}$').hasMatch(otp)
    ? null
    : 'Paste the complete 66-character verification capability from your email.';
