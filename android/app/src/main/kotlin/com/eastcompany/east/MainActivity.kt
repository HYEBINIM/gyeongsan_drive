package com.eastcompany.east

import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    /**
     * Activity 생성 시 Splash Screen 초기화
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 12+ Splash Screen 설치 (Theme.SplashScreen 활성화)
        installSplashScreen()

        // 한국어 주석: Android 15+의 엣지투엣지 기본 동작과 동일하게,
        // 모든 버전에서 시스템 인셋을 Flutter로 전달받도록 설정합니다.
        WindowCompat.setDecorFitsSystemWindows(window, false)

        super.onCreate(savedInstanceState)
    }

    /**
     * FlutterEngine 설정
     * Platform Channel Plugin 등록
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // WebView 성능 최적화 Plugin 등록
        WebViewSettingsPlugin.registerWith(flutterEngine)
    }
}
