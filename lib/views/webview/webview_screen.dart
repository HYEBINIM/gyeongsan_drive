import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// 웹뷰 화면 - URL을 받아 앱 내에서 웹사이트 표시
class WebViewScreen extends StatefulWidget {
  /// 로드할 웹사이트 URL
  final String url;

  /// 화면 상단에 표시될 제목 (선택사항)
  final String? title;

  const WebViewScreen({super.key, required this.url, this.title});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  /// 웹뷰 초기화 및 설정
  void _initializeWebView() async {
    // Platform Channel을 통한 네이티브 최적화 설정 적용
    await _optimizeWebViewSettings();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // JavaScript 활성화
      ..setNavigationDelegate(
        NavigationDelegate(
          // 페이지 로딩 시작
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          // 페이지 로딩 완료
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          // 웹 리소스 에러 처리
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _errorMessage = '페이지를 불러올 수 없습니다.\n${error.description}';
            });
          },
        ),
      );

    // controller 초기화 완료를 UI에 반영
    setState(() {});

    // Android 전용 성능 최적화 설정
    if (Platform.isAndroid) {
      final androidController =
          _controller!.platform as AndroidWebViewController;

      // Wide Viewport: 데스크톱 사이트를 모바일 화면에 맞게 축소
      await androidController.setUseWideViewPort(true);

      // 미디어 자동재생 차단 (초기 로딩 속도 향상)
      await androidController.setMediaPlaybackRequiresUserGesture(true);

      // Geolocation 활성화 (위치 기반 서비스용)
      await androidController.setGeolocationEnabled(true);
    }

    // 배경색 설정 (깜빡임 방지)
    await _controller!.setBackgroundColor(const Color(0xFF1C1B1F));

    // 데스크톱 브라우저로 인식 (데스크톱 버전 웹사이트 로드)
    await _controller!.setUserAgent(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    );

    // 줌 기능 활성화 (핀치 제스처로 확대/축소)
    await _controller!.enableZoom(true);

    // URL 로드
    await _controller!.loadRequest(Uri.parse(widget.url));
  }

  /// Platform Channel을 통해 네이티브 WebView 설정 최적화
  Future<void> _optimizeWebViewSettings() async {
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('webview_settings');
        await platform.invokeMethod('optimizeWebViewSettings');
      } catch (e) {
        // 에러 무시 (선택적 최적화)
      }
    }
  }

  /// 페이지 새로고침
  Future<void> _refresh() async {
    await _controller?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? '웹페이지'),
        actions: [
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 웹뷰 또는 에러 메시지 표시
          if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 시도'),
                  ),
                ],
              ),
            )
          else if (_controller == null)
            const Center(child: CircularProgressIndicator())
          else
            WebViewWidget(controller: _controller!),

          // 로딩 인디케이터
          if (_isLoading)
            Container(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.8),
              child: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
