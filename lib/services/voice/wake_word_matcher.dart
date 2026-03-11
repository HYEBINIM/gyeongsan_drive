import '../../utils/constants.dart';

class WakeWordMatcher {
  const WakeWordMatcher({this.wakeWord = AppConstants.voiceWakeWord});

  final String wakeWord;

  bool matchesWakePhrase(String text) {
    return _matchPrefix(text) != null;
  }

  String stripWakeWordPrefix(String text) {
    final normalized = normalizeWakeTranscript(text);
    final match = _matchPrefix(text);
    if (match == null) {
      return normalized;
    }

    var remaining = normalized
        .substring(match.normalizedPrefixLength)
        .trimLeft();
    if (remaining.startsWith('야')) {
      remaining = remaining.substring(1).trimLeft();
    }
    if (_leadingPunctuationPattern.hasMatch(remaining)) {
      remaining = remaining.substring(1).trimLeft();
    }
    return remaining;
  }

  String normalizeWakeTranscript(String text) {
    var normalized = text.trim();
    normalized = normalized.replaceAll(_punctuationPattern, ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    return normalized.trim();
  }

  _WakeWordPrefixMatch? _matchPrefix(String text) {
    final normalized = normalizeWakeTranscript(text);
    for (final alias in _normalizedAliases) {
      if (_startsWithAlias(normalized, alias)) {
        return _WakeWordPrefixMatch(alias.length);
      }
    }

    final compact = _compactWakeTranscript(normalized);
    for (final alias in _compactAliases) {
      if (_startsWithAlias(compact, alias)) {
        return _WakeWordPrefixMatch(
          _prefixLengthInNormalized(normalized, alias),
        );
      }
    }

    final fuzzyMatch = _fuzzyWakeWordPattern.firstMatch(compact);
    final fuzzyPrefix = fuzzyMatch?.group(0);
    if (fuzzyPrefix != null) {
      return _WakeWordPrefixMatch(
        _prefixLengthInNormalized(normalized, fuzzyPrefix),
      );
    }
    return null;
  }

  bool _startsWithAlias(String text, String alias) {
    if (!text.startsWith(alias)) {
      return false;
    }
    if (text.length == alias.length) {
      return true;
    }

    final nextChar = text[alias.length];
    return nextChar == ' ' || nextChar == '야';
  }

  String _compactWakeTranscript(String text) {
    return text.replaceAll(' ', '');
  }

  int _prefixLengthInNormalized(String normalized, String compactPrefix) {
    var compactIndex = 0;
    for (var index = 0; index < normalized.length; index += 1) {
      final char = normalized[index];
      if (char == ' ') {
        continue;
      }
      if (compactIndex < compactPrefix.length &&
          char == compactPrefix[compactIndex]) {
        compactIndex += 1;
        if (compactIndex == compactPrefix.length) {
          return index + 1;
        }
      } else {
        break;
      }
    }
    return normalized.length;
  }

  static final RegExp _punctuationPattern = RegExp(r'[,.!?~:;]+');
  static final RegExp _leadingPunctuationPattern = RegExp(r'^[,.!?~:;]');
  static final List<String> _normalizedAliases =
      [AppConstants.voiceWakeWord, ...AppConstants.voiceWakeWordAliases]
          .map((alias) => alias.trim().replaceAll(RegExp(r'\s+'), ' '))
          .toSet()
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  static final List<String> _compactAliases =
      _normalizedAliases
          .map((alias) => alias.replaceAll(' ', ''))
          .toSet()
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  static final RegExp _fuzzyWakeWordPattern = RegExp(
    r'^(이\s*스?\s*(트|터|뜨|투|트야|터야|투야))',
  );
}

class _WakeWordPrefixMatch {
  const _WakeWordPrefixMatch(this.normalizedPrefixLength);

  final int normalizedPrefixLength;
}
