class ApiConfig {
  static const String primaryBaseUrl = 'https://goride-server.tailaf7d4.ts.net/goride-api/api';
  static const String fallbackBaseUrl = 'https://dark-thunder-e44d.khairy-saad.workers.dev/api';

  static bool useFallback = false;

  static String get baseUrl => primaryBaseUrl;

  static String get primaryRoot => primaryBaseUrl.replaceFirst(RegExp(r'/api$'), '');
  static String get fallbackRoot => fallbackBaseUrl.replaceFirst(RegExp(r'/api$'), '');
  static String get activeRoot => useFallback ? fallbackRoot : primaryRoot;

  static const String mapTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String mapUserAgent = 'com.goride.driver';

  static String resolve(String urlOrPath) {
    if (useFallback && urlOrPath.startsWith(primaryRoot)) {
      return fallbackRoot + urlOrPath.substring(primaryRoot.length);
    }
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
      return urlOrPath;
    }
    final p = urlOrPath.startsWith('/') ? urlOrPath : '/$urlOrPath';
    return '$activeRoot$p';
  }
}