import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media_rules.dart';

final mediaSourceProvider = Provider<MediaSource>((ref) => PickerMediaSource());
final imageCompressorProvider = Provider<ImageCompressor>(
  (ref) => const WebPImageCompressor(),
);
