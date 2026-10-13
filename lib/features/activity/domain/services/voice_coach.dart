/// Speaks short cues aloud while recording (ducks other audio).
abstract interface class VoiceCoach {
  Future<void> speak(String text);
}
