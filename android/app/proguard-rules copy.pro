# =====================================================
# Flutter 앱 ProGuard 규칙
# =====================================================
# 이 파일은 코드 난독화 빌드 시 유지해야 할 클래스와 메서드를 정의합니다.
# --obfuscate 옵션 사용 시 리플렉션 기반 플러그인이 제거되지 않도록 보호합니다.

# =====================================================
# 음성 인식 및 출력 플러그인 보호 (speech_to_text, flutter_tts)
# =====================================================

# speech_to_text 플러그인 보호
-keep class com.csdcorp.speech_to_text.** { *; }
-keep interface com.csdcorp.speech_to_text.** { *; }
-keep class * implements com.csdcorp.speech_to_text.** { *; }

# flutter_tts 플러그인 보호 (올바른 패키지명)
-keep class com.tundralabs.fluttertts.** { *; }
-keep interface com.tundralabs.fluttertts.** { *; }
-keep class * implements com.tundralabs.fluttertts.** { *; }

# Android 음성 인식 API 보호
-keep class android.speech.** { *; }
-keep interface android.speech.** { *; }
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
}

# Android TTS API 보호
-keep class android.speech.tts.** { *; }
-keep interface android.speech.tts.** { *; }
-keepclassmembers class * {
    *** onStart(...);
    *** onDone(...);
    *** onError(...);
    *** onStop(...);
    *** onRangeStart(...);
}

# =====================================================
# Flutter Plugin 기본 보호
# =====================================================

# Flutter 엔진 및 플러그인 기본 보호
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.util.** { *; }

# Method Channel 보호 (Flutter-Native 통신)
-keep class io.flutter.plugin.common.** { *; }
-keepclassmembers class * {
    @io.flutter.plugin.common.MethodChannel$MethodCallHandler *;
}

# =====================================================
# 커스텀 플러그인 보호
# =====================================================

# WebViewSettingsPlugin 보호 (패키지명 업데이트)
-keep class com.eastcompany.east.WebViewSettingsPlugin { *; }
-keep class com.eastcompany.east.MainActivity { *; }

# =====================================================
# WebView 관련 보호
# =====================================================

# WebView 플러그인 보호
-keep class io.flutter.plugins.webviewflutter.** { *; }
-keep class * implements io.flutter.plugins.webviewflutter.** { *; }

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
# Firebase 관련 보호
# =====================================================

# Firebase Core
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# =====================================================
# Google Sign-In 보호 (전면 개선)
# =====================================================

# Google Play Services Auth & Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep interface com.google.android.gms.tasks.** { *; }

# Google Sign-In 플러그인 (Flutter)
-keep class io.flutter.plugins.googlesignin.** { *; }
-keep interface io.flutter.plugins.googlesignin.** { *; }

# GoogleApiClient 및 콜백 보호
-keepclassmembers class * implements com.google.android.gms.common.api.GoogleApiClient.ConnectionCallbacks {
    <methods>;
}
-keepclassmembers class * implements com.google.android.gms.common.api.GoogleApiClient.OnConnectionFailedListener {
    <methods>;
}

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

# 경고 억제
-dontwarn com.google.android.gms.auth.**
-dontwarn com.google.android.gms.tasks.**

# =====================================================
# 네트워크 통신 관련 보호
# =====================================================

# HTTP 클라이언트 (OkHttp)
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Gson (JSON 직렬화/역직렬화)
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod

# =====================================================
# 권한 관련 플러그인 보호
# =====================================================

# permission_handler 플러그인
-keep class com.baseflow.permissionhandler.** { *; }

# =====================================================
# 위치 서비스 관련 보호
# =====================================================

# geolocator 플러그인
-keep class com.baseflow.geolocator.** { *; }

# Google Play Services Location
-keep class com.google.android.gms.location.** { *; }

# =====================================================
# 공유 기능 관련 보호
# =====================================================

# share_plus 플러그인
-keep class dev.fluttercommunity.plus.share.** { *; }

# =====================================================
# 일반 보호 규칙
# =====================================================

# 열거형(Enum) 보호
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelable 구현 보호
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
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

# Annotation 보존
-keepattributes *Annotation*,Signature,Exception,InnerClasses,EnclosingMethod

# 라인 번호 보존 (크래시 리포트 분석용)
-keepattributes SourceFile,LineNumberTable

# =====================================================
# 경고 억제
# =====================================================

# 알려진 경고 억제
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
# 프로덕션 최적화 (로그 제거 및 보안 강화)
# =====================================================

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
    public void println(%);
    public void println(**);
}

# BuildConfig DEBUG 상수 최적화
-assumenosideeffects class com.eastcompany.east.BuildConfig {
    public static final boolean DEBUG return false;
}

# =====================================================
# 보안 강화
# =====================================================

# 난독화 강도 높이기
-repackageclasses ''
-allowaccessmodification

# 최적화 옵션
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5

# =====================================================
# 추가 플러그인 보호
# =====================================================

# Google Play Services Location (Safe Home 기능용)
-keep class com.google.android.gms.location.** { *; }
-keep interface com.google.android.gms.location.** { *; }

# Firebase Crashlytics (크래시 리포팅)
-keep class com.google.firebase.crashlytics.** { *; }
-keepattributes *Annotation*,SourceFile,LineNumberTable

# url_launcher 플러그인
-keep class io.flutter.plugins.urllauncher.** { *; }

# image_picker 플러그인 (프로필 사진 등)
-keep class io.flutter.plugins.imagepicker.** { *; }

# =====================================================
# 끝
# =====================================================
