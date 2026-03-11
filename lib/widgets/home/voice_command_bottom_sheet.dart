// UTF-8 인코딩 파일
// 한국어 주석: 음성 명령 Bottom Sheet UI (Spotify 테마)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/voice/voice_state.dart';
import '../../view_models/home/voice_command_viewmodel.dart';
import 'conversation_widgets.dart';

/// 음성 명령 Bottom Sheet
/// 음성 인식 상태와 AI 응답을 표시하는 UI
class VoiceCommandBottomSheet extends StatelessWidget {
  /// 쿼리 접두사 ("차량 {MT_ID}" 또는 "현재위치 {위도},{경도}")
  final String queryPrefix;

  /// 바텀시트가 닫힐 때 호출되는 콜백 (마커 초기화용)
  final VoidCallback? onClosed;

  const VoiceCommandBottomSheet({
    super.key,
    required this.queryPrefix,
    this.onClosed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 한국어 주석: 뒤로가기 버튼 시 음성 인식/출력 리소스 정리 후 닫기
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // 음성 인식/출력 중지
          final viewModel = context.read<VoiceCommandViewModel>();
          viewModel.stopListening();
          viewModel.stopSpeaking();
          // 한국어 주석: 바텀시트 닫힐 때 콜백 호출
          onClosed?.call();
          Navigator.pop(context);
        }
      },
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들 바
              _buildHandle(colorScheme),

              // 헤더
              _buildHeader(context, colorScheme),

              const SizedBox(height: 16),

              // 콘텐츠
              Flexible(
                child: Consumer<VoiceCommandViewModel>(
                  builder: (context, viewModel, _) {
                    return _buildContent(context, colorScheme, viewModel);
                  },
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 핸들 바
  Widget _buildHandle(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: colorScheme.outline,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// 헤더 (타이틀 + 닫기 버튼)
  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'AI 어시스턴트',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: colorScheme.onSurface),
            onPressed: () {
              // 음성 인식/출력 중지
              final viewModel = context.read<VoiceCommandViewModel>();
              viewModel.stopListening();
              viewModel.stopSpeaking();
              // 한국어 주석: 바텀시트 닫힐 때 콜백 호출
              onClosed?.call();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  /// 콘텐츠 (상태별 UI)
  Widget _buildContent(
    BuildContext context,
    ColorScheme colorScheme,
    VoiceCommandViewModel viewModel,
  ) {
    final state = viewModel.state;

    switch (state) {
      case VoiceCommandState.listening:
        return _buildListeningUI(colorScheme, viewModel);

      case VoiceCommandState.processing:
        return _buildProcessingUI(colorScheme, viewModel);

      case VoiceCommandState.speaking:
      case VoiceCommandState.completed:
        return _buildResponseUI(context, colorScheme, viewModel);

      case VoiceCommandState.error:
        return _buildErrorUI(context, colorScheme, viewModel);

      case VoiceCommandState.idle:
        return _buildIdleUI(colorScheme);
    }
  }

  /// 대기 상태 UI
  Widget _buildIdleUI(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_none,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '마이크 버튼을 눌러\n음성 명령을 시작하세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// 듣는 중 UI (파형 애니메이션 또는 히스토리)
  Widget _buildListeningUI(
    ColorScheme colorScheme,
    VoiceCommandViewModel viewModel,
  ) {
    if (viewModel.conversationHistory.isEmpty) {
      // 첫 대화: 기존 파형 애니메이션 UI
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 한국어 주석: 파형을 고정 높이 컨테이너로 감싸서 텍스트가 움직이지 않도록 함
            SizedBox(
              height: 50,
              child: Center(
                child: _WaveformAnimation(color: colorScheme.primary),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              '듣고 있습니다...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '말씀하세요',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      );
    }

    // 연속 대화: 히스토리 + 상단 배너
    return Column(
      children: [
        const ListeningBanner(),
        Expanded(
          child: ConversationHistoryView(
            history: viewModel.conversationHistory,
          ),
        ),
      ],
    );
  }

  /// 처리 중 UI
  Widget _buildProcessingUI(
    ColorScheme colorScheme,
    VoiceCommandViewModel viewModel,
  ) {
    // 한국어 주석: 처리 중 UI는 히스토리 리스트의 "현재 대화" 카드에 스피너를 표시
    return ConversationHistoryView(
      history: viewModel.conversationHistory,
      currentUserInput: viewModel.userInput,
      currentAIResponse: '처리 중...',
      isSpeaking: false,
      isProcessing: true, // 상단에 작은 로딩 인디케이터 표시
    );
  }

  /// 응답 UI (대화 히스토리)
  Widget _buildResponseUI(
    BuildContext context,
    ColorScheme colorScheme,
    VoiceCommandViewModel viewModel,
  ) {
    // 한국어 주석:
    // - 중복 카드 문제 방지: 완료 상태에서는 현재 대화를 별도 표시하지 않음
    // - 말하는 중(speaking)일 때만 현재 대화(진행중 카드)를 표시
    final showCurrent = viewModel.isSpeaking;
    return ConversationHistoryView(
      history: viewModel.conversationHistory,
      currentUserInput: showCurrent ? viewModel.userInput : null,
      currentAIResponse: showCurrent ? viewModel.aiResponse : null,
      isSpeaking: viewModel.isSpeaking,
      isProcessing: false,
      onRetry: () {
        // 한국어 주석: 생성자에서 전달받은 queryPrefix 사용
        viewModel.startVoiceCommand(queryPrefix: queryPrefix);
      },
    );
  }

  /// 에러 UI
  Widget _buildErrorUI(
    BuildContext context,
    ColorScheme colorScheme,
    VoiceCommandViewModel viewModel,
  ) {
    // 에러 타입별 아이콘 및 색상
    final errorType = viewModel.sessionState.errorType;
    IconData errorIcon = Icons.error_outline;
    Color iconColor = colorScheme.error;

    if (errorType == VoiceErrorType.lowConfidence ||
        errorType == VoiceErrorType.noiseDetected) {
      errorIcon = Icons.hearing_disabled;
      iconColor = colorScheme.tertiary;
    } else if (errorType == VoiceErrorType.speechTimeout) {
      errorIcon = Icons.timer_off;
      iconColor = colorScheme.secondary;
    }

    // 한국어 주석: SingleChildScrollView로 감싸서 오버플로우 방지
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(errorIcon, size: 64, color: iconColor),

          const SizedBox(height: 16),

          Text(
            viewModel.errorMessage ?? '오류가 발생했습니다',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
          ),

          // 신뢰도 정보 표시 (lowConfidence 에러일 경우)
          if (errorType == VoiceErrorType.lowConfidence &&
              viewModel.confidence != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '인식 신뢰도: ${(viewModel.confidence! * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 추가 안내 메시지
          if (errorType == VoiceErrorType.lowConfidence ||
              errorType == VoiceErrorType.noiseDetected) ...[
            const SizedBox(height: 12),
            Text(
              '조용한 곳에서 마이크에 가까이 말씀해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // 재시도 가능한 에러: "다시 말하기" 버튼 표시
          if (viewModel.sessionState.canRetryVoiceRecognition) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // 한국어 주석: 생성자에서 전달받은 queryPrefix 사용
                  viewModel.startVoiceCommand(queryPrefix: queryPrefix);
                },
                icon: const Icon(Icons.mic, size: 20),
                label: const Text('다시 말하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 닫기 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                viewModel.reset();
                // 한국어 주석: 바텀시트 닫힐 때 콜백 호출
                onClosed?.call();
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                viewModel.sessionState.canRetryVoiceRecognition ? '닫기' : '확인',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 파형 애니메이션 위젯
class _WaveformAnimation extends StatefulWidget {
  final Color color;

  const _WaveformAnimation({required this.color});

  @override
  State<_WaveformAnimation> createState() => _WaveformAnimationState();
}

class _WaveformAnimationState extends State<_WaveformAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final delay = index * 0.2;
            final value = ((_controller.value + delay) % 1.0);
            final height = 20 + (30 * (1 - (value - 0.5).abs() * 2));

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: height,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }
}
