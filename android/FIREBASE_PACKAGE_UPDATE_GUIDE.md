# Firebase 패키지명 업데이트 가이드

패키지명을 `com.example.flutter_webview`에서 `com.eastcompany.east`로 변경했으므로, Firebase 프로젝트 설정도 업데이트해야 합니다.

## 1. Firebase Console에서 패키지명 변경

### 방법 1: 기존 앱 패키지명 변경 (권장하지 않음)
Firebase는 앱 패키지명 직접 변경을 지원하지 않습니다. 대신 새 앱을 추가하는 것이 좋습니다.

### 방법 2: 새 Android 앱 추가 (권장)

1. **Firebase Console 접속**
   - https://console.firebase.google.com
   - 프로젝트 선택

2. **새 Android 앱 추가**
   - 프로젝트 설정 → 일반 탭
   - "앱 추가" → "Android" 선택
   - Android 패키지 이름: `com.eastcompany.east` 입력
   - 앱 닉네임: 이스트
   - 디버그 서명 인증서 SHA-1 (선택사항, Google Sign-In 사용 시 필요)

3. **google-services.json 다운로드**
   - 새로 생성된 `google-services.json` 파일 다운로드
   - `android/app/google-services.json` 경로에 덮어쓰기

4. **기존 앱 제거 (선택사항)**
   - Firebase Console → 프로젝트 설정 → 일반
   - `com.example.flutter_webview` 앱 찾기
   - 삭제 버튼 클릭 (30일 후 완전 삭제)

## 2. SHA-1 인증서 등록 (Google Sign-In 사용 시)

### 디버그 인증서 SHA-1 확인:
```bash
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### 릴리즈 인증서 SHA-1 확인:
```bash
keytool -list -v -keystore android/app/upload-keystore.jks -alias upload
```

Firebase Console → 프로젝트 설정 → 앱 선택 → SHA 인증서 지문에 등록하세요.

## 3. Firebase 서비스별 설정 확인

### 3.1 Firebase Authentication
- 새 패키지명으로 앱 등록 완료되면 자동으로 작동합니다.
- Google Sign-In을 사용한다면 SHA-1 인증서 등록 필수!

### 3.2 Cloud Firestore
- 패키지명 변경만으로는 영향 없습니다.
- 기존 데이터와 규칙이 그대로 유지됩니다.

### 3.3 Firebase Cloud Messaging (FCM)
- 새 google-services.json의 Sender ID를 사용합니다.
- 기존 디바이스 토큰은 무효화되므로, 사용자가 앱 재설치 후 새 토큰 생성됩니다.

### 3.4 Firebase Analytics
- 새 앱으로 등록되므로, 기존 분석 데이터와 분리됩니다.
- 이전 데이터는 구 패키지명 앱에서 계속 확인 가능합니다.

## 4. 테스트

패키지명 변경 후 다음 기능들을 테스트하세요:

- [ ] Firebase 초기화 성공
- [ ] Firebase Authentication (이메일/Google Sign-In)
- [ ] Firestore 데이터 읽기/쓰기
- [ ] FCM 푸시 알림 수신
- [ ] Firebase Analytics 이벤트 기록

## 5. 주의사항

⚠️ **중요:**
- 패키지명 변경 후에는 기존 사용자가 앱을 재설치해야 합니다.
- 같은 기기에 구 패키지명 앱과 신 패키지명 앱이 동시에 설치 가능합니다.
- Google Play Store에 업로드 시, 새 패키지명은 새로운 앱으로 인식됩니다.
- 기존 앱을 업데이트하려면 패키지명을 그대로 유지해야 합니다.

## 6. 보안 확인

- [ ] `google-services.json`이 `.gitignore`에 등록되어 있는지 확인
- [ ] Git 히스토리에 이전 `google-services.json`이 포함되어 있다면 제거 권장:
  ```bash
  git filter-branch --force --index-filter "git rm --cached --ignore-unmatch android/app/google-services.json" --prune-empty --tag-name-filter cat -- --all
  ```
- [ ] GitHub에 푸시된 민감한 파일 제거 후 Firebase API 키 재생성 권장

## 7. 완료 확인

설정이 완료되면 다음 명령어로 빌드를 테스트하세요:

```bash
flutter clean
flutter pub get
flutter build apk --debug
```

빌드가 성공하고 Firebase 기능이 정상 작동하면 완료입니다!
