import 'dart:convert';
import 'package:crypto/crypto.dart';

/// 암호화 유틸리티
/// SHA-256 해시를 사용한 PIN 암호화 및 검증
class CryptoUtils {
  /// PIN 코드를 SHA-256 해시로 변환
  ///
  /// [pin] 4~6자리 숫자 PIN
  /// Returns: 64자 hex 문자열 (SHA-256 해시)
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// PIN 코드 검증
  ///
  /// [inputPin] 사용자가 입력한 PIN
  /// [storedHash] 저장된 SHA-256 해시
  /// Returns: 입력한 PIN의 해시와 저장된 해시가 일치하면 true
  static bool verifyPin(String inputPin, String storedHash) {
    return hashPin(inputPin) == storedHash;
  }
}
