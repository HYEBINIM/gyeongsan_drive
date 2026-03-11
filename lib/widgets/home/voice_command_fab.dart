// UTF-8 인코딩 파일
// 한국어 주석: 음성 명령 FAB 버튼 (Spotify 테마)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remixicon/remixicon.dart';
import '../../models/voice/voice_state.dart';
import '../../view_models/home/voice_command_viewmodel.dart';
import '../../services/permission/permission_service.dart';
import '../../utils/snackbar_utils.dart';
import 'voice_command_bottom_sheet.dart';

/// 음성 명령 FAB 버튼
/// Spotify Green 테마 적용 및 상태별 애니메이션
class VoiceCommandFAB extends StatefulWidget {
  /// 쿼리 접두사를 반환하는 콜백 함수
  /// - 홈 페이지: "차량 {MT_ID}"
  /// - 지역 정보 페이지: "현재위치 {위도},{경도}"
  final Future<String?> Function()? onGetQueryPrefix;
  // 한글 주석: FAB 사용 가능 여부
  final bool isEnabled;
  // 한글 주석: 비활성 상태 설명 메시지
  final String? disabledMessage;

  /// 음성 응답 완료 시 호출되는 콜백 (지도 마커 표시용)
  /// metadata가 있을 때만 호출됨
  ///
  /// [metadata]: API 응답 메타데이터
  /// [toolsUsed]: tools_used 필드 (카테고리 추론용)
  /// [originalQuery]: 원본 음성 쿼리 (카테고리 추론용)
  final void Function(
    Map<String, dynamic> metadata, {
    List<dynamic>? toolsUsed,
    String? originalQuery,
  })?
  onVoiceResponseComplete;

  /// 바텀시트가 닫힐 때 호출되는 콜백 (마커 초기화용)
  final VoidCallback? onBottomSheetClosed;

  const VoiceCommandFAB({
    super.key,
    this.onGetQueryPrefix,
    this.isEnabled = true,
    this.disabledMessage,
    this.onVoiceResponseComplete,
    this.onBottomSheetClosed,
  });

  @override
  State<VoiceCommandFAB> createState() => _VoiceCommandFABState();
}

class _VoiceCommandFABState extends State<VoiceCommandFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  // 한국어 주석: 이전 상태 추적 (speaking → completed 전환 감지용)
  VoiceCommandState? _previousState;
  bool _didLogProviderReadError = false;
  // 한국어 주석: 모달이 아닌 지속형 바텀시트 컨트롤러 (지도 제스처 허용)
  PersistentBottomSheetController? _bottomSheetController;

  @override
  void initState() {
    super.initState();

    // 펄스 애니메이션 설정 (듣는 중일 때 사용)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    // 한국어 주석: 위젯 폐기 시 열린 바텀시트가 있으면 닫아 리소스 정리
    _bottomSheetController?.close();
    _bottomSheetController = null;
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    VoiceCommandViewModel viewModel;
    try {
      viewModel = context.watch<VoiceCommandViewModel>();
      _didLogProviderReadError = false;
    } catch (e) {
      if (!_didLogProviderReadError) {
        debugPrint('[VoiceCommandFAB] VoiceCommandViewModel read failed: $e');
        _didLogProviderReadError = true;
      }
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
      return _buildUnavailableStateFab(context);
    }

    final isListening = viewModel.isListening;
    final isProcessing = viewModel.isProcessing;
    final colorScheme = Theme.of(context).colorScheme;
    final bool enabled = widget.isEnabled && !isProcessing;
    final currentState = viewModel.state;

    // 한국어 주석: processing → speaking 전환 감지 (TTS 재생 시작 시 지도 마커 표시)
    // 실제 상태 흐름: listening → processing → speaking
    if (_previousState == VoiceCommandState.processing &&
        currentState == VoiceCommandState.speaking) {
      final metadata = viewModel.sessionState.metadata;
      if (metadata != null && widget.onVoiceResponseComplete != null) {
        // 한국어 주석: tools_used와 원본 쿼리 추출
        // tools_used는 VoiceCommandResponse의 data 필드에 저장됨
        final data = viewModel.sessionState.data;
        final List<dynamic>? toolsUsed = data?['tools_used'] as List<dynamic>?;
        final originalQuery = viewModel.userInput;

        // 한국어 주석: PostFrameCallback으로 콜백 호출을 build 후로 지연
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onVoiceResponseComplete!(
            metadata,
            toolsUsed: toolsUsed,
            originalQuery: originalQuery,
          );
        });
      }
    }
    _previousState = currentState;

    // 듣는 중이면 펄스 애니메이션 시작
    if (isListening && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isListening && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isListening ? _pulseAnimation.value : 1.0,
          child: FloatingActionButton(
            onPressed: enabled
                ? () => _handleFABPress(context, viewModel)
                : () => _showDisabledFeedback(context),
            backgroundColor: enabled
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest, // Spotify Green
            foregroundColor: enabled
                ? colorScheme.onPrimary
                : colorScheme.onSurface, // 색 대비 유지
            elevation: enabled ? 8 : 0,
            child: isProcessing
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : Icon(
                    isListening
                        ? RemixIcons.mic_ai_fill
                        : RemixIcons.mic_ai_line,
                    size: 40,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildUnavailableStateFab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FloatingActionButton(
      onPressed: () => _showDisabledFeedback(context),
      backgroundColor: colorScheme.surfaceContainerHighest,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      child: const Icon(RemixIcons.mic_ai_line, size: 40),
    );
  }

  /// FAB 버튼 클릭 핸들러
  Future<void> _handleFABPress(
    BuildContext context,
    VoiceCommandViewModel viewModel,
  ) async {
    if (!widget.isEnabled) {
      _showDisabledFeedback(context);
      return;
    }

    // 마이크 권한 확인
    final hasPermission = await PermissionService()
        .requestMicrophonePermission();
    if (!hasPermission && context.mounted) {
      SnackBarUtils.showWarning(context, '마이크 권한이 필요합니다. 설정에서 마이크 권한을 허용해주세요.');
      return;
    }

    // 콜백으로 쿼리 접두사 가져오기
    String? queryPrefix;
    if (widget.onGetQueryPrefix != null) {
      queryPrefix = await widget.onGetQueryPrefix!();
    }

    // 쿼리 접두사 유효성 검증
    if (queryPrefix == null && context.mounted) {
      SnackBarUtils.showError(context, '정보를 가져올 수 없습니다. 다시 시도해주세요.');
      return;
    }

    if (!context.mounted) return;

    final state = viewModel.state;

    // 초기화가 안 되어 있으면 초기화
    if (state == VoiceCommandState.idle) {
      viewModel.initialize().then((_) {
        if (!context.mounted) return;

        if (viewModel.hasError) {
          // 초기화 실패 시 에러 표시
          SnackBarUtils.showError(
            context,
            viewModel.errorMessage ?? '초기화에 실패했습니다.',
          );
        } else {
          // 초기화 성공 → Bottom Sheet 표시 및 음성 인식 시작
          _showBottomSheetAndStartListening(context, viewModel, queryPrefix!);
        }
      });
    } else if (state == VoiceCommandState.listening) {
      // 이미 듣는 중이면 Bottom Sheet만 표시
      _showBottomSheet(context, queryPrefix!, viewModel);
    } else {
      // 다른 상태면 Bottom Sheet 표시 및 음성 인식 시작
      _showBottomSheetAndStartListening(context, viewModel, queryPrefix!);
    }
  }

  /// Bottom Sheet 표시
  void _showBottomSheet(
    BuildContext context,
    String queryPrefix,
    VoiceCommandViewModel viewModel,
  ) {
    // 한국어 주석: 이미 바텀시트가 열려 있으면 중복 오픈 방지
    if (_bottomSheetController != null) {
      return;
    }

    // 한국어 주석: 닫힘 콜백이 여러 경로에서 중복 호출되지 않도록 가드
    var didNotifyClose = false;
    void notifyBottomSheetClosed() {
      if (didNotifyClose) return;
      didNotifyClose = true;
      // ignore: discarded_futures
      viewModel.endManualSession();
      widget.onBottomSheetClosed?.call();
      _bottomSheetController = null;
    }

    final scaffoldState = Scaffold.maybeOf(context);
    if (scaffoldState == null) {
      return;
    }

    _bottomSheetController = scaffoldState.showBottomSheet(
      (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false, // 한국어 주석: 배경 지도 제스처를 살리기 위해 부모 높이 확장 방지
          builder: (context, scrollController) {
            return VoiceCommandBottomSheet(
              queryPrefix: queryPrefix,
              // 한국어 주석: 바텀시트 내부에서 닫힐 때 호출될 콜백 전달
              onClosed: notifyBottomSheetClosed,
            );
          },
        );
      },
      backgroundColor: Colors.transparent,
      elevation: 0,
      enableDrag: true,
    );

    _bottomSheetController?.closed.whenComplete(() {
      // 한국어 주석: 스와이프/외부 닫힘 등 모든 경로에서 마커 초기화 보장
      notifyBottomSheetClosed();
    });
  }

  /// Bottom Sheet ǥ�� �� ���� �ν� ����
  void _showBottomSheetAndStartListening(
    BuildContext context,
    VoiceCommandViewModel viewModel,
    String queryPrefix, // �� ���� ���λ� �Ķ����
  ) {
    // Bottom Sheet ǥ�� (queryPrefix ����)
    _showBottomSheet(context, queryPrefix, viewModel);

    // ���� �ν� ���� (���� ���λ� ����)
    // ignore: discarded_futures
    viewModel.startVoiceCommand(queryPrefix: queryPrefix);
  }

  /// 한국 주석: 비활성화 상태 안내
  void _showDisabledFeedback(BuildContext context) {
    final message =
        widget.disabledMessage ?? "차량을 등록하거나 데이터가 준비되면 음성 명령을 사용할 수 있어요.";
    SnackBarUtils.showWarning(context, message);
  }
}
