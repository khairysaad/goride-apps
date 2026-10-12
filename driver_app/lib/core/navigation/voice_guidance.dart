import 'dart:math' as math;

import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';

import '../network/route_service.dart';

const _notable = {
  'arrive',
  'turn',
  'roundabout',
  'rotary',
  'exit roundabout',
  'exit rotary',
  'end of road',
  'on ramp',
  'off ramp',
  'fork',
  'merge',
  'uturn',
};

class VoiceGuidance {
  VoiceGuidance._();

  static final VoiceGuidance instance = VoiceGuidance._();

  final FlutterTts _tts = FlutterTts();
  bool _enabled = true;
  bool _initialized = false;
  final Set<String> _spoken = {};

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      // 1) Prefer Google's TTS engine (the one behind the Google Maps voice).
      try {
        final engines = await _tts.getEngines;
        if (engines is List && engines.isNotEmpty) {
          final hasGoogle =
              engines.any((e) => e.toString().toLowerCase().contains('google'));
          if (hasGoogle) {
            await _tts.setEngine('com.google.android.tts');
          }
        }
      } catch (_) {}

      // 2) Pick the best available Arabic voice.
      String lang = 'ar';
      try {
        final langs = await _tts.getLanguages;
        if (langs is List && langs.isNotEmpty) {
          final all = langs.map((l) => l.toString()).toList();
          final preferred = ['ar-EG', 'ar-SA', 'ar-AE', 'ar'];
          bool exists(String v) =>
              all.any((l) => l.toLowerCase().startsWith(v.toLowerCase()));
          lang = preferred.firstWhere(exists, orElse: () {
            final anyAr = all.where((l) => l.toLowerCase().startsWith('ar'));
            return anyAr.isNotEmpty ? anyAr.first : 'ar';
          });
        }
      } catch (_) {}
      await _tts.setLanguage(lang);

      // 3) Try the Google Arabic narrator voices (network/local), ignore miss.
      for (final voice in const [
        {'name': 'ar-x-ara-network', 'locale': 'ar-XA'},
        {'name': 'ar-x-ara-local', 'locale': 'ar-XA'},
      ]) {
        try {
          await _tts.setVoice(voice);
          break;
        } catch (_) {}
      }

      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (_) {}
  }

  bool get enabled => _enabled;

  set enabled(bool value) {
    _enabled = value;
    if (!value) {
      try {
        _tts.stop();
      } catch (_) {}
    }
  }

  void onRoute(RouteResult route) {
    _spoken.clear();
  }

  String _streetSuffix(RouteStep s) {
    final name = s.instruction?.trim();
    if (name == null || name.isEmpty) return '';
    return ' إلى $name';
  }

  /// Google-style Arabic instruction for this maneuver.
  String maneuverText(RouteStep s) {
    switch (s.maneuver) {
      case 'turn':
        switch (s.modifier) {
          case 'left':
            return 'انعطف يساراً${_streetSuffix(s)}';
          case 'right':
            return 'انعطف يميناً${_streetSuffix(s)}';
          case 'left_sharp':
            return 'انعطف يساراً بحدة';
          case 'right_sharp':
            return 'انعطف يميناً بحدة';
          case 'slight_left':
            return 'انعطف يساراً قليلاً';
          case 'slight_right':
            return 'انعطف يميناً قليلاً';
          case 'uturn':
            return 'استدر إلى الخلف';
          default:
            return 'انعطف';
        }
      case 'new name':
        return 'تابع على الطريق${_streetSuffix(s)}';
      case 'continue':
        return 'استمر في السير${_streetSuffix(s)}';
      case 'merge':
        return 'ادمج في الطريق الرئيسي';
      case 'fork':
        return 'تابع على الطريق${_streetSuffix(s)}';
      case 'on ramp':
        return 'اصعد على الطريق السريع';
      case 'off ramp':
        return 'اخرج من الطريق السريع';
      case 'roundabout':
      case 'rotary':
        return 'ادخل الدوار';
      case 'exit roundabout':
      case 'exit rotary':
        return 'اخرج من الدوار';
      case 'depart':
        return 'انطلق الآن';
      case 'end of road':
        final m = s.modifier == 'left'
            ? 'انعطف يساراً'
            : s.modifier == 'right'
                ? 'انعطف يميناً'
                : 'تابع';
        return 'في نهاية الطريق $m';
      case 'arrive':
        final side = s.modifier == 'left'
            ? '، على يسارك'
            : s.modifier == 'right'
                ? '، على يمينك'
                : '';
        return 'لقد وصلت إلى وجهتك$side';
      default:
        if (s.distance != null && s.distance! >= 40) {
          return 'تابع لمسافة ${(s.distance! / 1000).toStringAsFixed(1)} كيلومتر';
        }
        return 'تابع في السير';
    }
  }

  String _stepKey(RouteStep s) {
    final p = s.location;
    return '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}';
  }

  Future<void> onLocationChanged(LatLng current, RouteResult? route) async {
    if (!_enabled || route == null || route.steps.isEmpty) return;
    await init();

    final steps = route.steps;

    // Locate the next upcoming notable maneuver (Google-style):
    // - any maneuver within 60m is considered "reached": finalize it (speak
    //   only for real turns), moving on to the next one.
    // - intermediate 'continue'/'new name' steps are skipped silently.
    RouteStep? target;
    for (final s in steps) {
      if (s.maneuver == 'depart') continue;
      final key = _stepKey(s);
      final done = _spoken.contains('fin:$key');
      if (done) continue;
      final d = _distanceMeters(current, s.location);
      if (d < 60) {
        _spoken.add('fin:$key');
        if (_notable.contains(s.maneuver) &&
            !_spoken.contains('t0:$key')) {
          await _speak(maneuverText(s));
        }
        continue;
      }
      if (!_notable.contains(s.maneuver)) continue;
      target = s;
      break;
    }

    if (target == null) return;

    final dist = _distanceMeters(current, target.location);
    final key = _stepKey(target);

    if (target.maneuver == 'arrive') {
      if (dist <= 200 && _spoken.add('a200:$key')) {
        await _speak('أنت على بعد 200 متر من وجهتك');
        return;
      }
      if (dist <= 500 && _spoken.add('a500:$key')) {
        await _speak('أنت على بعد 500 متر من وجهتك');
        return;
      }
      if (dist <= 1000 && _spoken.add('a1000:$key')) {
        await _speak('أنت على بعد كيلومتر واحد من وجهتك');
        return;
      }
      return;
    }

    if (dist <= 80 && _spoken.add('t0:$key')) {
      await _speak(maneuverText(target));
      return;
    }
    if (dist <= 200 && _spoken.add('t200:$key')) {
      await _speak('بعد 200 متر، ${maneuverText(target)}');
      return;
    }
    if (dist <= 300 && _spoken.add('t300:$key')) {
      await _speak('بعد 300 متر، ${maneuverText(target)}');
      return;
    }
    if (dist <= 500 && _spoken.add('t500:$key')) {
      await _speak('بعد 500 متر، ${maneuverText(target)}');
      return;
    }
    if (dist <= 1000 && _spoken.add('t1000:$key')) {
      await _speak('في كيلومتر واحد، ${maneuverText(target)}');
      return;
    }
    if (dist <= 1500 && _spoken.add('t1500:$key')) {
      await _speak('في كيلومتر ونصف، ${maneuverText(target)}');
      return;
    }
  }

  Future<void> _speak(String text) async {
    await init();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  double _rad(double deg) => deg * math.pi / 180;
}