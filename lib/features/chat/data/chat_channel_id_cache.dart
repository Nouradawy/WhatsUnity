import 'package:shared_preferences/shared_preferences.dart';

/// Persists the Supabase `channels.id` for a [compoundId] + [channelName] (+ optional
/// building scope) so [GeneralChat] can open offline after at least one online visit.
abstract final class ChatChannelIdCache {
  static String _key(
    String compoundId,
    String channelName,
    String buildingSegment,
  ) =>
      'chat_channel_id_v1_${compoundId}_${channelName}_$buildingSegment';

  /// [buildingSegment]: use `'__general__'` for compound-wide chat; otherwise building name or id string.
  static Future<String?> read({
    required String compoundId,
    required String channelName,
    required String buildingSegment,
  }) async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key(compoundId, channelName, buildingSegment));
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static Future<void> write({
    required String compoundId,
    required String channelName,
    required String buildingSegment,
    required String channelId,
  }) async {
    if (channelId.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key(compoundId, channelName, buildingSegment), channelId);
  }
}
