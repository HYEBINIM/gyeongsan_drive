import '../../models/voice/rule_voice_intent.dart';

class RuleVoiceIntentMatcher {
  const RuleVoiceIntentMatcher();

  RuleVoiceIntent match(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) {
      return RuleVoiceIntent.unsupported;
    }

    if (_containsAny(normalized, const ['배터리']) &&
        _containsAny(normalized, const ['잔량', '퍼센트', '%'])) {
      return RuleVoiceIntent.batterySoc;
    }

    if (_containsAny(normalized, const ['속도', '몇 킬로', '몇키로'])) {
      return RuleVoiceIntent.vehicleSpeed;
    }

    if (_containsAny(normalized, const ['총 주행거리', '주행거리', '누적 거리', '누적거리'])) {
      return RuleVoiceIntent.vehicleMileage;
    }

    if (_containsAny(normalized, const ['운전 점수', '운전점수']) ||
        (_containsAny(normalized, const ['점수']) &&
            _containsAny(normalized, const ['운전']))) {
      return RuleVoiceIntent.drivingScore;
    }

    return RuleVoiceIntent.unsupported;
  }

  bool _containsAny(String source, List<String> keywords) {
    for (final keyword in keywords) {
      if (source.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  String _normalize(String text) {
    var normalized = text.trim().toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    return normalized;
  }
}
