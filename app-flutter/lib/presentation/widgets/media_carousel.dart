import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../media/media_rules.dart';
import '../theme.dart';

/// Swipeable media block for a post (§2.1). One item renders edge-to-edge with
/// no chrome; two or more add a counter and page dots.
class MediaCarousel extends StatefulWidget {
  const MediaCarousel({
    super.key,
    required this.urls,
    this.height = 240,
    this.onTap,
  });
  final List<String> urls;
  final double height;
  final void Function(int index)? onTap;
  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    if (urls.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => widget.onTap?.call(i),
                child: _Frame(url: urls[i]),
              ),
            ),
            if (urls.length > 1)
              Positioned(
                right: 10,
                top: 10,
                child: _Pill(label: '${_index + 1}/${urls.length}'),
              ),
            if (urls.length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < urls.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: i == _index ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? Colors.white
                              : Colors.white.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

File _asFile(String path) => File(path);

class _Frame extends StatelessWidget {
  const _Frame({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) {
    final isVideo = MediaRules.isVideoPath(url);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: context.nx.surfaceTint,
          child: url.startsWith('http')
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: context.nx.textSecondary,
                    ),
                  ),
                )
              : Image.file(
                  // A locally picked file that has not been uploaded yet.
                  _asFile(url),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.image_outlined,
                    color: context.nx.textSecondary,
                  ),
                ),
        ),
        if (isVideo)
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .45),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: DesignTokens.meta.copyWith(color: Colors.white),
    ),
  );
}
