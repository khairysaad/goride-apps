import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../models/models.dart';

class FavoritesProvider extends ChangeNotifier {
  List<FavoritePlace> _places = [];
  List<FavoriteDriverItem> _drivers = [];
  bool _loading = false;

  List<FavoritePlace> get places => _places;
  List<FavoriteDriverItem> get drivers => _drivers;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final p = await ApiClient.instance.get('/favorites/places');
      _places = (p['places'] as List)
          .map((e) => FavoritePlace.fromJson(e as Map<String, dynamic>))
          .toList();
      final d = await ApiClient.instance.get('/favorites/drivers');
      _drivers = (d['drivers'] as List)
          .map((e) => FavoriteDriverItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addPlace({
    required String name,
    required String address,
    required double lat,
    required double lng,
    int type = 2,
  }) async {
    await ApiClient.instance.post('/favorites/places', data: {
      'name': name,
      'address': address,
      'lat': lat,
      'lng': lng,
      'type': type,
    });
    await load();
  }

  Future<void> removePlace(int id) async {
    await ApiClient.instance.delete('/favorites/places/$id');
    await load();
  }

  Future<void> addDriver(int driverId) async {
    await ApiClient.instance.post('/favorites/drivers', data: {
      'driver_id': driverId,
    });
    await load();
  }

  Future<void> removeDriver(int driverId) async {
    await ApiClient.instance.delete('/favorites/drivers/$driverId');
    await load();
  }
}