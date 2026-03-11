# Android 키스토어 설정 가이드

## 1. Upload 키스토어 생성

다음 명령어를 실행하여 Upload 키스토어를 생성하세요:

```bash
keytool -genkey -v -keystore C:\project\flutter_webview\android\app\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### 입력 정보:
- **키스토어 비밀번호**: 안전한 비밀번호 입력 (기억하세요!)
- **키 비밀번호**: 키스토어 비밀번호와 동일하게 설정 권장
- **이름 및 조직 정보**: 실제 회사/개인 정보 입력
  - 이름: 대표자 이름
  - 조직 단위: 개발팀
  - 조직: 회사명 (예: East Company)
  - 구/군/시: 서울
  - 시/도: 서울특별시
  - 국가 코드: KR

## 2. key.properties 파일 생성

`android/key.properties` 파일을 생성하고 다음 내용을 입력하세요:

```properties
storePassword=<키스토어 비밀번호>
keyPassword=<키 비밀번호>
keyAlias=upload
storeFile=upload-keystore.jks
```

**⚠️ 중요:**
- `key.properties` 파일은 **절대 Git에 커밋하지 마세요!**
- 이미 `.gitignore`에 등록되어 있습니다.
- 키스토어 파일(`upload-keystore.jks`)도 안전하게 보관하세요.

## 3. 키스토어 백업

생성된 키스토어 파일과 비밀번호를 안전한 곳에 백업하세요:
- `upload-keystore.jks` 파일
- `key.properties` 파일 (또는 비밀번호를 별도 기록)

**키스토어를 분실하면 앱을 업데이트할 수 없습니다!**

## 4. Google Play App Signing 활성화

Google Play Console에서 App Signing을 활성화하세요:

1. Google Play Console → 앱 선택
2. **출시** → **설정** → **앱 무결성**
3. **App Signing** 활성화
4. **업로드 키 인증서** 등록:
   ```bash
   keytool -export -rfc -keystore upload-keystore.jks -alias upload -file upload_certificate.pem
   ```
5. 생성된 `upload_certificate.pem` 파일을 Google Play Console에 업로드

## 5. 완료 확인

설정이 완료되면 다음 명령어로 릴리즈 빌드를 테스트하세요:

```bash
flutter build appbundle --release
```

빌드가 성공하면 `build/app/outputs/bundle/release/app-release.aab` 파일이 생성됩니다.
