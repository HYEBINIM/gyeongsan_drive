# =====================================================
# Flutter 앱 ProGuard 규칙 (정리 버전)
# =====================================================
# 이 파일은 코드 난독화(R8) 빌드 시 유지해야 할 클래스와 메서드를 정의합니다.
# --obfuscate + minifyEnabled true 환경에서 리플렉션/네이티브 플러그인이 제거되지
# 않도록 보호합니다.

# =====================================================
# Flutter / 엔진 / 플러그인 기본 보호
# =====================================================

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# =====================================================
# 음성 인식 및 출력 플러그인 보호 (speech_to_text, flutter_tts)
# =====================================================

# speech_to_text 플러그인 보호
-keep class com.csdcorp.speech_to_text.** { *; }

# flutter_tts 플러그인 보호
-keep class com.tundralabs.fluttertts.** { *; }

# Android 음성 인식 API 보호
-keep class android.speech.** { *; }
-keep interface android.speech.** { *; }

# Android TTS API 보호
-keep class android.speech.tts.** { *; }
-keep interface android.speech.tts.** { *; }

# 음성 콜백 메서드 (리스너) 보존
-keepclassmembers class * {
    *** onResults(...);
    *** onPartialResults(...);
    *** onError(...);
    *** onReadyForSpeech(...);
    *** onBeginningOfSpeech(...);
    *** onRmsChanged(...);
    *** onBufferReceived(...);
    *** onEndOfSpeech(...);
    *** onEvent(...);
    *** onStart(...);
    *** onDone(...);
    *** onStop(...);
    *** onRangeStart(...);
}

# =====================================================
# 커스텀 플러그인 / 메인 액티비티 보호
# =====================================================

-keep class com.eastcompany.east.WebViewSettingsPlugin { *; }
-keep class com.eastcompany.east.MainActivity { *; }

# =====================================================
# WebView 관련 보호
# =====================================================

# WebView 플러그인 (webview_flutter)
-keep class io.flutter.plugins.webviewflutter.** { *; }

# Android WebView API 보호
-keep class android.webkit.** { *; }

-keepclassmembers class * extends android.webkit.WebViewClient {
    <methods>;
}

-keepclassmembers class * extends android.webkit.WebChromeClient {
    <methods>;
}

# JavaScript Interface 보호 (WebView에서 JavaScript와 통신)
-keepattributes JavascriptInterface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# =====================================================
# Firebase / Google Play Services 관련 보호
# (firebase_core, firebase_auth, cloud_firestore, cloud_functions, geoflutterfire_plus, google_sign_in)
# =====================================================

-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# (향후 Messaging 사용 시 대비 – 현재 사용 안 해도 있어도 무방)
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# =====================================================
# Google Sign-In 보호
# =====================================================

# Google Play Services Auth & Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep interface com.google.android.gms.tasks.** { *; }

# Google Sign-In 플러그인 (Flutter)
-keep class io.flutter.plugins.googlesignin.** { *; }

# Google Sign-In Result Handling
-keepclassmembers class com.google.android.gms.auth.api.signin.GoogleSignInAccount {
    <fields>;
    <methods>;
}
-keepclassmembers class com.google.android.gms.auth.api.signin.GoogleSignInOptions {
    <fields>;
    <methods>;
}
-keepclassmembers class com.google.android.gms.auth.api.signin.GoogleSignInResult {
    <fields>;
    <methods>;
}

-dontwarn com.google.android.gms.auth.**
-dontwarn com.google.android.gms.tasks.**

# (Credential Manager 사용 시 대비 – 아직 사용 안 해도 문제 없음)
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** { *; }

# =====================================================
# flutter_local_notifications + Gson 보호
# =====================================================

# flutter_local_notifications 플러그인 패키지
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Gson (JSON 직렬화/역직렬화)
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod

# =====================================================
# 권한 / 위치 / 연락처 플러그인 보호
# (permission_handler, geolocator, flutter_contacts)
# =====================================================

# permission_handler 플러그인
-keep class com.baseflow.permissionhandler.** { *; }

# geolocator 플러그인
-keep class com.baseflow.geolocator.** { *; }

# Google Play Services Location
-keep class com.google.android.gms.location.** { *; }
-dontwarn com.google.android.gms.location.**

# flutter_contacts 플러그인 – 연락처 관련 리플렉션/필드 보호
-keep class com.github.contacts.** { *; }  # 실제 패키지명과 다르면 빌드시 에러 없음, 단순 no-op
-keepclassmembers class android.provider.ContactsContract$CommonDataKinds$* {
    *;
}

# =====================================================
# url_launcher 플러그인 보호
# =====================================================

-keep class io.flutter.plugins.urllauncher.** { *; }

# =====================================================
# HTTP 통신 라이브러리 보호 (http, dio 패키지)
# =====================================================

# OkHttp (http 패키지 내부 사용)
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**

# Dio HTTP 클라이언트
-keep class io.flutter.plugins.** { *; }

# HTTP 헤더 및 요청/응답 보호
-keepattributes *Annotation*
-keepclassmembers class * {
    @retrofit2.http.* <methods>;
}

# 카카오 API 통신 시 필요한 JSON 직렬화 보호
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# =====================================================
# 일반 보호 규칙 (Enum / Parcelable / Serializable / Native / Annotation)
# =====================================================

# 열거형(Enum) 보호
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelable 구현 보호
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# Serializable 구현 보호
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Native 메서드 보호
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Annotation 및 디버깅 정보 보존
-keepattributes *Annotation*,Signature,Exception,InnerClasses,EnclosingMethod
-keepattributes SourceFile,LineNumberTable

# =====================================================
# 프로덕션 최적화 (로그 제거 및 보안 강화)
# =====================================================

# =====================================================
# Android 15+ (API 35+) 경고 대응
# =====================================================

# 한국어 주석: Android 15에서 deprecated 된 시스템 바 색상 API 호출을 제거하여
# Play Console의 "지원 중단된 API" 경고를 줄입니다. (릴리즈 빌드 전용)
-assumenosideeffects class android.view.Window {
    void setStatusBarColor(int);
    void setNavigationBarColor(int);
    void setNavigationBarDividerColor(int);
}

# 디버그 로그 완전 제거 (릴리즈 빌드)
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
    public static *** wtf(...);
}

# System.out.println 제거
-assumenosideeffects class java.io.PrintStream {
    public void println(...);
}

# =====================================================
# 경고 억제 (알려진 무시 가능 경고)
# =====================================================

-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Google Play Core (Flutter deferred components - 사용하지 않음)
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# =====================================================
# 끝
# =====================================================
