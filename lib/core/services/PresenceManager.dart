import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/chat/presentation/bloc/presence_cubit.dart';
import 'RealtimeUserService.dart';

class PresenceManager extends StatefulWidget {
  final Widget child;
  const PresenceManager({super.key, required this.child});

  @override
  State<PresenceManager> createState() => _PresenceManagerState();
}

class _PresenceManagerState extends State<PresenceManager> with WidgetsBindingObserver {
  // 1. Create member variables to hold cubit instances.
  late final PresenceCubit _presenceCubit;
  late final AuthCubit _authCubit;

  (String, String)? _resolvePresenceIdentity() {
    // 2. Use the stored _authCubit instead of context.read().
    final authState = _authCubit.state;
    if (authState is! Authenticated) return null;
    final userId = authState.user.id.trim();
    final compoundId = (authState.selectedCompoundId ?? '').trim();
    if (userId.isEmpty || compoundId.isEmpty) return null;
    return (userId, compoundId);
  }

  @override
  void initState() {
    super.initState();

    // 3. Get the cubit instances ONCE and store them.
    _presenceCubit = context.read<PresenceCubit>();
    _authCubit = context.read<AuthCubit>();

    // Start listening to app lifecycle events
    WidgetsBinding.instance.addObserver(this);

    final identity = _resolvePresenceIdentity();
    if (identity != null) {
      _presenceCubit.initializePresence(
        userId: identity.$1,
        compoundId: identity.$2,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      RealtimeUserService.instance.init(context);
    });

  }

  @override
  void dispose() {
    // Stop listening to app lifecycle events
    WidgetsBinding.instance.removeObserver(this);
    RealtimeUserService.instance.dispose();
    // 4. Safely use the stored instance in dispose().
    _presenceCubit.disconnectPresence();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;

    // 5. Use the stored instances here as well.
    if (state == AppLifecycleState.resumed) {
      // App is in the foreground
      final identity = _resolvePresenceIdentity();
      if (identity != null) {
        _presenceCubit.initializePresence(
          userId: identity.$1,
          compoundId: identity.$2,
        );
      } else {
        _presenceCubit.updatePresenceStatus('online');
      }
    } else {
      // App is in the background or closed, untrack to send a "leave" event
      _presenceCubit.untrackPresence();
    }
  }


  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}