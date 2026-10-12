import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;

  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class RouteService {
  static const _base = 'https://router.project-osrm.org/route/v1/driving/';

  static Future<RouteResult> getRoute(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        '$_base${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return _fallback(from, to);

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List? ?? [];
      if (routes.isEmpty) return _fallback(from, to);

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List;
      final points = coords
          .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
          .toList();

      final distanceMeters = (route['distance'] as num? ?? 0).toDouble();
      final durationSeconds = (route['duration'] as num? ?? 0).toDouble();

      return RouteResult(
        points: points,
        distanceKm: distanceMeters / 1000,
        durationMinutes: (durationSeconds / 60).round().clamp(1, 600),
      );
    } catch (_) {
      return _fallback(from, to);
    }
  }

  static RouteResult _fallback(LatLng from, LatLng to) {
    final distance = _distanceKm(from, to);
    return RouteResult(
      points: [from, to],
      distanceKm: distance,
      durationMinutes: (distance / 22 * 60).round().clamp(1, 600),
    );
  }

  static double _distanceKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final sLat = math.sin(dLat / 2);
    final sLng = math.sin(dLng / 2);
    final h = sLat * sLat +
        math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * sLng * sLng;
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return r * c;
  }

  static double _rad(double deg) => deg * math.pi / 180;
}