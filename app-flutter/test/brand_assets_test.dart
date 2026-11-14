import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Logo Kit installation. Every path below is a launch requirement:
/// a missing icon file only surfaces at build or store-upload time, so it is
/// asserted here instead.
void main() {
  test('in-app marks live in assets/brand', () {
    for (final name in [
      'nexus-mark.png',
      'nexus-mark-reversed.png',
      'nexus-mark-mono.png',
      'nexus-logo-lockup.png',
      'nexus-icon.png',
    ]) {
      expect(
        File('assets/brand/$name').existsSync(),
        isTrue,
        reason: 'missing brand asset $name',
      );
    }
  });

  test('pubspec ships the brand directory and the Inter family', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/brand/'));
    expect(pubspec, contains('family: Inter'));
  });

  test('Android launcher icons exist for every density', () {
    const required = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final entry in required.entries) {
      final base = 'android/app/src/main/res/mipmap-${entry.key}';
      for (final file in [
        'ic_launcher.png',
        'ic_launcher_foreground.png',
        'ic_launcher_monochrome.png',
      ]) {
        expect(File('$base/$file').existsSync(), isTrue, reason: '$base/$file');
      }
    }
    final adaptive = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(adaptive, contains('<foreground'));
    expect(adaptive, contains('<monochrome'));
  });

  test('iOS AppIcon.appiconset declares only files that exist', () {
    final dir = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
    final contents = File('${dir.path}/Contents.json').readAsStringSync();
    final names = RegExp(r'"filename"\s*:\s*"([^"]+)"')
        .allMatches(contents)
        .map((m) => m.group(1)!)
        .toSet();
    expect(names, isNotEmpty);
    for (final name in names) {
      expect(File('${dir.path}/$name').existsSync(), isTrue, reason: name);
    }
    // App Store requires the 1024 marketing icon.
    expect(contents, contains('Icon-App-1024x1024@1x.png'));
  });

  test('web icons are published at the documented paths', () {
    for (final name in [
      'favicon.ico',
      'favicon.png',
      'Icon-192.png',
      'Icon-512.png',
      'apple-touch-icon.png',
      'og-image.png',
      'manifest.json',
      'index.html',
    ]) {
      expect(File('web/$name').existsSync(), isTrue, reason: 'web/$name');
    }
    final manifest = File('web/manifest.json').readAsStringSync();
    expect(manifest, contains('Icon-192.png'));
    expect(manifest, contains('Icon-512.png'));
    expect(manifest, contains('#F8F9FA'));
    final index = File('web/index.html').readAsStringSync();
    expect(index, contains('favicon.ico'));
    expect(index, contains('og-image.png'));
  });
}
