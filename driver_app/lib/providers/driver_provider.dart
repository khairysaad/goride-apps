import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../models/models.dart';

class DriverProvider extends ChangeNotifier {
  Driver? _driver;
  bool _isLoading = false;
  List<DriverVehicle> _vehicles = [];

  Driver? get driver => _driver;
  bool get isLoading => _isLoading;
  bool get isOnline => _driver?.isOnline ?? false;
  List<DriverVehicle> get vehicles => _vehicles;

  Future<void> loadProfile() async {
    try {
      final data = await ApiClient.instance.get('/driver/profile');
      _driver = Driver.fromJson(data['driver'] as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchVehicles() async {
    try {
      final data = await ApiClient.instance.get('/driver/vehicles');
      _vehicles = (data['vehicles'] as List)
          .map((e) => DriverVehicle.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> addVehicle({
    required int vehicleTypeId,
    required String make,
    required String model,
    required int year,
    required String plateNumber,
    String? color,
    int seats = 4,
  }) async {
    await ApiClient.instance.post('/driver/vehicles', data: {
      'vehicle_type_id': vehicleTypeId,
      'make': make,
      'model': model,
      'year': '$year',
      'plate_number': plateNumber,
      if (color != null && color.isNotEmpty) 'color': color,
      'seats': seats,
    });
    await fetchVehicles();
  }

  Future<void> setActiveVehicle(int vehicleId) async {
    await ApiClient.instance.post('/driver/vehicles/$vehicleId/active');
    await fetchVehicles();
  }

  Future<void> deleteVehicle(int vehicleId) async {
    await ApiClient.instance.delete('/driver/vehicles/$vehicleId');
    await fetchVehicles();
  }

  Future<void> apply({
    required String licenseNumber,
    required String nationalId,
    required String vehicleMake,
    required String vehicleModel,
    required int vehicleYear,
    required String vehiclePlate,
    required int vehicleTypeId,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.post('/driver/apply', data: {
        'license_number': licenseNumber,
        'national_id': nationalId,
        'vehicle_make': vehicleMake,
        'vehicle_model': vehicleModel,
        'vehicle_year': vehicleYear,
        'vehicle_plate': vehiclePlate,
        'vehicle_type_id': vehicleTypeId,
      });
      _driver = Driver.fromJson(data['driver'] as Map<String, dynamic>);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleAvailability() async {
    await ApiClient.instance.post('/driver/toggle-availability');
    await loadProfile();
  }

  Future<void> updateLocation(double lat, double lng) async {
    try {
      await ApiClient.instance.post('/driver/location', data: {'lat': lat, 'lng': lng});
    } catch (_) {}
  }
}