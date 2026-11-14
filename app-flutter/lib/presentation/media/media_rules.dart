import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

/// Client-side limits for §2.2. The Go media handler enforces the same numbers
/// server-side, so a client that lies is still rejected.
class MediaRules {
  const MediaRules._();
  static const maxImages = 4;
  static const maxVideoBytes = 25 * 1024 * 1024;
  static const maxVideoSeconds = 60;
  static const maxImageBytes = 10 * 1024 * 1024;
  static const imageMaxEdge = 1440;
  static const imageQuality = 82;

  static String? imagesRoom(int current, int adding) => current + adding >
          maxImages
      ? 'You can attach up to $maxImages photos.'
      : null;

  static String? validateVideo({required int bytes, required int seconds}) {
    if (bytes > maxVideoBytes) {
      return 'Video is ${(bytes / 1048576).toStringAsFixed(1)} MB — the limit is 25 MB.';
    }
    if (seconds > maxVideoSeconds) {
      return 'Video is ${seconds}s — the limit is 60s.';
    }
    if (seconds <= 0) return 'This video could not be read.';
    return null;
  }

  static bool isVideoPath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v');
  }

  static String humanSize(int bytes) => bytes >= 1048576
      ? '${(bytes / 1048576).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).round()} KB';
}

abstract interface class MediaSource {
  Future<List<String>> pickImages(int remaining);
  Future<String?> pickVideo();
  Future<String?> pickOneImage();
}

class PickerMediaSource implements MediaSource {
  PickerMediaSource([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<List<String>> pickImages(int remaining) async {
    if (remaining <= 0) return const [];
    final files = await _picker.pickMultiImage(
      imageQuality: 88,
      maxWidth: 2048,
      limit: remaining,
    );
    return files.map((f) => f.path).toList();
  }

  @override
  Future<String?> pickVideo() async {
    final file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: MediaRules.maxVideoSeconds),
    );
    return file?.path;
  }

  @override
  Future<String?> pickOneImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2048,
    );
    return file?.path;
  }
}

abstract interface class ImageCompressor {
  Future<String> compress(String path);
}

/// Re-encodes to WebP at 1440 px / q82 (~60-70% smaller than the camera
/// original), which is what keeps the upload light (§7).
class WebPImageCompressor implements ImageCompressor {
  const WebPImageCompressor();

  @override
  Future<String> compress(String path) async {
    if (MediaRules.isVideoPath(path)) return path;
    try {
      final dir = await getTemporaryDirectory();
      final target = '${dir.path}/nx_${const Uuid().v4()}.webp';
      final result = await FlutterImageCompress.compressAndGetFile(
        path,
        target,
        format: CompressFormat.webp,
        quality: MediaRules.imageQuality,
        minWidth: MediaRules.imageMaxEdge,
        minHeight: MediaRules.imageMaxEdge,
        keepExif: false,
      );
      return result?.path ?? path;
    } catch (_) {
      // Never block a post because the encoder is missing on this platform.
      return path;
    }
  }
}

/// Reads the clip length before upload so a 3-minute video is refused on the
/// device instead of after a 100 MB transfer.
Future<int> videoSeconds(String path) async {
  final controller = VideoPlayerController.file(File(path));
  try {
    await controller.initialize();
    return controller.value.duration.inSeconds;
  } catch (_) {
    return 0;
  } finally {
    await controller.dispose();
  }
}
