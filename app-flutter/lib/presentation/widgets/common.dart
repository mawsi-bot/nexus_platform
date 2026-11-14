import 'package:flutter/material.dart';

import '../theme.dart';

/// Brand mark for in-app headers. Light surfaces use the gradient mark; dark
/// media overlays use the reversed one (Logo Kit §5).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 28, this.reversed = false});
  final double size;
  final bool reversed;
  @override
  Widget build(BuildContext context) => Image.asset(
    reversed
        ? 'assets/brand/nexus-mark-reversed.png'
        : 'assets/brand/nexus-mark.png',
    height: size,
    width: size,
    filterQuality: FilterQuality.high,
    semanticLabel: 'Nexus',
  );
}

/// Horizontal lockup (mark + NEXUS + tagline) for a full brand statement.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.height = 44});
  final double height;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/brand/nexus-logo-lockup.png',
    height: height,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    semanticLabel: 'Nexus — Business & Community',
  );
}

class Photo extends StatelessWidget {
  const Photo({
    super.key,
    this.height,
    this.width,
    this.alignment = const Alignment(0, -.56),
    this.radius = 0,
    this.scale,
  });
  final double? height, width;
  final Alignment alignment;
  final double radius;

  /// Optional artwork zoom (1 = fit). Legacy name kept for older tests.
  final double? scale;
  double? get backgroundScale => scale;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Image.asset(
      DesignTokens.photoFallback,
      height: height,
      width: width,
      fit: BoxFit.cover,
      alignment: alignment,
    ),
  );
}

/// Media block with a legibility scrim — the only place dark tones are allowed.
class ScrimmedMedia extends StatelessWidget {
  const ScrimmedMedia({
    super.key,
    required this.height,
    this.radius = 12,
    this.child,
  });
  final double height;
  final double radius;
  final Widget? child;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Photo(),
          DecoratedBox(
            decoration: BoxDecoration(gradient: DesignTokens.mediaScrim),
          ),
          ?child,
        ],
      ),
    ),
  );
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.size = 36, this.ring = false, this.label});
  final double size;
  final bool ring;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final inner = ClipOval(child: Photo(width: size, height: size));
    return Container(
      padding: EdgeInsets.all(ring ? 2.5 : 0),
      decoration: ring
          ? const BoxDecoration(
              shape: BoxShape.circle,
              gradient: DesignTokens.brandGradient,
            )
          : null,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.nx.surface,
          border: ring ? null : Border.all(color: context.nx.border),
        ),
        child: ring ? inner : inner,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: DesignTokens.meta.copyWith(
              color: context.nx.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.label, this.size = 44});
  final IconData icon;
  final String? label;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: context.nx.surfaceTint,
      borderRadius: BorderRadius.circular(label == null ? 13 : size / 2),
      border: Border.all(color: context.nx.border),
    ),
    alignment: Alignment.center,
    child: label == null
        ? Icon(icon, color: context.nx.accentBrand, size: size * 0.46)
        : Text(
            label!,
            style: DesignTokens.itemTitle.copyWith(
              color: context.nx.accentBrand,
            ),
          ),
  );
}

class NativeInput extends StatelessWidget {
  const NativeInput({
    super.key,
    required this.value,
    required this.onChanged,
    required this.hint,
    this.maxLength,
    this.lines = 1,
    this.type,
    this.onSubmitted,
    this.inputKey,
    this.prefixIcon,
  });
  final String value, hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmitted;
  final int? maxLength;
  final int lines;
  final TextInputType? type;
  final Key? inputKey;
  final IconData? prefixIcon;
  @override
  Widget build(BuildContext context) => TextFormField(
    key: inputKey ?? ValueKey('$hint-${value.isEmpty}'),
    initialValue: value,
    onChanged: onChanged,
    maxLength: maxLength,
    maxLines: lines,
    keyboardType: type,
    onFieldSubmitted: (_) => onSubmitted?.call(),
    style: DesignTokens.body,
    decoration: InputDecoration(
      hintText: hint,
      counterText: '',
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, size: 19, color: context.nx.textSecondary),
    ),
  );
}

/// Kept for call sites that still render a chip row; the newer screens use
/// [Segmented] from `states.dart`.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.items,
    required this.value,
    required this.onSelect,
  });
  final List<String> items;
  final String value;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              label: Text(item),
              labelStyle: DesignTokens.meta.copyWith(
                color: item.toLowerCase() == value.toLowerCase()
                    ? Colors.white
                    : context.nx.textPrimary,
              ),
              selected: item.toLowerCase() == value.toLowerCase(),
              onSelected: (_) => onSelect(item.toLowerCase()),
              showCheckmark: false,
            ),
          ),
      ],
    ),
  );
}
