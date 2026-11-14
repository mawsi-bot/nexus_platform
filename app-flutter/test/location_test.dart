import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/location_service.dart';

import 'support/plugins.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => clearMock(geolocatorChannel));

  group('DeviceLocationService', () {
    test('returns a fix when location is enabled and granted', () async {
      installGeolocator(position: fakePosition(lat: 16.84, lng: 96.17));
      final fix = await const DeviceLocationService().current();
      expect(fix, isNotNull);
      expect(fix!.lat, closeTo(16.84, 1e-9));
      expect(fix.label, '16.840, 96.170');
    });

    test('requests permission once and uses the grant', () async {
      installGeolocator(
        permission: 0,
        afterRequest: 2,
        position: fakePosition(),
      );
      expect(await const DeviceLocationService().current(), isNotNull);
    });

    test('returns null when the service is switched off', () async {
      installGeolocator(serviceEnabled: false);
      expect(await const DeviceLocationService().current(), isNull);
    });

    test('returns null when permission stays denied', () async {
      installGeolocator(permission: 0, afterRequest: 0);
      expect(await const DeviceLocationService().current(), isNull);
    });

    test('returns null when permission is denied forever', () async {
      installGeolocator(permission: 1, afterRequest: 1);
      expect(await const DeviceLocationService().current(), isNull);
    });

    test('never throws when the platform call fails', () async {
      installGeolocator(throwOnCall: true);
      expect(await const DeviceLocationService().current(), isNull);
    });
  });

  test('placeFixProvider resolves through the service', () async {
    installGeolocator(position: fakePosition());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(placeFixProvider.future), isNotNull);
  });

  test('LocationFix formats three decimals', () {
    expect(const LocationFix(lat: -1.23456, lng: 2.34567).label, '-1.235, 2.346');
  });
}
