import 'package:flutter/material.dart';

/// The complete token set as a [ThemeExtension].
///
/// Light and dark are two instances of the same shape, so a widget asks the
/// active theme for colours instead of importing constants. That is what makes
/// §1.3 (theme switching) work: change `themeMode` and every screen repaints.
@immutable
class NexusColors extends ThemeExtension<NexusColors> {
  const NexusColors({
    required this.bgPrimary,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.accentBrand,
    required this.danger,
    required this.surfaceTint,
    required this.onAccent,
  });

  final Color bgPrimary;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color accentBrand;
  final Color danger;
  final Color surfaceTint;
  final Color onAccent;

  /// §1.1 light-first palette — the normative values.
  static const light = NexusColors(
    bgPrimary: Color(0xFFF8F9FA),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
    accentBrand: Color(0xFFC2926B),
    danger: Color(0xFFFF453A),
    surfaceTint: Color(0xFFF3F4F6),
    onAccent: Color(0xFFFFFFFF),
  );

  /// Dark counterpart. The accent keeps its hue so brand recognition survives.
  static const dark = NexusColors(
    bgPrimary: Color(0xFF0B0F14),
    surface: Color(0xFF151A21),
    textPrimary: Color(0xFFF3F4F6),
    textSecondary: Color(0xFF9AA3AF),
    border: Color(0xFF262D36),
    accentBrand: Color(0xFFD3A47C),
    danger: Color(0xFFFF6B61),
    surfaceTint: Color(0xFF1E242C),
    onAccent: Color(0xFF111827),
  );

  @override
  NexusColors copyWith({
    Color? bgPrimary,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? accentBrand,
    Color? danger,
    Color? surfaceTint,
    Color? onAccent,
  }) => NexusColors(
    bgPrimary: bgPrimary ?? this.bgPrimary,
    surface: surface ?? this.surface,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    border: border ?? this.border,
    accentBrand: accentBrand ?? this.accentBrand,
    danger: danger ?? this.danger,
    surfaceTint: surfaceTint ?? this.surfaceTint,
    onAccent: onAccent ?? this.onAccent,
  );

  @override
  NexusColors lerp(ThemeExtension<NexusColors>? other, double t) {
    if (other is! NexusColors) return this;
    return NexusColors(
      bgPrimary: Color.lerp(bgPrimary, other.bgPrimary, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      accentBrand: Color.lerp(accentBrand, other.accentBrand, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      surfaceTint: Color.lerp(surfaceTint, other.surfaceTint, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

/// `context.nx` is the one way widgets read colours.
extension NexusColorsX on BuildContext {
  NexusColors get nx =>
      Theme.of(this).extension<NexusColors>() ?? NexusColors.light;
}
