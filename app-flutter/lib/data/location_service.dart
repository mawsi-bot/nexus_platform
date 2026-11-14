import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// A device position captured at compose time.
///
/// The label is formatted from the real coordinates: the app never invents a
/// place name, and a failed fix is reported as "no fix" instead of showing a
/// hardcoded address.
class LocationFix {
  const LocationFix({required this.lat, required this.lng});
  final double lat;
  final double lng;
  String get label =>
      '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}';
}

abstract interface class LocationService {
  /// Returns null when location is unavailable or denied. Never throws: the
  /// composer must keep working without a fix.
  Future<LocationFix?> current();
}

class DeviceLocationService implements LocationService {
  const DeviceLocationService();

  @override
  Future<LocationFix?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LocationFix(lat: position.latitude, lng: position.longitude);
    } catch (_) {
      return null;
    }
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const DeviceLocationService(),
);

/// Resolved once per compose session; invalidate to re-request a fix.
final placeFixProvider = FutureProvider<LocationFix?>(
  (ref) => ref.watch(locationServiceProvider).current(),
);
