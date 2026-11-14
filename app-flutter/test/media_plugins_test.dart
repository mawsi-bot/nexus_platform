import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nexus/presentation/media/media_rules.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/plugins.dart';

class FakePicker extends ImagePicker {
  FakePicker({
    this.images = const [],
    this.multi = const [],
    this.video,
    this.fail = false,
  });
  final List<String> images;
  final List<String> multi;
  final String? video;
  final bool fail;
  int pickImageCalls = 0;
  int pickMultiCalls = 0;
  int pickVideoCalls = 0;
  int? lastLimit;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    pickImageCalls++;
    if (fail) throw PlatformExceptionStub();
    if (images.isEmpty) return null;
    return XFile(images.first);
  }

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    pickMultiCalls++;
    lastLimit = limit;
    if (fail) throw PlatformExceptionStub();
    return multi.map(XFile.new).toList();
  }

  @override
  Future<XFile?> pickVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async {
    pickVideoCalls++;
    if (fail) throw PlatformExceptionStub();
    return video == null ? null : XFile(video!);
  }
}

class PlatformExceptionStub implements Exception {
  const PlatformExceptionStub();
  @override
  String toString() => 'PlatformException(photo_access_denied)';
}

class FakeVideoPlatform extends VideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  FakeVideoPlatform({this.duration = const Duration(seconds: 42), this.broken = false});
  final Duration duration;
  final bool broken;
  int disposed = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async => 1;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => broken
      ? Stream<VideoEvent>.error(StateError('decoder failed'))
      : Stream<VideoEvent>.value(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: duration,
            size: const Size(1080, 1920),
          ),
        );

  @override
  Future<void> dispose(int playerId) async {
    disposed++;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildView(int playerId) => const SizedBox.shrink();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    VideoPlayerPlatform.instance = FakeVideoPlatform();
  });

  group('PickerMediaSource', () {
    test('nothing is returned when no slots remain', () async {
      final picker = FakePicker(multi: const ['/tmp/a.jpg']);
      final source = PickerMediaSource(picker);
      expect(await source.pickImages(0), isEmpty);
      expect(picker.pickMultiCalls, 0);
    });

    test('forwards the remaining slot count as a limit', () async {
      final picker = FakePicker(multi: const ['/tmp/a.jpg', '/tmp/b.jpg']);
      final source = PickerMediaSource(picker);
      final picked = await source.pickImages(2);
      expect(picked, ['/tmp/a.jpg', '/tmp/b.jpg']);
      expect(picker.lastLimit, 2);
    });

    test('video picker returns the path or null', () async {
      final withVideo = PickerMediaSource(FakePicker(video: '/tmp/clip.mp4'));
      expect(await withVideo.pickVideo(), '/tmp/clip.mp4');
      final without = PickerMediaSource(FakePicker());
      expect(await without.pickVideo(), isNull);
    });

    test('single image picker returns the path or null', () async {
      final one = PickerMediaSource(FakePicker(images: const ['/tmp/x.jpg']));
      expect(await one.pickOneImage(), '/tmp/x.jpg');
      final none = PickerMediaSource(FakePicker());
      expect(await none.pickOneImage(), isNull);
    });

    test('a denied permission error is not swallowed', () async {
      final source = PickerMediaSource(FakePicker(fail: true));
      expect(source.pickImages(2), throwsA(isA<PlatformExceptionStub>()));
      expect(source.pickVideo(), throwsA(isA<PlatformExceptionStub>()));
      expect(source.pickOneImage(), throwsA(isA<PlatformExceptionStub>()));
    });
  });

  group('videoSeconds', () {
    test('reads the clip duration from the player', () async {
      VideoPlayerPlatform.instance = FakeVideoPlatform(
        duration: const Duration(seconds: 47),
      );
      final path = '${Directory.systemTemp.path}/nexus_probe.mp4';
      await File(path).writeAsBytes(const [0, 0, 0, 24]);
      addTearDown(() => File(path).delete());
      expect(await videoSeconds(path), 47);
    });

    test('a 60s+ clip is refused by the rules', () async {
      expect(MediaRules.validateVideo(bytes: 1024, seconds: 61), isNotNull);
    });
  });

  group('WebPImageCompressor', () {
    test('a video is passed through untouched', () async {
      const compressor = WebPImageCompressor();
      expect(await compressor.compress('/tmp/movie.mp4'), '/tmp/movie.mp4');
    });

    test('an image never blocks the post when encoding is unavailable',
        () async {
      final dir = await Directory.systemTemp.createTemp('nexus_compress');
      addTearDown(() => dir.delete(recursive: true));
      installPathProvider(dir.path);
      final src = '${dir.path}/photo.jpg';
      await File(src).writeAsBytes(const [0xFF, 0xD8, 0xFF, 0xE0]);

      // No flutter_image_compress plugin is registered in the test binding, so
      // the real code path takes its fallback branch and keeps the original.
      final out = await const WebPImageCompressor().compress(src);
      expect(out, isNotEmpty);
      expect(File(out).existsSync(), isTrue);
      clearMock(pathProviderChannel);
    });
  });
}
