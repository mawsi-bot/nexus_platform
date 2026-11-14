import 'package:flutter/material.dart';

import 'design/nexus_colors.dart';
import 'design/tokens.dart';

export 'design/nexus_colors.dart';
export 'design/tokens.dart';

/// Backwards-compatible façade.
///
/// The old dark tokens are gone; every field below now resolves to the light
/// design system so legacy call sites keep compiling while they are migrated to
/// `DesignTokens` directly.
abstract final class Tokens {
  static const canvas = DesignTokens.bgPrimary;
  static const canvasHi = DesignTokens.surfaceTint;
  static const ink = DesignTokens.textPrimary;
  static const deep = DesignTokens.textPrimary;
  static const soft = DesignTokens.surface;
  static const card = DesignTokens.surface;
  static const card2 = DesignTokens.surfaceTint;
  static const pill = DesignTokens.border;
  static const muted = DesignTokens.textSecondary;
  static const tan = DesignTokens.accentBrand;
  static const alert = DesignTokens.danger;
  static const paper = DesignTokens.bgPrimary;
  static const line = DesignTokens.border;
  static const surface = DesignTokens.bgPrimary;
  static const photo = 'assets/baseline.jpg';

  static ThemeData get theme => buildTheme(Brightness.light);
  static ThemeData get dark => buildTheme(Brightness.dark);
}

ThemeData buildTheme([Brightness brightness = Brightness.light]) {
  final nx = brightness == Brightness.dark ? NexusColors.dark : NexusColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: nx.accentBrand,
    onPrimary: nx.onAccent,
    secondary: nx.textPrimary,
    onSecondary: nx.surface,
    surface: nx.surface,
    onSurface: nx.textPrimary,
    error: nx.danger,
    onError: Colors.white,
    outline: nx.border,
    outlineVariant: nx.surfaceTint,
    surfaceContainerHighest: nx.surfaceTint,
    onSurfaceVariant: nx.textSecondary,
    inverseSurface: nx.textPrimary,
    onInverseSurface: nx.surface,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: nx.bgPrimary,
    canvasColor: nx.bgPrimary,
    textTheme: base.textTheme
        .apply(
          bodyColor: nx.textPrimary,
          displayColor: nx.textPrimary,
          fontFamily: DesignTokens.fontFamily,
          fontFamilyFallback: [DesignTokens.fallbackFont],
        )
        .copyWith(
          headlineSmall: DesignTokens.screenTitle,
          titleLarge: DesignTokens.screenTitle,
          titleMedium: DesignTokens.itemTitle,
          bodyLarge: DesignTokens.body,
          bodyMedium: DesignTokens.body,
          labelSmall: DesignTokens.meta,
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: nx.surface,
      foregroundColor: nx.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: DesignTokens.screenTitle,
    ),
    dividerTheme: DividerThemeData(
      color: nx.border,
      thickness: 1,
      space: 1,
    ),
    cardTheme: CardThemeData(
      color: nx.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        side: BorderSide(color: nx.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: nx.accentBrand,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 46),
        textStyle: DesignTokens.itemTitle.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: nx.textPrimary,
        minimumSize: const Size(0, 46),
        side: BorderSide(color: nx.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: nx.accentBrand,
        textStyle: DesignTokens.itemTitle,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: nx.surfaceTint,
      hintStyle: DesignTokens.body.copyWith(color: nx.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
        borderSide: BorderSide(color: nx.accentBrand, width: 1.4),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: nx.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: nx.border,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusSheet),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: nx.surfaceTint,
      selectedColor: nx.accentBrand,
      side: BorderSide.none,
      labelStyle: DesignTokens.meta.copyWith(color: nx.textPrimary),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: nx.textPrimary,
      contentTextStyle: DesignTokens.body.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: nx.accentBrand, linearTrackColor: nx.surfaceTint),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(backgroundColor: nx.surface, selectedItemColor: nx.textPrimary, unselectedItemColor: nx.textSecondary, type: BottomNavigationBarType.fixed, elevation: 0),
  ).copyWith(
    extensions: <ThemeExtension<dynamic>>[nx],
  );
}
