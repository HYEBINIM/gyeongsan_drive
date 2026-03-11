// UTF-8 인코딩 파일
// 한국어 주석: 대화 UI 위젯 모음

import 'package:flutter/material.dart';
import '../../models/voice/voice_state.dart';

/// 사용자 입력 카드
class UserInputCard extends StatelessWidget {
  final String userInput;

  const UserInputCard({super.key, required this.userInput});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '사용자',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            userInput,
            style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

/// AI 응답 카드
class AIResponseCard extends StatelessWidget {
  final String aiResponse;
  // 한국어 주석: 음성 출력 중 여부(이퀄라이저 애니메이션 표시)
  final bool isSpeaking;
  // 한국어 주석: 처리 중 여부(로딩 인디케이터 표시)
  final bool isProcessing;
  final bool showRetryButton;
  final VoidCallback? onRetry;

  const AIResponseCard({
    super.key,
    required this.aiResponse,
    this.isSpeaking = false,
    this.isProcessing = false,
    this.showRetryButton = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Text(
                'AI 어시스턴트',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isSpeaking) ...[
                const SizedBox(width: 8),
                // 한국어 주석: 말하는 중에는 작은 스피커 애니메이션 표시
                SpeakingIndicator(color: colorScheme.primary, size: 18),
              ] else if (isProcessing) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // 응답 텍스트
          Text(
            aiResponse,
            style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
          ),

          // "다시 말하기" 버튼
          if (showRetryButton && !isSpeaking && onRetry != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.mic, size: 20),
                label: const Text('다시 말하기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 단일 대화 카드 (사용자 입력 + AI 응답)
class ConversationCard extends StatelessWidget {
  final String userInput;
  final String aiResponse;
  final bool showRetryButton;
  final bool isSpeaking;
  final bool isProcessing;
  final VoidCallback? onRetry;

  const ConversationCard({
    super.key,
    required this.userInput,
    required this.aiResponse,
    this.showRetryButton = false,
    this.isSpeaking = false,
    this.isProcessing = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UserInputCard(userInput: userInput),
        const SizedBox(height: 12),
        AIResponseCard(
          aiResponse: aiResponse,
          isSpeaking: isSpeaking,
          isProcessing: isProcessing,
          showRetryButton: showRetryButton,
          onRetry: onRetry,
        ),
      ],
    );
  }
}

/// 대화 히스토리 표시 위젯
class ConversationHistoryView extends StatefulWidget {
  final List<ConversationEntry> history;
  final String? currentUserInput;
  final String? currentAIResponse;
  // 한국어 주석: 현재 카드 상태 플래그들
  final bool isSpeaking;
  final bool isProcessing;
  final VoidCallback? onRetry;

  const ConversationHistoryView({
    super.key,
    required this.history,
    this.currentUserInput,
    this.currentAIResponse,
    this.isSpeaking = false,
    this.isProcessing = false,
    this.onRetry,
  });

  @override
  State<ConversationHistoryView> createState() =>
      _ConversationHistoryViewState();
}

class _ConversationHistoryViewState extends State<ConversationHistoryView> {
  // 한국어 주석: 최근 대화가 항상 보이도록 자동 스크롤 관리
  final ScrollController _controller = ScrollController();
  int _prevItemCount = 0;

  @override
  void initState() {
    super.initState();
    _prevItemCount = _computeItemCount();
    _scrollToEnd();
  }

  @override
  void didUpdateWidget(covariant ConversationHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newCount = _computeItemCount();
    final increased = newCount > _prevItemCount;
    final speakingChanged = widget.isSpeaking != oldWidget.isSpeaking;
    final processingChanged = widget.isProcessing != oldWidget.isProcessing;
    final contentChanged =
        widget.currentAIResponse != oldWidget.currentAIResponse ||
        widget.currentUserInput != oldWidget.currentUserInput;

    if (increased || speakingChanged || processingChanged || contentChanged) {
      _scrollToEnd();
    }
    _prevItemCount = newCount;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _computeItemCount() {
    final hasCurrent =
        widget.currentUserInput != null && widget.currentAIResponse != null;
    return widget.history.length + (hasCurrent ? 1 : 0);
  }

  void _scrollToEnd() {
    // 한국어 주석: 프레임 렌더 후 최대 위치로 스크롤(최근 대화 노출)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final position = _controller.position.maxScrollExtent;
      _controller.animateTo(
        position,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasCurrentConversation =
        widget.currentUserInput != null && widget.currentAIResponse != null;
    final itemCount = _computeItemCount();

    return ListView.separated(
      controller: _controller,
      padding: const EdgeInsets.all(20),
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index < widget.history.length) {
          // 이전 대화
          final entry = widget.history[index];
          // 한국어 주석:
          // - 말하는 중이 아니고(onSpeaking=false), onRetry가 제공되며,
          //   현재 대화 카드가 표시되지 않을 때(중복 방지)만 마지막 항목에 "다시 말하기" 버튼 표시
          final isLast = index == widget.history.length - 1;
          final busy = widget.isSpeaking || widget.isProcessing;
          final showRetryOnLast =
              !busy &&
              widget.onRetry != null &&
              !hasCurrentConversation &&
              isLast;
          return ConversationCard(
            userInput: entry.userInput,
            aiResponse: entry.aiResponse,
            showRetryButton: showRetryOnLast,
            isSpeaking: false,
            isProcessing: false,
            onRetry: showRetryOnLast ? widget.onRetry : null,
          );
        } else {
          // 현재 대화 (마지막)
          return ConversationCard(
            userInput: widget.currentUserInput!,
            aiResponse: widget.currentAIResponse!,
            showRetryButton: true,
            isSpeaking: widget.isSpeaking,
            isProcessing: widget.isProcessing,
            onRetry: widget.onRetry,
          );
        }
      },
    );
  }
}

/// 듣는 중 상단 배너
class ListeningBanner extends StatelessWidget {
  const ListeningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(Icons.mic, size: 20, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Text(
            '듣고 있습니다... 말씀하세요',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// 말하는 중(스피킹) 시각적 표시 위젯
/// 한국어 주석: 작은 파형 애니메이션으로 음성 출력 중임을 표시
class SpeakingIndicator extends StatefulWidget {
  final Color color;
  final double size;

  const SpeakingIndicator({super.key, required this.color, this.size = 16});

  @override
  State<SpeakingIndicator> createState() => _SpeakingIndicatorState();
}

class _SpeakingIndicatorState extends State<SpeakingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(3, (index) {
              // 한국어 주석: 각 바에 시간차를 두어 파형 효과 생성
              final delay = index * 0.3;
              final value = ((_controller.value + delay) % 1.0);
              final heightRatio = 0.4 + (0.6 * (1 - (value - 0.5).abs() * 2));

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                width: widget.size / 6,
                height: widget.size * heightRatio,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
