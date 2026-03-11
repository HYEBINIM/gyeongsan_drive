import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../view_models/home/voice_command_viewmodel.dart';
import 'wake_query_listening_modal.dart';

class VoiceWakeListenerHost extends StatefulWidget {
  const VoiceWakeListenerHost({super.key, required this.child});

  final Widget child;

  @override
  State<VoiceWakeListenerHost> createState() => _VoiceWakeListenerHostState();
}

class _VoiceWakeListenerHostState extends State<VoiceWakeListenerHost>
    with WidgetsBindingObserver {
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool? _lastAuthenticated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncPassiveWakeAvailability();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isAuthenticated = context.watch<AuthProvider>().isAuthenticated;
    if (_lastAuthenticated == isAuthenticated) {
      return;
    }

    _lastAuthenticated = isAuthenticated;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncPassiveWakeAvailability();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _syncPassiveWakeAvailability();
  }

  Future<void> _syncPassiveWakeAvailability() async {
    final authProvider = context.read<AuthProvider>();
    final voiceViewModel = context.read<VoiceCommandViewModel>();
    await voiceViewModel.syncPassiveWakeAvailability(
      isForeground: _lifecycleState == AppLifecycleState.resumed,
      isAuthenticated: authProvider.isAuthenticated,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceCommandViewModel>(
      builder: (context, viewModel, _) {
        final showWakeQueryModal = viewModel.shouldShowWakeQueryModal;

        return PopScope(
          canPop: !showWakeQueryModal,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop || !showWakeQueryModal) {
              return;
            }
            await context.read<VoiceCommandViewModel>().dismissWakeQueryModal();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (showWakeQueryModal)
                Positioned.fill(
                  child: WakeQueryListeningModal(
                    title: '듣고 있습니다',
                    message: '원하시는 기능을 말씀하세요',
                    onClose: () {
                      context
                          .read<VoiceCommandViewModel>()
                          .dismissWakeQueryModal();
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
