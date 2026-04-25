import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

/// Play button only when **remote** metadata says the asset is ready:
/// - `metadata.status` is `ready` / `completed` / `processed`, or
/// - `metadata.playback_url` / `playbackUrl` is set (server merged Gumlet output).
///
/// While `status` is `processing` / `pending` / `uploading`, shows loading — even
/// if `source` is already an `https` URL (upload may have finished but pipeline not).
bool audioMessageShowsPlayButton(types.AudioMessage m) {
  final meta = m.metadata;
  if (meta != null) {
    final playback = meta['playback_url'] ?? meta['playbackUrl'];
    if (playback is String && playback.trim().isNotEmpty) {
      return true;
    }
  }

  final raw = m.metadata?['status'];
  if (raw == null) return true;
  if (raw == true) return true;
  if (raw is num && raw == 1) return true;
  if (raw is String) {
    final s = raw.trim().toLowerCase();
    if (s == 'processing' || s == 'pending' || s == 'uploading') {
      return false;
    }
    return s == 'ready' || s == 'completed' || s == 'processed';
  }
  return false;
}
