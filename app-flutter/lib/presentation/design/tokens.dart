import 'package:flutter/material.dart';

/// The single source of truth for Nexus visual design.
///
/// Every value here is normative and comes from the Production-Grade UI/UX
/// Architecture directive (§1.1 colour, §1.2 type/shape, §1.3 motion). Screens
/// must not declare colours, radii or font sizes of their own: a drift test
/// (`test/design_system_test.dart`) fails the build if these values change.
abstract final class DesignTokens {
  // §1.1 — Light-first palette. Dark tones exist only as media scrims.
  static const bgPrimary = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const accentBrand = Color(0xFFC2926B);
  static const danger = Color(0xFFFF453A);
  static const surfaceTint = Color(0xFFF3F4F6);

  /// Brand mark gradient — Logo Kit v1 §2 (135°/ForwardDiagonal). Reserved for
  /// the logo and brand surfaces; it is not a UI accent colour.
  static const brandBlueStart = Color(0xFF3D7BFF);
  static const brandBlueEnd = Color(0xFF1E4FD8);
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandBlueStart, brandBlueEnd],
  );

  /// Legibility scrim for text over media (§1.1 permits dark only here).
  static const mediaScrim = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xCC0B0F14), Color(0x590B0F14), Color(0x000B0F14)],
  );

  /// Neutral fallback artwork for media that has no image payload yet.
  static const photoFallback = 'assets/baseline.jpg';

  // §1.2 — Type scale.
  static const fontFamily = 'Inter';
  static const fallbackFont = 'Noto Sans Myanmar';
  static const screenTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: -0.2,
  );
  static const itemTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const meta = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: 0.1,
  );

  // §1.2 — Shapes.
  static const radiusCard = 16.0;
  static const radiusSheet = 16.0;
  static const radiusPill = 999.0;
  static const radiusInput = 12.0;

  // §1.3 — Motion (150–300 ms, ease-out).
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 300);
  static const easeOut = Curves.easeOutCubic;

  /// Elevation is expressed as a shadow rather than Material elevation so the
  /// light canvas keeps its flat, premium feel.
  static const cardShadow = [
    BoxShadow(color: Color(0x0A111827), blurRadius: 12, offset: Offset(0, 2)),
  ];
  static const railShadow = [
    BoxShadow(color: Color(0x1F111827), blurRadius: 8, offset: Offset(0, 2)),
  ];
}
