/// One presence payload (maps to legacy Supabase realtime `payload` shape).
class PresencePayloadEntry {
  PresencePayloadEntry(this.payload);
  final Map<String, dynamic> payload;
}

/// One connected client's presence bundle for [ChatMember] status maps.
class SinglePresenceState {
  SinglePresenceState(this.presences);
  final List<PresencePayloadEntry> presences;
}

abstract class PresenceState {}

class PresenceInitial extends PresenceState {}

class PresenceUpdated extends PresenceState {
  final List<SinglePresenceState> currentPresence;

  PresenceUpdated(this.currentPresence);
}