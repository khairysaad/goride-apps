import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteStep {
  final LatLng location;
  final String? maneuver;
  final String? instruction;
  final double? distance;
  final double? duration;
  final String? modifier;

  const RouteStep({
    required this.location,
    this.maneuver,
    this.instruction,
    this.distance,
    this.duration,
    this.modifier,
  });
}

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final List<RouteStep> steps;

  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    this.steps = const [],
  });
}

class RouteService {
  static const _base = 'https://router.project-osrm.org/route/v1/driving/';

  static Future<RouteResult> getRoute(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        '$_base${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&steps=true&annotations=false',
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

      final legs = route['legs'] as List? ?? [];
      final steps = <RouteStep>[];
      for (final leg in legs) {
        final legSteps = (leg is Map && leg['steps'] is List)
            ? leg['steps'] as List
            : <dynamic>[];
        for (final s in legSteps) {
          if (s is! Map) continue;
          final stop = s['maneuver'];
          final lat = stop is Map ? stop['location'] : null;
          steps.add(RouteStep(
            location: lat is List && lat.length >= 2
                ? LatLng(lat[1].toDouble(), lat[0].toDouble())
                : (points.isNotEmpty ? points.last : from),
            maneuver: stop is Map ? stop['type']?.toString() : null,
            modifier: stop is Map ? stop['modifier']?.toString() : null,
            instruction: s['name']?.toString(),
            distance: s['distance'] is num ? (s['distance'] as num).toDouble() : null,
            duration: s['duration'] is num ? (s['duration'] as num).toDouble() : null,
          ));
        }
      }

      return RouteResult(
        points: points,
        distanceKm: distanceMeters / 1000,
        durationMinutes: (durationSeconds / 60).round().clamp(1, 600),
        steps: steps,
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
      steps: [RouteStep(location: to, maneuver: 'arrive', modifier: null)],
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