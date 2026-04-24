import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/supabase.dart';
import 'presence_state.dart';

class PresenceCubit extends Cubit<PresenceState> {
  PresenceCubit() : super(PresenceInitial());

  RealtimeChannel? _presenceChannel;

  // FIX: Updated to expect a List of SinglePresenceState instead of a Map
  List<SinglePresenceState> currentPresence = [];

  void initializePresence() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // FIX: Wipe existing channel to prevent duplicate "ghost" subscriptions
    if (_presenceChannel != null) {
      disconnectPresence();
    }

    _presenceChannel = supabase.channel('online-users', opts: const RealtimeChannelConfig(self: true));

    _presenceChannel!
        .onPresenceSync((payload) {
      currentPresence = _presenceChannel!.presenceState();
      emit(PresenceUpdated(currentPresence));
    })
        .onPresenceJoin((payload) {
      currentPresence = _presenceChannel!.presenceState();
      emit(PresenceUpdated(currentPresence));
    })
        .onPresenceLeave((payload) {
      currentPresence = _presenceChannel!.presenceState();
      emit(PresenceUpdated(currentPresence));
    })
        .subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _presenceChannel!.track({
          'user_id': userId,
          'status': 'online',
          'online_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<void> updatePresenceStatus(String status) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || _presenceChannel == null) return;

    await _presenceChannel!.track({
      'user_id': userId,
      'status': status,
      'online_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> untrackPresence() async {
    await _presenceChannel?.untrack();
  }

  void disconnectPresence() {
    _presenceChannel?.unsubscribe();
    _presenceChannel = null;
  }

  @override
  Future<void> close() {
    disconnectPresence();
    return super.close();
  }
}