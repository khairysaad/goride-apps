import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/location/location_service.dart';

class LocationProvider extends ChangeNotifier {
  LocationAccess _access = LocationAccess.unknown;
  Position? _current;

  LocationAccess get access => _access;
  Position? get current => _current;

  Future<LocationAccess> requestLocation(BuildContext context) async {
    final prev = _access;
    _access = await LocationService.requestWithRationale(context);
    if (_access == LocationAccess.granted) {
      await _capture();
    } else if (prev == LocationAccess.granted) {
      _current = null;
    }
    notifyListeners();
    return _access;
  }

  Future<void> _capture() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _current = pos;
    } catch (_) {
      _current = null;
    }
  }

  Future<void> refresh() async {
    _access = await LocationService.checkAccess();
    if (_access == LocationAccess.granted) {
      await _capture();
    }
    notifyListeners();
  }

  Future<void> clear() async {
    _current = null;
    _access = LocationAccess.unknown;
    notifyListeners();
  }
}