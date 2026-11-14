import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/presentation/theme.dart';
import 'package:nexus/presentation/widgets/states.dart';

/// Drift guard for the design system. Any change to a normative token fails
/// here first, because the directive fixes these values (§1.1–1.3).
void main() {
  test('palette matches the directive byte for byte', () {
    expect(DesignTokens.bgPrimary, const Color(0xFFF8F9FA));
    expect(DesignTokens.surface, const Color(0xFFFFFFFF));
    expect(DesignTokens.textPrimary, const Color(0xFF111827));
    expect(DesignTokens.textSecondary, const Color(0xFF6B7280));
    expect(DesignTokens.border, const Color(0xFFE5E7EB));
    expect(DesignTokens.accentBrand, const Color(0xFFC2926B));
    expect(DesignTokens.danger, const Color(0xFFFF453A));
    expect(DesignTokens.surfaceTint, const Color(0xFFF3F4F6));
  });

  test('type scale, radii and motion', () {
    expect(DesignTokens.screenTitle.fontSize, 19);
    expect(DesignTokens.screenTitle.fontWeight, FontWeight.w800);
    expect(DesignTokens.itemTitle.fontSize, 15);
    expect(DesignTokens.itemTitle.fontWeight, FontWeight.w700);
    expect(DesignTokens.body.fontSize, 14);
    expect(DesignTokens.body.fontWeight, FontWeight.w400);
    expect(DesignTokens.meta.fontSize, 11.5);
    expect(DesignTokens.meta.fontWeight, FontWeight.w600);
    expect(DesignTokens.radiusCard, 16);
    expect(DesignTokens.radiusSheet, 16);
    expect(DesignTokens.radiusPill, 999);
    expect(DesignTokens.radiusInput, 12);
    for (final d in [DesignTokens.fast, DesignTokens.base, DesignTokens.slow]) {
      expect(d.inMilliseconds, inInclusiveRange(150, 300));
    }
  });

  test('the app theme is light-first and carries the tokens', () {
    final theme = buildTheme();
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, DesignTokens.bgPrimary);
    expect(theme.colorScheme.primary, DesignTokens.accentBrand);
    expect(theme.colorScheme.error, DesignTokens.danger);
    expect(theme.cardTheme.color, DesignTokens.surface);
    expect(theme.textTheme.titleLarge?.fontSize, 19);
  });

  test('no raw error text can reach the user', () {
    for (final raw in [
      'ClientException: Connection refused',
      'Unsupported operation: Backend does not persist post type',
      'FormatException: Unexpected character',
      'SocketException: Failed host lookup',
      'ApiException(429, rate_limited)',
      'ApiException(401, unauthorized)',
    ]) {
      final message = friendlyError(raw);
      expect(message.toLowerCase(), isNot(contains('exception')));
      expect(message.toLowerCase(), isNot(contains('unsupported')));
      expect(message, isNot(contains('(')));
      expect(message, isNotEmpty);
    }
  });
}
