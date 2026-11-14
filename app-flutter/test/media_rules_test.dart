import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/presentation/media/media_rules.dart';

void main() {
  test('image slots are capped at four', () {
    expect(MediaRules.imagesRoom(0, 1), isNull);
    expect(MediaRules.imagesRoom(3, 1), isNull);
    expect(MediaRules.imagesRoom(4, 1), contains('up to 4'));
    expect(MediaRules.maxImages, 4);
  });

  test('video validation covers size, length and unreadable files', () {
    expect(MediaRules.validateVideo(bytes: 1024, seconds: 10), isNull);
    expect(
      MediaRules.validateVideo(bytes: 26 * 1024 * 1024, seconds: 10),
      contains('25 MB'),
    );
    expect(
      MediaRules.validateVideo(bytes: 1024, seconds: 61),
      contains('60s'),
    );
    expect(MediaRules.validateVideo(bytes: 1024, seconds: 0), isNotNull);
  });

  test('video paths and human sizes', () {
    expect(MediaRules.isVideoPath('/a/b.MP4'), isTrue);
    expect(MediaRules.isVideoPath('/a/b.mov'), isTrue);
    expect(MediaRules.isVideoPath('/a/b.webp'), isFalse);
    expect(MediaRules.humanSize(2 * 1024 * 1024), '2.0 MB');
    expect(MediaRules.humanSize(512 * 1024), '512 KB');
  });

  test('webp compressor leaves videos untouched', () async {
    const compressor = WebPImageCompressor();
    expect(await compressor.compress('/tmp/clip.mp4'), '/tmp/clip.mp4');
  });
}
