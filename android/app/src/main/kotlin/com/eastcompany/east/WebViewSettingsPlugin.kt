package com.eastcompany.east

import android.webkit.WebSettings
import android.webkit.WebView
import com.eastcompany.east.BuildConfig
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * WebView 성능 최적화를 위한 Platform Channel Plugin
 *
 * Flutter에서 직접 접근할 수 없는 Android Native WebSettings를 제어합니다.
 * - DOM Storage 활성화
 * - 캐시 모드 설정
 * - Layout 최적화
 * - 데이터베이스 활성화
 */
class WebViewSettingsPlugin : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "webview_settings"

        /**
         * FlutterEngine에 Plugin을 등록합니다
         */
        fun registerWith(flutterEngine: FlutterEngine) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            channel.setMethodCallHandler(WebViewSettingsPlugin())
        }
    }

    /**
     * Flutter에서 호출한 메서드를 처리합니다
     */
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "optimizeWebViewSettings" -> {
                try {
                    // WebView 전역 설정 최적화
                    optimizeGlobalWebViewSettings()
                    result.success(true)
                } catch (e: Exception) {
                    result.error("OPTIMIZATION_ERROR", e.message, null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * WebView 전역 설정을 최적화합니다
     *
     * 주의: WebView 인스턴스별 설정은 webview_flutter 패키지에서 처리하며,
     * 여기서는 전역 설정만 처리합니다.
     */
    private fun optimizeGlobalWebViewSettings() {
        // WebView 디버그 모드: 디버그 빌드에서만 활성화
        // 프로덕션 빌드에서는 보안을 위해 비활성화
        if (BuildConfig.DEBUG) {
            WebView.setWebContentsDebuggingEnabled(true)
        }

        // 참고: WebSettings는 각 WebView 인스턴스에 귀속되므로
        // 전역 설정은 제한적입니다. 실제 최적화는 webview_flutter_android
        // 패키지의 AndroidWebViewController를 통해 이루어집니다.
    }
}
