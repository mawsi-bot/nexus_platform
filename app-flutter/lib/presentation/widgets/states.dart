import 'package:flutter/material.dart';

import '../theme.dart';

/// Turns any thrown object into copy a customer may read.
///
/// Raw `ClientException`, `FormatException` or backend `Unsupported operation…`
/// strings must never reach the UI (Directive §3/§4), so every failure path
/// funnels through here.
String friendlyError(Object error) {
  final raw = error.toString().toLowerCase();
  if (raw.contains('timeout') || raw.contains('unavailable')) {
    return 'The connection is slow right now. Please try again.';
  }
  if (raw.contains('socket') ||
      raw.contains('clientexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('connection')) {
    return 'You appear to be offline. Check your connection and retry.';
  }
  if (raw.contains('401') || raw.contains('unauthor') || raw.contains('login')) {
    return 'Your session has ended. Please sign in again.';
  }
  if (raw.contains('429') || raw.contains('rate')) {
    return 'Too many attempts. Please wait a moment and retry.';
  }
  if (raw.contains('unsupported') || raw.contains('unmapped')) {
    return 'This part of Nexus is not available yet.';
  }
  if (raw.contains('format')) {
    return 'We could not read the response. Please retry.';
  }
  return 'Something went wrong. Please retry.';
}

/// A deliberate, illustrated empty state with a single call to action (§3).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.bubble_chart_outlined,
    this.ctaLabel,
    this.onCta,
  });
  final String title, message;
  final IconData icon;
  final String? ctaLabel;
  final VoidCallback? onCta;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Illustration(icon: icon),
          SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: DesignTokens.itemTitle,
          ),
          SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: DesignTokens.body.copyWith(
              color: context.nx.textSecondary,
            ),
          ),
          if (ctaLabel != null) ...[
            SizedBox(height: 20),
            FilledButton(onPressed: onCta, child: Text(ctaLabel!)),
          ],
        ],
      ),
    ),
  );
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 104,
    height: 104,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: context.nx.surfaceTint,
    ),
    alignment: Alignment.center,
    child: Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.nx.surface,
        border: Border.all(color: context.nx.border),
        boxShadow: DesignTokens.cardShadow,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 28, color: context.nx.accentBrand),
    ),
  );
}

/// Failure state with retry — never a raw exception string (§3).
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off_outlined,
    title: 'Something went wrong',
    message: friendlyError(error),
    ctaLabel: onRetry == null ? null : 'Retry',
    onCta: onRetry,
  );
}

/// Animated shimmer used by every skeleton placeholder (§1.3).
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment(-1 - 2 * _controller.value, 0),
        end: Alignment(1 - 2 * _controller.value, 0),
        colors: [
          context.nx.surfaceTint,
          Color(0xFFE9EBEF),
          context.nx.surfaceTint,
        ],
      ).createShader(bounds),
      child: child,
    ),
    child: widget.child,
  );
}

/// A single skeleton block.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.height = 12,
    this.width,
    this.radius = 8,
  });
  final double height;
  final double? width;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: context.nx.surfaceTint,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Feed/card skeleton: header, two lines, media block, action row.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.media = true});
  final bool media;
  @override
  Widget build(BuildContext context) => Shimmer(
    child: Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.nx.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(color: context.nx.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(height: 36, width: 36, radius: 18),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 11, width: 120)),
            ],
          ),
          SizedBox(height: 14),
          SkeletonBox(height: 13, width: double.infinity),
          SizedBox(height: 8),
          SkeletonBox(height: 13, width: 220),
          if (media) ...[
            SizedBox(height: 14),
            SkeletonBox(height: 180, width: double.infinity, radius: 12),
          ],
          SizedBox(height: 14),
          Row(
            children: [
              SkeletonBox(height: 14, width: 46),
              SizedBox(width: 18),
              SkeletonBox(height: 14, width: 46),
              SizedBox(width: 18),
              SkeletonBox(height: 14, width: 46),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Segmented control used by Feed and Discover (§2.1, §2.2).
class Segmented extends StatelessWidget {
  const Segmented({
    super.key,
    required this.items,
    required this.value,
    required this.onSelect,
    this.expand = true,
  });
  final List<String> items;
  final String value;
  final ValueChanged<String> onSelect;
  final bool expand;
  @override
  Widget build(BuildContext context) {
    final children = [
      for (final item in items)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(item.toLowerCase()),
          child: AnimatedContainer(
            duration: DesignTokens.fast,
            curve: DesignTokens.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: item.toLowerCase() == value.toLowerCase()
                  ? context.nx.surface
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
              boxShadow: item.toLowerCase() == value.toLowerCase()
                  ? DesignTokens.cardShadow
                  : null,
            ),
            child: Text(
              item,
              textAlign: TextAlign.center,
              style: DesignTokens.meta.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: item.toLowerCase() == value.toLowerCase()
                    ? context.nx.textPrimary
                    : context.nx.textSecondary,
              ),
            ),
          ),
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.nx.surfaceTint,
        borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final child in children)
            expand ? Expanded(child: child) : child,
        ],
      ),
    );
  }
}

/// Small distance/place pill (§2.2).
class MetaPill extends StatelessWidget {
  const MetaPill({super.key, required this.label, this.icon = Icons.place});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: context.nx.surfaceTint,
      borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: DesignTokens.meta.copyWith(color: context.nx.textSecondary),
        ),
      ],
    ),
  );
}

/// Verified business badge (§2.3).
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 16});
  final double size;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Verified business',
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.nx.accentBrand,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.check, size: size * 0.68, color: Colors.white),
    ),
  );
}
