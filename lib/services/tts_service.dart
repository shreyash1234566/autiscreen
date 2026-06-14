import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  /// Call once after registration — pre-warms TTS engine for the selected language.
  /// [languageCode] is 'en' or 'hi' (the app's internal code, not a BCP-47 tag).
  Future<void> init(String languageCode) async {
    await _flutterTts.setLanguage(_toBcp47(languageCode));
    await _flutterTts.setSpeechRate(0.4); // slower — better for children
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.1);     // slightly higher pitch
  }

  /// Speaks [name] in [languageCode] ('en' or 'hi').
  Future<void> callName(String name, {required String languageCode}) async {
    await _flutterTts.setLanguage(_toBcp47(languageCode));
    await _flutterTts.speak(name);
  }

  /// Speaks arbitrary [text] in [languageCode].
  Future<void> speak(String text, {required String languageCode}) async {
    await _flutterTts.setLanguage(_toBcp47(languageCode));
    await _flutterTts.speak(text);
  }

  Future<void> stop() async => _flutterTts.stop();

  String _toBcp47(String code) {
    switch (code) {
      case 'hi':
        return 'hi-IN';
      default:
        return 'en-US';
    }
  }
}
