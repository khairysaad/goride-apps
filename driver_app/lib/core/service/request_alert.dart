import 'package:flutter/services.dart';

class RequestAlert {
  static Future<void> ring() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}