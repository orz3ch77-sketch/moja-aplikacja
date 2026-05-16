class VoiceSpeaker {
  const VoiceSpeaker();

  bool get isSupported => false;

  Future<void> speak(String text) async {}

  void stop() {}
}
