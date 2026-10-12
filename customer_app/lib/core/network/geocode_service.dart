import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class GeocodeResult {
  final String displayName;
  final LatLng position;

  GeocodeResult({required this.displayName, required this.position});

  String get shortName {
    final parts = displayName.split(',');
    if (parts.length > 2) parts.removeRange(2, parts.length);
    return parts.join(',');
  }
}

class GeocodeService {
  static const _ua = 'KhatSeeryCustomer/1.0 (https://goride.app)';
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://nominatim.openstreetmap.org',
      headers: {
        'User-Agent': _ua,
        'Accept-Language': 'ar',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  static Future<List<GeocodeResult>> search(String query,
      {LatLng? near}) async {
    try {
      final res = await _dio.get('/search', queryParameters: {
        'q': query,
        'format': 'jsonv2',
        'limit': 6,
        if (near != null) 'lat': near.latitude,
        if (near != null) 'lon': near.longitude,
        'accept-language': 'ar',
      });
      if (res.data is! List) return const [];
      return (res.data as List).whereType<Map>().map((e) {
        final lat = double.tryParse('${e['lat']}') ?? 0;
        final lon = double.tryParse('${e['lon']}') ?? 0;
        final name = '${e['display_name'] ?? ''}';
        return GeocodeResult(displayName: name, position: LatLng(lat, lon));
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<String?> reverse(double lat, double lng) async {
    try {
      final res = await _dio.get('/reverse', queryParameters: {
        'lat': lat,
        'lon': lng,
        'format': 'jsonv2',
        'zoom': 16,
        'accept-language': 'ar',
      });
      if (res.data is! Map) return null;
      final d = res.data as Map;
      final addr = d['address'];
      if (addr is Map) {
        final a = Map<String, dynamic>.from(addr);
        final road = a['road'] ??
            a['pedestrian'] ??
            a['footway'] ??
            a['cycleway'] ??
            a['neighbourhood'] ??
            '';
        final area = a['suburb'] ??
            a['quarter'] ??
            a['city_district'] ??
            a['village'] ??
            '';
        final city = a['city'] ?? a['town'] ?? a['county'] ?? a['state'] ?? '';
        final parts = <String>[
          if (road is String && road.trim().isNotEmpty) road,
          if (area is String && area.trim().isNotEmpty) area,
          if (city is String && city.trim().isNotEmpty) city,
        ];
        if (parts.isNotEmpty) return parts.join('، ');
      }
      final name = d['display_name'];
      return name is String ? name : null;
    } catch (_) {
      return null;
    }
  }
}