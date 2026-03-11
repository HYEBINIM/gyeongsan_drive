import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../database/firestore_database_service.dart';
import '../../models/user_model.dart';

/// 미완료 계정 처리 결과
enum IncompleteAccountResult {
  resetRequired, // 비밀번호 재설정 필요 (미완료 계정)
  duplicate, // 중복 계정 (완료된 계정)
}

/// Firebase Authentication 서비스
/// 이메일/비밀번호 인증, 구글 소셜 로그인 및 이메일 검증 기능 제공
class FirebaseAuthService {
  // 한국어 주석: Firebase에서 발급한 Web 클라이언트 ID (Google Sign-In용)
  // Android에서는 serverClientId 없이도 작동 가능 (google-services.json의 OAuth 클라이언트 사용)
  // static const String _googleWebClientId =
  //     '230969693841-j743e5r9uokblekceads9gbfgtri0vt4.apps.googleusercontent.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // GoogleSignIn 인스턴스
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // serverClientId: _googleWebClientId, // 임시로 주석 처리
  );

  /// 현재 로그인된 사용자
  User? get currentUser => _auth.currentUser;

  /// 사용자 인증 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 임시 계정 생성 (이메일 검증용)
  /// 랜덤 비밀번호로 계정을 생성하고 검증 이메일을 발송
  Future<User?> createTempAccountWithEmail(String email) async {
    try {
      // 랜덤 임시 비밀번호 생성 (최소 6자리)
      final tempPassword = _generateTempPassword();

      // Firebase 계정 생성
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );

      // 검증 이메일 자동 발송
      await credential.user?.sendEmailVerification();

      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// 검증 이메일 발송
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// 이메일 검증 상태 확인
  /// 사용자 정보를 새로고침한 후 검증 상태 반환
  Future<bool> checkEmailVerified() async {
    try {
      await _auth.currentUser?.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// 사용자 정보 새로고침
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// 비밀번호 업데이트
  /// 이메일 검증 완료 후 사용자가 원하는 비밀번호로 변경
  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// displayName 업데이트
  /// Firebase Authentication의 displayName을 업데이트하고 사용자 정보 새로고침
  Future<void> updateDisplayName(String displayName) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
      await _auth.currentUser?.reload();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// 이메일/비밀번호로 재인증
  /// 민감한 작업(계정 삭제, 비밀번호 변경 등) 전 필수
  Future<void> reauthenticateWithPassword(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw '로그인된 사용자가 없습니다.';
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// 구글 계정으로 재인증
  /// 민감한 작업(계정 삭제 등) 전 필수
  Future<void> reauthenticateWithGoogle() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw '로그인된 사용자가 없습니다.';
      }

      // 구글 계정 선택 및 로그인
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // 사용자가 로그인을 취소한 경우
      if (googleUser == null) {
        throw '재인증이 취소되었습니다.';
      }

      // 구글 인증 정보 획득
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Firebase 인증 정보 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 재인증
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      final errorMessage = e.toString();

      // 사용자가 팝업을 닫은 경우
      if (errorMessage.contains('popup_closed')) {
        throw '재인증이 취소되었습니다.';
      }

      throw '재인증 중 오류가 발생했습니다: $e';
    }
  }

  /// 현재 사용자의 로그인 Provider 확인
  /// 'password': 이메일/비밀번호 로그인
  /// 'google.com': 구글 소셜 로그인
  String getUserProvider() {
    final user = currentUser;
    if (user == null || user.providerData.isEmpty) {
      return 'password'; // 기본값
    }
    return user.providerData.first.providerId;
  }

  /// 구글 소셜 로그인 사용자인지 확인
  bool isGoogleUser() {
    return getUserProvider() == 'google.com';
  }

  /// 이메일/비밀번호 로그인 사용자인지 확인
  bool isEmailPasswordUser() {
    return getUserProvider() == 'password';
  }

  /// 구글 Provider가 연결되어 있는지 확인 (다중 Provider 대응)
  /// 사용자가 여러 로그인 방식을 연결했을 때도 구글 Provider 감지
  bool hasGoogleProvider() {
    final user = currentUser;
    if (user == null) return false;

    return user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
  }

  /// 이메일/비밀번호로 로그인
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// 구글 계정으로 로그인
  /// 구글 계정 선택 후 Firebase Authentication과 연동
  Future<User?> signInWithGoogle() async {
    try {
      // 구글 계정 선택 및 로그인
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // 사용자가 로그인을 취소한 경우 null 반환 (에러 아님)
      if (googleUser == null) {
        return null;
      }

      // 구글 인증 정보 획득
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Firebase 인증 정보 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase로 로그인
      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      final errorMessage = e.toString();

      // 사용자가 팝업을 닫은 경우 무시 (정상적인 취소 동작)
      if (errorMessage.contains('popup_closed')) {
        return null;
      }

      throw '구글 로그인 중 오류가 발생했습니다: $e';
    }
  }

  /// 로그아웃
  /// Firebase 및 구글 계정 모두 로그아웃 처리
  Future<void> signOut() async {
    try {
      // Firebase 로그아웃
      await _auth.signOut();
      // 구글 로그아웃
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// 현재 로그인된 사용자 계정 삭제
  /// 회원가입 실패 시 롤백 또는 사용자 요청 시 사용
  Future<void> deleteCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw '보안을 위해 다시 로그인이 필요합니다.';
      }
      throw _handleAuthException(e);
    } catch (e) {
      throw '계정 삭제 중 오류가 발생했습니다: $e';
    }
  }

  /// 비밀번호 재설정 이메일 발송
  /// 사용자가 비밀번호를 잊어버렸을 때 재설정 링크를 이메일로 전송
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// 이메일 링크로 로그인 (아이디 찾기용)
  /// 비밀번호 없이 이메일 링크만으로 인증 가능
  Future<void> sendSignInLinkToEmail(String email) async {
    try {
      final actionCodeSettings = ActionCodeSettings(
        // 링크 클릭 후 리다이렉트될 URL
        url: 'https://your-app-url.com/finishSignUp?email=$email',
        // 모바일 앱에서 처리
        handleCodeInApp: true,
        // iOS 설정
        iOSBundleId: 'com.example.yourapp',
        // Android 설정
        androidPackageName: 'com.example.yourapp',
        androidInstallApp: true,
        androidMinimumVersion: '12',
      );

      await _auth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// URL이 이메일 로그인 링크인지 확인
  bool isSignInWithEmailLink(String emailLink) {
    return _auth.isSignInWithEmailLink(emailLink);
  }

  /// 이메일 링크로 로그인 처리
  Future<User?> signInWithEmailLink(String email, String emailLink) async {
    try {
      final credential = await _auth.signInWithEmailLink(
        email: email,
        emailLink: emailLink,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// 랜덤 임시 비밀번호 생성 (16자리)
  String _generateTempPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = Random.secure();
    return List.generate(
      16,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Firebase Auth 예외 처리
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'invalid-email':
        return '올바르지 않은 이메일 형식입니다.';
      case 'weak-password':
        return '비밀번호는 최소 6자 이상이어야 합니다.';
      case 'user-not-found':
        return '등록되지 않은 이메일입니다.';
      case 'wrong-password':
        return '잘못된 비밀번호입니다.';
      case 'too-many-requests':
        return '너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해주세요.';
      case 'account-exists-with-different-credential':
        return '이미 다른 로그인 방식으로 가입된 계정입니다.';
      case 'invalid-credential':
        return '인증 정보가 올바르지 않습니다.';
      case 'operation-not-allowed':
        return '이 로그인 방식은 현재 사용할 수 없습니다.';
      case 'user-disabled':
        return '비활성화된 계정입니다.';
      default:
        return '오류가 발생했습니다: ${e.message}';
    }
  }

  /// 미완료 계정 처리 (재가입을 위한 안내)
  /// 1. 이메일로 UID 조회
  /// 2. Database에 데이터 없거나 미인증 → 미완료 계정
  /// 3. 비밀번호 재설정 이메일 발송
  Future<IncompleteAccountResult> handleIncompleteAccount(
    String email,
    FirestoreDatabaseService databaseService,
  ) async {
    try {
      // 1. 이메일로 UID 조회
      final uid = await databaseService.getUidByEmail(email);

      if (uid == null) {
        // emails 인덱스에 없음 → Auth에만 있을 가능성
        // 미완료 계정으로 간주하고 비밀번호 재설정
        await sendPasswordResetEmail(email);
        return IncompleteAccountResult.resetRequired;
      }

      // 2. Database에서 사용자 정보 조회 시도
      UserModel? userData;
      try {
        userData = await databaseService.getUserData(uid);
      } catch (e) {
        // permission-denied 등의 경우 null로 처리
        userData = null;
      }

      // 3. 데이터 없거나 이메일 미인증 → 미완료 계정
      if (userData == null || !userData.emailVerified) {
        await sendPasswordResetEmail(email);
        return IncompleteAccountResult.resetRequired;
      }

      // 4. 완료된 계정 → 중복 계정
      return IncompleteAccountResult.duplicate;
    } catch (e) {
      throw '계정 확인 중 오류가 발생했습니다: $e';
    }
  }
}
