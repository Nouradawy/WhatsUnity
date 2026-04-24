import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/chat/presentation/bloc/presence_cubit.dart';
import 'RealtimeUserService.dart';

class PresenceManager extends StatefulWidget {
  final Widget child;
  const PresenceManager({super.key, required this.child});

  @override
  State<PresenceManager> createState() => _PresenceManagerState();
}

class _PresenceManagerState extends State<PresenceManager> with WidgetsBindingObserver {
  // 1. Create a member variable to hold the PresenceCubit instance.
  late final PresenceCubit _presenceCubit;

  @override
  void initState() {
    super.initState();

    // 2. Get the PresenceCubit instance ONCE and store it in the member variable.
    _presenceCubit = context.read<PresenceCubit>();

    // Start listening to app lifecycle events
    WidgetsBinding.instance.addObserver(this);

    // Initialize the global presence channel using the stored instance
    _presenceCubit.initializePresence();

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
    // 3. Safely use the stored instance in dispose(). Do NOT use context.read() here.
    _presenceCubit.disconnectPresence();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 4. Use the stored instance here as well for consistency and safety.
    if (state == AppLifecycleState.resumed) {
      // App is in the foreground
      _presenceCubit.updatePresenceStatus('online');
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