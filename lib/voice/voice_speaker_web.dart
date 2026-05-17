import 'dart:html' as html;

class VoiceSpeaker {
  const VoiceSpeaker();

  bool get isSupported => html.window.speechSynthesis != null;

  bool get isSpeaking => html.window.speechSynthesis?.speaking ?? false;

  Future<void> speak(String text) async {
    stop();

    final utterance = html.SpeechSynthesisUtterance(text)
      ..lang = 'pl-PL'
      ..rate = 0.82
      ..pitch = 1.08
      ..volume = 0.86;

    final voice = _softPolishVoice();
    if (voice != null) {
      utterance.voice = voice;
      utterance.lang = voice.lang;
    }

    html.window.speechSynthesis?.speak(utterance);
  }

  void stop() {
    html.window.speechSynthesis?.cancel();
  }

  html.SpeechSynthesisVoice? _softPolishVoice() {
    final voices = html.window.speechSynthesis?.getVoices() ?? [];
    if (voices.isEmpty) {
      return null;
    }

    final polishVoices = voices
        .where((voice) => (voice.lang ?? '').toLowerCase().startsWith('pl'))
        .toList();
    final candidates = polishVoices.isEmpty ? voices : polishVoices;
    const preferredNames = [
      'paulina',
      'zofia',
      'ewa',
      'maria',
      'female',
      'woman',
      'kobieta',
    ];

    for (final preferredName in preferredNames) {
      for (final voice in candidates) {
        if ((voice.name ?? '').toLowerCase().contains(preferredName)) {
          return voice;
        }
      }
    }

    return candidates.first;
  }
}
