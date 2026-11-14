import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/nexus_controller.dart';
import '../media/media_providers.dart';
import '../media/media_rules.dart';
import '../theme.dart';
import 'location_tile.dart';
import 'mention.dart';

/// Post composer (§2): text, up to four photos or one 25 MB / 60 s video.
class ComposerSheet extends ConsumerStatefulWidget {
  const ComposerSheet({super.key});
  @override
  ConsumerState<ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends ConsumerState<ComposerSheet> {
  String? _notice;

  Future<void> _addImages() async {
    final s = ref.read(nexusProvider);
    final room = MediaRules.maxImages - s.draftMedia.length;
    final problem = MediaRules.imagesRoom(s.draftMedia.length, 1);
    if (room <= 0) {
      setState(() => _notice = problem);
      return;
    }
    final picked = await ref.read(mediaSourceProvider).pickImages(room);
    final compressor = ref.read(imageCompressorProvider);
    for (final path in picked.take(room)) {
      ref
          .read(nexusProvider.notifier)
          .addDraftMedia(await compressor.compress(path));
    }
    if (mounted) setState(() => _notice = null);
  }

  Future<void> _addVideo() async {
    final path = await ref.read(mediaSourceProvider).pickVideo();
    if (path == null) return;
    final bytes = await File(path).length();
    final seconds = await videoSeconds(path);
    final problem = MediaRules.validateVideo(bytes: bytes, seconds: seconds);
    if (problem != null) {
      setState(() => _notice = problem);
      return;
    }
    final c = ref.read(nexusProvider.notifier);
    c.clearDraftMedia();
    c.addDraftMedia(path);
    if (mounted) setState(() => _notice = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(nexusProvider), c = ref.read(nexusProvider.notifier);
    final hasVideo = s.draftMedia.any(MediaRules.isVideoPath);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          s.repost == null ? 'Share something' : 'Share to your profile',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          s.repost == null
              ? 'Text, photos or one short video — your choice.'
              : 'Add your own words — the original stays credited',
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in const [
                ('feel', 'Feeling', Icons.favorite),
                ('photo', 'Photo', Icons.photo_camera),
                ('loc', 'Nearby', Icons.place),
                ('biz', 'Business', Icons.storefront),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    selected: s.kind == item.$1,
                    onSelected: (_) => c.kind(item.$1),
                    avatar: Icon(item.$3, size: 18),
                    label: Text(item.$2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        MentionInput(
          value: s.draft,
          onChanged: c.draft,
          lines: 3,
          maxLength: 200,
          candidates: s.mentionCandidates,
          hint: s.kind == 'feel'
              ? 'Share why you feel ${s.mood.toLowerCase()}…'
              : s.kind == 'loc'
              ? 'What makes this place worth a visit?'
              : 'Add a caption for your photo…',
        ),
        if (s.kind == 'feel')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 7,
              children: [
                for (final mood in const [
                  'Grateful',
                  'Hopeful',
                  'Missing home',
                  'Tired',
                  'Proud',
                ])
                  ChoiceChip(
                    selected: s.mood == mood,
                    onSelected: (_) => c.mood(mood),
                    label: Text(mood),
                  ),
              ],
            ),
          ),
        if (s.draftMedia.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: s.draftMedia.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final path = s.draftMedia[i];
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusInput,
                      ),
                      child: hasVideo
                          ? Container(
                              width: 132,
                              height: 84,
                              color: context.nx.surfaceTint,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.play_circle_fill,
                                color: context.nx.accentBrand,
                              ),
                            )
                          : Image.file(
                              File(path),
                              width: 84,
                              height: 84,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 84,
                                height: 84,
                                color: context.nx.surfaceTint,
                                child: Icon(
                                  Icons.image_outlined,
                                  color: context.nx.textSecondary,
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => c.removeDraftMedia(path),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: context.nx.textPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            TextButton.icon(
              onPressed: hasVideo ? null : _addImages,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text('Photos ${s.draftMedia.length}/${MediaRules.maxImages}'),
            ),
            TextButton.icon(
              onPressed: s.draftMedia.isEmpty ? _addVideo : null,
              icon: const Icon(Icons.videocam_outlined, size: 18),
              label: const Text('Video'),
            ),
          ],
        ),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _notice!,
              style: DesignTokens.meta.copyWith(color: context.nx.danger),
            ),
          ),
        const LocationTile(),
        FilledButton(
          onPressed: ref.watch(canPostProvider)
              ? () async {
                  await c.publish();
                  if (context.mounted &&
                      ref.read(nexusProvider).error == null) {
                    Navigator.pop(context);
                  }
                }
              : null,
          child: Text(
            s.repost != null
                ? 'Share post'
                : s.kind == 'feel'
                ? 'Post to Nearby'
                : s.kind == 'loc'
                ? 'Share this place'
                : 'Post photo',
          ),
        ),
      ],
    );
  }
}
