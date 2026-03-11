import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/constants.dart';

/// 핀코드 입력 위젯 (시스템 키패드 사용)
/// 은행 앱 스타일의 PIN 입력 UI
class PinCodeInput extends StatefulWidget {
  final int minLength; // 최소 자릿수 (기본 4)
  final int maxLength; // 최대 자릿수 (기본 6)
  final ValueChanged<String> onCompleted; // 입력 완료 시 콜백
  final String? errorMessage; // 에러 메시지
  final bool autoSubmit; // maxLength 도달 시 자동 제출

  const PinCodeInput({
    super.key,
    this.minLength = 4,
    this.maxLength = 6,
    required this.onCompleted,
    this.errorMessage,
    this.autoSubmit = true,
  });

  @override
  State<PinCodeInput> createState() => _PinCodeInputState();
}

class _PinCodeInputState extends State<PinCodeInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  // TextField의 TextInput 클라이언트를 강제로 재등록하기 위한 Key
  Key _textFieldKey = UniqueKey();
  String _pin = '';

  @override
  void initState() {
    super.initState();
    // TextField 값 변경 감지
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(PinCodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 에러 발생 시 PIN 초기화
    if (widget.errorMessage != null && oldWidget.errorMessage == null) {
      setState(() {
        _pin = '';
        _controller.clear();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// TextField 값 변경 시
  void _onTextChanged() {
    final text = _controller.text;

    // 숫자만 허용
    if (text.isNotEmpty && !RegExp(r'^[0-9]+$').hasMatch(text)) {
      _controller.text = _pin;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _pin.length),
      );
      return;
    }

    setState(() {
      _pin = text;
    });

    // 자동 제출 활성화 & 최대 길이 도달 시
    if (widget.autoSubmit && _pin.length == widget.maxLength) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_pin.length >= widget.minLength) {
          widget.onCompleted(_pin);
        }
      });
    }
  }

  /// 핀 동그라미를 탭했을 때 시스템 키패드를 다시 보여주기 위한 유틸리티
  /// - 일부 단말에서 같은 TextInput 클라이언트로 연속 `show` 요청 시 무시되는 이슈가 있어
  ///   "언포커스 → 다음 프레임에 리포커스"로 클라이언트를 재등록한 뒤 `show`를 요청
  void _showKeyboard() {
    final scope = FocusScope.of(context);

    // 1) 포커스가 없으면 즉시 포커스 및 show 요청
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
      return;
    }

    // 2) 이미 포커스가 있다면 클라이언트를 재등록하기 위해 잠시 언포커스했다가
    //    다음 프레임에 다시 포커스를 주고 show 요청
    scope.unfocus();
    // 새로운 클라이언트 생성을 유도하기 위해 Key 갱신
    setState(() {
      _textFieldKey = UniqueKey();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      // 소수의 단말에서 프레임 타이밍 이슈가 있어 아주 짧은 지연 후 호출
      Future<void>.delayed(const Duration(milliseconds: 1), () {
        SystemChannels.textInput.invokeMethod('TextInput.show');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasError = widget.errorMessage != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 핀코드 표시 영역 (클릭하면 키패드 표시)
        GestureDetector(
          // 동그라미 영역을 탭하면 시스템 키패드를 다시 표시
          onTap: _showKeyboard,
          child: _buildPinDisplay(colorScheme, hasError),
        ),
        const SizedBox(height: 16),

        // 에러 메시지
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              widget.errorMessage!,
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: AppConstants.fontFamilySmall,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        // 숨겨진 TextField (시스템 키패드를 띄우기 위함)
        // 일부 기기에서 0 크기 위젯은 키패드가 재호출되지 않는 문제가 있어
        // 최소 크기를 유지하고 Opacity 0으로 표시
        SizedBox(
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0.0,
            child: TextField(
              key: _textFieldKey,
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: widget.maxLength,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
              style: const TextStyle(color: Colors.transparent),
            ),
          ),
        ),

        // 키패드 영역 표시 (터치하면 포커스)
        GestureDetector(
          // 키패드 영역을 탭해도 동일하게 키패드를 표시
          onTap: _showKeyboard,
          child: Container(
            width: 300,
            height: 200,
            color: Colors.transparent,
            child: Center(),
          ),
        ),
      ],
    );
  }

  /// 핀코드 동그라미 표시
  Widget _buildPinDisplay(ColorScheme colorScheme, bool hasError) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.maxLength, (index) {
        final isFilled = index < _pin.length;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: hasError
                ? colorScheme.error.withValues(alpha: 0.3)
                : (isFilled ? colorScheme.primary : Colors.transparent),
            shape: BoxShape.circle,
            border: Border.all(
              color: hasError ? colorScheme.error : colorScheme.outline,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}
