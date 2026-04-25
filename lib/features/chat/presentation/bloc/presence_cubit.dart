import 'package:flutter_bloc/flutter_bloc.dart';

import 'presence_state.dart';

/// Presence is a **non-critical** UX signal. Supabase Realtime was removed; this
/// cubit keeps the same surface so member lists render with "offline" until
/// [MIGRATION_PLAN.md] Phase-3 wires `presence_sessions` + Appwrite Realtime.
class PresenceCubit extends Cubit<PresenceState> {
  PresenceCubit() : super(PresenceInitial());

  List<SinglePresenceState> currentPresence = [];

  void initializePresence() {
    currentPresence = [];
    emit(PresenceUpdated(currentPresence));
  }

  Future<void> updatePresenceStatus(String status) async {}

  Future<void> untrackPresence() async {}

  void disconnectPresence() {
    currentPresence = [];
    emit(PresenceUpdated(currentPresence));
  }

  @override
  Future<void> close() {
    disconnectPresence();
    return super.close();
  }
}
