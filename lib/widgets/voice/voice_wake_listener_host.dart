import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../view_models/home/voice_command_viewmodel.dart';

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
    return widget.child;
  }
}
