import '../../utils/constants.dart';

class WakeWordMatcher {
  const WakeWordMatcher({this.wakeWord = AppConstants.voiceWakeWord});

  final String wakeWord;

  bool matchesWakePhrase(String text) {
    final normalized = _normalize(text);
    return normalized.startsWith(wakeWord);
  }

  String stripWakeWordPrefix(String text) {
    final normalized = _normalize(text);
    if (!normalized.startsWith(wakeWord)) {
      return normalized;
    }

    var remaining = normalized.substring(wakeWord.length).trimLeft();
    if (remaining.startsWith('야')) {
      remaining = remaining.substring(1).trimLeft();
    }
    if (remaining.startsWith(',') || remaining.startsWith('.')) {
      remaining = remaining.substring(1).trimLeft();
    }
    return remaining;
  }

  String _normalize(String text) {
    var normalized = text.trim();
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    return normalized;
  }
}
