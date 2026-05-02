import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../presentation/bloc/auth_cubit.dart';
import '../presentation/bloc/auth_state.dart';
import '../../../core/services/PresenceManager.dart';
import '../../../core/services/app_permissions.dart';
import '../../home/presentation/pages/main_screen.dart';

class AuthReadyGate extends StatefulWidget {
  const AuthReadyGate({super.key});

  @override
  State<AuthReadyGate> createState() => _AuthReadyGateState();
}

class _AuthReadyGateState extends State<AuthReadyGate> {
  late Future<void> _initFuture;
  bool _scheduledPermissionsWelcome = false;

  Future<void> _init() async {
    final authCubit = context.read<AuthCubit>();
    // If we are already authenticated with a role, don't re-trigger initialization
    // This prevents the infinite loop when main.dart rebuilds.
    final state = authCubit.state;
    if (state is Authenticated && state.role != null) {
      debugPrint('AuthReadyGate: Already authenticated with role, skipping initialization');
      return;
    }
    await authCubit.initializeAuthSession();
  }

  void _maybeShowPermissionsWelcome() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showPermissionsWelcomeDialogIfNeeded(context);
    });
  }

  @override
  void initState() {
    super.initState();
    _initFuture = _init();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        if (snapshot.hasError) {
          debugPrint(
            'AuthReadyGate: initializeAuthSession failed: ${snapshot.error}\n'
            '${snapshot.stackTrace}',
          );
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText(
                  'Startup failed:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (!_scheduledPermissionsWelcome) {
          _scheduledPermissionsWelcome = true;
          _maybeShowPermissionsWelcome();
        }
        return PresenceManager(child: MainScreen());
      },
    );
  }
}