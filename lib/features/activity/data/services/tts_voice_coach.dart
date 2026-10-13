import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/services/voice_coach.dart';

/// The OS speech voice in Thai, ducking music while it speaks and working
/// with the screen locked (iOS `audio` background mode).
class TtsVoiceCoach implements VoiceCoach {
  TtsVoiceCoach([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  Future<void>? _ready;

  Future<void> _init() => _ready ??= () async {
    await _tts.setLanguage('th-TH');
    await _tts.setSpeechRate(Platform.isIOS ? 0.5 : 0.9);
    if (Platform.isIOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }
  }();

  @override
  Future<void> speak(String text) async {
    try {
      await _init();
      await _tts.speak(text);
    } catch (_) {
      // A cue that cannot be spoken is skipped; recording goes on.
    }
  }
}
