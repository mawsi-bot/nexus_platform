import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the OS-level location permissions the composer depends on.
/// A missing key is invisible in `flutter test` and only fails on a real
/// device or at App Store review, so it is asserted here.
void main() {
  test('Android declares foreground location permissions only', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.permission.ACCESS_FINE_LOCATION'));
    expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
    // Background location needs its own Play policy review; assert that no
    // <uses-permission> element declares it (comments may still name it).
    final background = RegExp(
      r'<uses-permission[^>]*ACCESS_BACKGROUND_LOCATION',
    );
    expect(background.hasMatch(manifest), isFalse);
    expect(manifest, contains('android.hardware.location.gps'));
  });

  test('iOS declares a when-in-use usage description', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('NSLocationWhenInUseUsageDescription'));
    // The always/background key would trigger an unnecessary App Store review.
    expect(plist, isNot(contains('NSLocationAlwaysAndWhenInUseUsageDescription')));
  });
}
