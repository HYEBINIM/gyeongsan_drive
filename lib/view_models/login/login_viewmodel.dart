import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../services/database/firestore_database_service.dart'; // RTDB → Firestore
import '../../services/storage/local_storage_service.dart';
import '../../models/user_model.dart';
import '../../models/notification_settings.dart';
import '../../widgets/dialogs/terms_agreement_bottom_sheet.dart';
import '../../utils/snackbar_utils.dart';

/// 로그인 화면의 비즈니스 로직을 담당하는 ViewModel
class LoginViewModel extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirestoreDatabaseService _databaseService =
      FirestoreDatabaseService(); // RTDB → Firestore
  final LocalStorageService _storageService = LocalStorageService();

  // Google 로그인 로딩 상태
  bool _isGoogleLoading = false;

  // 이메일 로그인 로딩 상태
  bool _isEmailLoading = false;

  // 자동 로그인 체크박스 상태
  bool _rememberMe = false;

  /// Google 로그인 로딩 상태 getter
  bool get isGoogleLoading => _isGoogleLoading;

  /// 이메일 로그인 로딩 상태 getter
  bool get isEmailLoading => _isEmailLoading;

  /// 자동 로그인 체크박스 상태 getter
  bool get rememberMe => _rememberMe;

  /// 이메일 로그인 처리
  /// 회원가입 화면으로 이동
  Future<void> onEmailLogin(BuildContext context) async {
    if (context.mounted) {
      Navigator.pushNamed(context, AppRoutes.signup);
    }
  }

  /// 이메일/비밀번호 로그인 처리
  /// Firebase Authentication을 사용하여 로그인 수행
  Future<void> onEmailPasswordLogin(
    String email,
    String password,
    BuildContext context, {
    Map<String, dynamic>? arguments, // 한국어 주석: 라우트 arguments (returnRoute 포함)
  }) async {
    // 이미 로그인 중이면 무시 (중복 실행 방지)
    if (_isEmailLoading) return;

    // 입력값 검증
    if (email.isEmpty || password.isEmpty) {
      if (context.mounted) {
        SnackBarUtils.showError(context, '이메일과 비밀번호를 입력해주세요');
      }
      return;
    }

    // 로딩 시작
    _isEmailLoading = true;
    notifyListeners();

    try {
      // Firebase 이메일 로그인 시도
      final user = await _authService.signInWithEmail(email, password);

      if (user != null) {
        // 이메일 인증 확인
        if (!user.emailVerified) {
          if (context.mounted) {
            SnackBarUtils.showWarning(context, '이메일 인증이 완료되지 않았습니다');
          }
          await _authService.signOut();
          return;
        }

        // Database에 사용자 데이터가 있는지 확인
        final exists = await _databaseService.userExists(user.uid);

        if (!exists) {
          // Database에 데이터가 없으면 신규 사용자로 처리 (기본 알림 설정 포함)
          final userModel = UserModel.fromFirebaseUser(
            user,
          ).copyWith(notificationSettings: NotificationSettings.defaults());
          await _databaseService.saveUserData(userModel);
        } else {
          // 기존 사용자 → Database의 displayName을 Firebase Auth에 동기화
          final userData = await _databaseService.getUserData(user.uid);
          if (userData?.displayName != null &&
              user.displayName != userData?.displayName) {
            await _authService.updateDisplayName(userData!.displayName!);
          }

          // 알림 설정이 없는 기존 사용자에게 기본 알림 설정 추가
          if (userData != null && userData.notificationSettings == null) {
            final updatedModel = userData.copyWith(
              notificationSettings: NotificationSettings.defaults(),
            );
            await _databaseService.saveUserData(updatedModel);
          }

          // 마지막 로그인 시간 업데이트
          await _databaseService.updateLastLogin(user.uid);
        }

        // 자동 로그인 설정 저장
        await _storageService.setAutoLoginEnabled(_rememberMe);

        // 한국어 주석: 로그인 성공 시 복귀 경로로 이동 (또는 홈으로 이동)
        if (context.mounted) {
          final returnRoute = arguments?['returnRoute'] as String?;
          final returnArguments = arguments?['returnArguments'];

          if (returnRoute != null) {
            // 한국어 주석: returnRoute가 있으면 해당 경로로 복귀
            Navigator.pushReplacementNamed(
              context,
              returnRoute,
              arguments: returnArguments,
            );
          } else {
            // 한국어 주석: returnRoute가 없으면 홈 탭으로 이동
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.mainNavigation,
              arguments: 0, // 홈 탭
            );
          }
        }
      }
    } catch (e) {
      // 에러 발생 시 사용자에게 알림
      if (context.mounted) {
        SnackBarUtils.showError(context, e.toString());
      }
    } finally {
      // 로딩 종료
      _isEmailLoading = false;
      notifyListeners();
    }
  }

  /// 아이디 찾기
  /// 아이디 찾기 화면으로 이동
  void onFindId(BuildContext context) {
    if (context.mounted) {
      Navigator.pushNamed(context, AppRoutes.findId);
    }
  }

  /// 비밀번호 찾기
  /// 비밀번호 찾기 화면으로 이동
  void onFindPassword(BuildContext context) {
    if (context.mounted) {
      Navigator.pushNamed(context, AppRoutes.findPassword);
    }
  }

  /// 회원가입 화면으로 이동
  void onSignup(BuildContext context) {
    if (context.mounted) {
      Navigator.pushNamed(context, AppRoutes.signup);
    }
  }

  /// Google 소셜 로그인 처리
  /// Google Sign-In 패키지를 사용하여 인증 처리
  Future<void> onGoogleLogin(
    BuildContext context, {
    Map<String, dynamic>? arguments, // 한국어 주석: 라우트 arguments (returnRoute 포함)
  }) async {
    // 이미 로그인 중이면 무시 (중복 실행 방지)
    if (_isGoogleLoading) return;

    // 로딩 시작
    _isGoogleLoading = true;
    notifyListeners();

    try {
      // 구글 로그인 시도
      final user = await _authService.signInWithGoogle();

      if (user == null) {
        // 한국어 주석: 사용자 취소 등으로 null 반환 시 사용자에게 안내
        if (context.mounted) {
          SnackBarUtils.showInfo(context, '로그인이 취소되었어요');
        }
        return;
      }

      final hasCachedProfile = await _storageService.hasCachedUserProfile(
        user.uid,
      );

      if (hasCachedProfile) {
        if (context.mounted) {
          _handleExistingUserFlow(context, user, arguments: arguments);
        }
        return;
      }

      // 기존 사용자인지 확인
      final exists = await _databaseService.userExists(user.uid);

      if (!exists) {
        // 신규 사용자 → 약관 동의 Bottom Sheet 표시 (비동기 처리)
        if (context.mounted) {
          unawaited(
            _presentTermsAgreementSheet(context, user, arguments: arguments),
          );
        }
        return;
      }

      await _storageService.markUserProfileInitialized(user.uid);
      if (context.mounted) {
        _handleExistingUserFlow(context, user, arguments: arguments);
      }
    } catch (e) {
      // 에러 발생 시 사용자에게 알림
      if (context.mounted) {
        SnackBarUtils.showError(context, e.toString());
      }
    } finally {
      // 로딩 종료
      _isGoogleLoading = false;
      notifyListeners();
    }
  }

  /// 기존 사용자 후속 처리 (네비게이션 선행 + 비동기 작업 분리)
  void _handleExistingUserFlow(
    BuildContext context,
    User user, {
    Map<String, dynamic>? arguments,
  }) {
    if (context.mounted) {
      // 한국어 주석: returnRoute가 있으면 해당 경로로 복귀
      final returnRoute = arguments?['returnRoute'] as String?;
      final returnArguments = arguments?['returnArguments'];

      if (returnRoute != null) {
        Navigator.pushReplacementNamed(
          context,
          returnRoute,
          arguments: returnArguments,
        );
      } else {
        // 한국어 주석: returnRoute가 없으면 홈 탭으로 이동
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.mainNavigation,
          arguments: 0, // 홈 탭
        );
      }
    }

    // 한국어 주석: Firestore/SharedPreferences 작업을 병렬로 처리하여 성능 향상
    Future.wait([
      _databaseService.updateLastLogin(user.uid),
      _storageService.setAutoLoginEnabled(_rememberMe),
      _storageService.markUserProfileInitialized(user.uid),
      // 한국어 주석: Google 기존 사용자의 notificationSettings 마이그레이션
      _migrateNotificationSettingsIfNeeded(user.uid),
    ]).catchError((e) {
      // ignore: avoid_print
      print('백그라운드 작업 실패: $e');
      return <void>[];
    });
  }

  /// Google 기존 사용자의 notificationSettings가 null인 경우 기본값으로 마이그레이션
  Future<void> _migrateNotificationSettingsIfNeeded(String uid) async {
    try {
      final userData = await _databaseService.getUserData(uid);
      if (userData != null && userData.notificationSettings == null) {
        final updatedModel = userData.copyWith(
          notificationSettings: NotificationSettings.defaults(),
        );
        await _databaseService.saveUserData(updatedModel);
      }
    } catch (e) {
      // ignore: avoid_print
      print('notificationSettings 마이그레이션 실패: $e');
    }
  }

  /// 신규 사용자 약관 동의를 비차단으로 표시
  Future<void> _presentTermsAgreementSheet(
    BuildContext context,
    User user, {
    Map<String, dynamic>? arguments,
  }) async {
    if (!context.mounted) return;

    final rootContext = context;

    await showModalBottomSheet(
      context: rootContext,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => TermsAgreementBottomSheet(
        // 동의 시 처리
        onAgree:
            (
              agreedToService,
              agreedToPrivacy,
              agreedToLocation,
              isOver14,
            ) async {
              // 한국어 주석: 선(先) 네비게이션으로 체감 속도 개선
              if (rootContext.mounted) {
                final returnRoute = arguments?['returnRoute'] as String?;
                final returnArguments = arguments?['returnArguments'];

                if (returnRoute != null) {
                  Navigator.pushReplacementNamed(
                    rootContext,
                    returnRoute,
                    arguments: returnArguments,
                  );
                } else {
                  Navigator.pushReplacementNamed(
                    rootContext,
                    AppRoutes.mainNavigation,
                    arguments: 0, // 홈 탭
                  );
                }
              }

              // 한국어 주석: 저장 로직을 병렬로 처리하여 성능 향상 (실패 시 콘솔 로깅)
              final userModel = UserModel.fromFirebaseUser(user).copyWith(
                agreedToService: agreedToService,
                agreedToPrivacy: agreedToPrivacy,
                agreedToLocation: agreedToLocation,
                isOver14: isOver14,
                termsAgreedAt: DateTime.now(),
                notificationSettings: NotificationSettings.defaults(),
              );

              Future.wait([
                _databaseService.saveUserData(userModel),
                _storageService.setAutoLoginEnabled(_rememberMe),
                _storageService.markUserProfileInitialized(user.uid),
              ]).catchError((e) {
                // 한국어 주석: 사용자 흐름을 막지 않기 위해 로그만 남김
                // ignore: avoid_print
                print('약관 저장/설정 비동기 처리 실패: $e');
                return <void>[];
              });
            },
        // 취소 시 처리
        onCancel: () async {
          // 생성된 계정 삭제
          await _authService.deleteCurrentUser();
          await _authService.signOut();
          try {
            await _storageService.clearUserProfileCache(user.uid);
          } catch (_) {
            // 한국어 주석: 사용자 취소 시 캐시 삭제 실패는 무시
          }
        },
      ),
    );
  }

  /// 미완료 회원가입 계정 확인
  /// Auth에는 계정이 있지만 Database에 데이터가 없는 경우 감지
  Future<bool> checkIncompleteSignup() async {
    try {
      final user = _authService.currentUser;

      // 로그인되어 있고 이메일 인증이 완료된 경우
      if (user != null && user.emailVerified) {
        // Database에 사용자 데이터가 있는지 확인
        final exists = await _databaseService.userExists(user.uid);

        // Database에 데이터가 없으면 미완료 회원가입
        if (!exists) {
          return true;
        }
      }

      return false;
    } catch (e) {
      // 에러 발생 시 false 반환
      return false;
    }
  }

  /// 미완료 회원가입 계정 삭제
  /// 사용자가 회원가입을 완료하지 않기로 선택한 경우 호출
  Future<void> deleteIncompleteAccount() async {
    try {
      await _authService.deleteCurrentUser();
      await _authService.signOut();
    } catch (e) {
      throw '계정 삭제 중 오류가 발생했습니다: $e';
    }
  }

  /// 자동 로그인 체크박스 상태 변경
  /// [value] true면 자동 로그인 활성화, false면 비활성화
  void setRememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }
}
