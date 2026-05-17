class VoiceSpeaker {
  const VoiceSpeaker();

  bool get isSupported => false;

  bool get isSpeaking => false;

  Future<void> speak(String text) async {}

  void stop() {}
}
