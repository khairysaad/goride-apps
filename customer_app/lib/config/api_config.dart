class ApiConfig {
  static const String primaryBaseUrl = 'https://goride-server.tailaf7d4.ts.net/goride-api/api';
  static const String fallbackBaseUrl = 'https://dark-thunder-e44d.khairy-saad.workers.dev/api';

  static bool useFallback = false;

  static String get baseUrl => primaryBaseUrl;

  static String get primaryRoot => primaryBaseUrl.replaceFirst(RegExp(r'/api$'), '');
  static String get fallbackRoot => fallbackBaseUrl.replaceFirst(RegExp(r'/api$'), '');
  static String get activeRoot => useFallback ? fallbackRoot : primaryRoot;

  static String get baseRoot => activeRoot;

  static String resolve(String? url) {
    final u = url?.trim() ?? '';
    if (u.isEmpty) return '';
    if (useFallback && u.startsWith(primaryRoot)) {
      return fallbackRoot + u.substring(primaryRoot.length);
    }
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    return '$activeRoot/${u.replaceFirst(RegExp(r'^/'), '')}';
  }

  static const String mapTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String mapUserAgent = 'com.goride.customer';
}