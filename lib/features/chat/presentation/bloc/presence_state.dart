import 'package:supabase_flutter/supabase_flutter.dart';

abstract class PresenceState {}

class PresenceInitial extends PresenceState {}

class PresenceUpdated extends PresenceState {
  // Update this to accept the List type as well
  final List<SinglePresenceState> currentPresence;

  PresenceUpdated(this.currentPresence);
}