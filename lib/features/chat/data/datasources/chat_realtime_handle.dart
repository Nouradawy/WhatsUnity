import 'dart:async';

/// Stops chat database realtime delivery (replaces Supabase [RealtimeChannel] for Appwrite).
class ChatRealtimeHandle {
  ChatRealtimeHandle({required Future<void> Function() close}) : _close = close;

  final Future<void> Function() _close;

  void unsubscribe() {
    unawaited(_close());
  }
}
