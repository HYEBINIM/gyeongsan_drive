import 'package:flutter/services.dart';

class VoiceCueService {
  Future<void> playWakeAcknowledgement() async {
    await SystemSound.play(SystemSoundType.click);
  }
}
