import 'dart:async';

import 'package:WhatsUnity/core/config/Enums.dart';
import 'package:WhatsUnity/core/di/app_services.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MentionNotificationState {
  final int unreadGeneralMentionCount;
  final int unreadBuildingMentionCount;
  final bool isLoading;

  const MentionNotificationState({
    required this.unreadGeneralMentionCount,
    required this.unreadBuildingMentionCount,
    required this.isLoading,
  });

  int get totalUnreadMentionCount =>
      unreadGeneralMentionCount + unreadBuildingMentionCount;

  // Backward-compatible alias for existing listeners/selectors.
  int get unreadMentionCount => totalUnreadMentionCount;

  factory MentionNotificationState.initial() => const MentionNotificationState(
        unreadGeneralMentionCount: 0,
        unreadBuildingMentionCount: 0,
        isLoading: false,
      );

  MentionNotificationState copyWith({
    int? unreadGeneralMentionCount,
    int? unreadBuildingMentionCount,
    bool? isLoading,
  }) {
    return MentionNotificationState(
      unreadGeneralMentionCount:
          unreadGeneralMentionCount ?? this.unreadGeneralMentionCount,
      unreadBuildingMentionCount:
          unreadBuildingMentionCount ?? this.unreadBuildingMentionCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Computes unread mention count from Appwrite chat messages.
///
/// The badge is channel-scoped (compound general + building chat) and uses
/// client-side "last seen" timestamps per user/channel.
class MentionNotificationCubit extends Cubit<MentionNotificationState> {
  MentionNotificationCubit() : super(MentionNotificationState.initial());

  Timer? _refreshTimer;
  String? _activeUserId;
  String? _activeCompoundId;
  String? _activeBuilding;
  _MentionAuthSnapshot? _activeSnapshot;
  bool _isRefreshInProgress = false;
  int _refreshRequestToken = 0;

  static const Duration _refreshInterval = Duration(seconds: 20);
  static const int _kPerChannelMessageScanLimit = 80;

  /// Refreshes mention matching when [Authenticated.currentUser] profile fields
  /// or [Authenticated.role] change without altering the stable shell key
  /// (user / compound / building). Otherwise [_activeSnapshot] stays stale,
  /// [_isMentioningCurrentUser] never sees @displayName, and badges stay at 0.
  void syncMentionDetectionFromAuth(Authenticated authState) {
    final uid = authState.user.id.trim();
    final cid = authState.selectedCompoundId?.trim();
    if (uid.isEmpty || cid == null || cid.isEmpty) return;
    if (_activeUserId == null || _activeCompoundId == null) return;
    if (uid != _activeUserId || cid != _activeCompoundId) return;

    final nextSnapshot = _MentionAuthSnapshot.fromAuthState(authState);
    final prev = _activeSnapshot;
    final detectionChanged = prev == null ||
        prev.currentUserDisplayName != nextSnapshot.currentUserDisplayName ||
        prev.role != nextSnapshot.role;
    _activeSnapshot = nextSnapshot;
    if (detectionChanged) {
      unawaited(_refreshUnreadMentionsFromSnapshot(nextSnapshot));
    }
  }

  /// Starts mention polling for the current authenticated context.
  Future<void> startForAuthState(Authenticated authState) async {
    final nextUserId = authState.user.id.trim();
    final nextCompoundId = authState.selectedCompoundId?.trim();
    final nextBuilding = authState.currentUser?.building.trim();
    if (nextUserId.isEmpty || nextCompoundId == null || nextCompoundId.isEmpty) {
      stop();
      return;
    }

    final contextChanged = _activeUserId != nextUserId ||
        _activeCompoundId != nextCompoundId ||
        _activeBuilding != nextBuilding;
    final prevSnapshot = _activeSnapshot;
    final nextSnapshot = _MentionAuthSnapshot.fromAuthState(authState);
    final mentionDetectionChanged = prevSnapshot == null ||
        prevSnapshot.currentUserDisplayName !=
            nextSnapshot.currentUserDisplayName ||
        prevSnapshot.role != nextSnapshot.role;

    _activeUserId = nextUserId;
    _activeCompoundId = nextCompoundId;
    _activeBuilding = nextBuilding;
    _activeSnapshot = nextSnapshot;

    if (contextChanged || mentionDetectionChanged) {
      await refreshUnreadMentions(authState);
    }

    _refreshTimer ??= Timer.periodic(_refreshInterval, (_) {
      final snapshot = _activeSnapshot;
      if (snapshot == null) return;
      _refreshUnreadMentionsFromSnapshot(snapshot);
    });
  }

  Future<void> refreshUnreadMentions(Authenticated authState) async {
    await _refreshUnreadMentionsFromSnapshot(
      _MentionAuthSnapshot.fromAuthState(authState),
    );
  }

  /// Force-refreshes unread mentions, bypassing the [_isRefreshInProgress] lock
  /// if necessary (e.g. on app resume).
  Future<void> refreshUnreadMentionsForce(Authenticated authState) async {
    _isRefreshInProgress = false;
    await refreshUnreadMentions(authState);
  }

  Future<void> _refreshUnreadMentionsFromSnapshot(
    _MentionAuthSnapshot snapshot,
  ) async {
    if (_isRefreshInProgress) return;
    final compoundId = snapshot.selectedCompoundId.trim();
    final userId = snapshot.userId.trim();
    if (compoundId.isEmpty || userId.isEmpty) return;

    _isRefreshInProgress = true;
    final requestToken = ++_refreshRequestToken;
    // Silent poll: do not emit isLoading toggles — they fire BlocObserver onChange twice
    // every [_refreshInterval] even when counts are unchanged (no Equatable on state).
    final nowUtc = DateTime.now().toUtc();
    try {
      final countByScope = await _remote_countUnreadMentions(
        snapshot: snapshot,
        nowUtc: nowUtc,
      );
      if (requestToken != _refreshRequestToken) return;
      final nextGeneral = countByScope['COMPOUND_GENERAL'] ?? 0;
      final nextBuilding = countByScope['BUILDING_CHAT'] ?? 0;
      if (state.unreadGeneralMentionCount != nextGeneral ||
          state.unreadBuildingMentionCount != nextBuilding) {
        emit(
          state.copyWith(
            unreadGeneralMentionCount: nextGeneral,
            unreadBuildingMentionCount: nextBuilding,
            isLoading: false,
          ),
        );
      }
    } catch (_) {
      if (requestToken != _refreshRequestToken) return;
    } finally {
      _isRefreshInProgress = false;
    }
  }

  Future<void> markGeneralMentionsAsSeen(Authenticated authState) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = authState.user.id.trim();
    final compoundId = authState.selectedCompoundId?.trim();
    if (userId.isEmpty || compoundId == null || compoundId.isEmpty) return;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    await prefs.setString(
      _lastSeenKey(
        userId: userId,
        compoundId: compoundId,
        channelScope: 'COMPOUND_GENERAL',
      ),
      nowIso,
    );
    if (state.unreadGeneralMentionCount != 0) {
      emit(state.copyWith(unreadGeneralMentionCount: 0));
    }
  }

  Future<void> markBuildingMentionsAsSeen(Authenticated authState) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = authState.user.id.trim();
    final compoundId = authState.selectedCompoundId?.trim();
    if (userId.isEmpty || compoundId == null || compoundId.isEmpty) return;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final buildingName = authState.currentUser?.building.trim();
    if (buildingName != null && buildingName.isNotEmpty) {
      await prefs.setString(
        _lastSeenKey(
          userId: userId,
          compoundId: compoundId,
          channelScope: 'BUILDING_CHAT:$buildingName',
        ),
        nowIso,
      );
    }
    if (state.unreadBuildingMentionCount != 0) {
      emit(state.copyWith(unreadBuildingMentionCount: 0));
    }
  }

  void stop() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _activeUserId = null;
    _activeCompoundId = null;
    _activeBuilding = null;
    _activeSnapshot = null;
    emit(MentionNotificationState.initial());
  }

  Future<Map<String, int>> _remote_countUnreadMentions({
    required _MentionAuthSnapshot snapshot,
    required DateTime nowUtc,
  }) async {
    final userId = snapshot.userId.trim();
    final compoundId = snapshot.selectedCompoundId.trim();
    final buildingName = snapshot.currentUserBuilding?.trim();

    final channels = await _remote_resolveTrackedChannels(
      compoundId: compoundId,
      buildingName: buildingName,
    );
    if (channels.isEmpty) {
      return const {
        'COMPOUND_GENERAL': 0,
        'BUILDING_CHAT': 0,
      };
    }

    final prefs = await SharedPreferences.getInstance();
    final countByScope = <String, int>{
      'COMPOUND_GENERAL': 0,
      'BUILDING_CHAT': 0,
    };
    for (final channel in channels) {
      final key = _lastSeenKey(
        userId: userId,
        compoundId: compoundId,
        channelScope: channel.scopeKey,
      );
      final lastSeenIso = prefs.getString(key);
      final lastSeenAt = DateTime.tryParse(lastSeenIso ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

      final rows = await AppServices.chatRemoteDataSource.remote_fetchMessages(
        channelId: channel.channelId,
        currentUserId: userId,
        pageSize: _kPerChannelMessageScanLimit,
        pageNum: 0,
      );
      for (final row in rows) {
        final authorId = row['author_id']?.toString().trim();
        if (authorId == null || authorId.isEmpty || authorId == userId) continue;
        final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '')
            ?.toUtc();
        if (createdAt == null ||
            createdAt.isBefore(lastSeenAt) ||
            createdAt.isAfter(nowUtc)) {
          continue;
        }
        final messageText = row['text']?.toString() ?? '';
        if (_isMentioningCurrentUser(messageText, snapshot)) {
          final groupKey = channel.groupKey;
          countByScope[groupKey] = (countByScope[groupKey] ?? 0) + 1;
        }
      }
    }
    return countByScope;
  }

  bool _isMentioningCurrentUser(String text, _MentionAuthSnapshot snapshot) {
    final normalizedText = text.toLowerCase();
    final displayName = snapshot.currentUserDisplayName?.trim() ?? '';
    final mentionToken = displayName.isEmpty
        ? ''
        : '@${displayName.replaceAll(' ', '_').toLowerCase()}';
    if (mentionToken.isNotEmpty && normalizedText.contains(mentionToken)) {
      return true;
    }
    if (normalizedText.contains('@everyone')) return true;
    if (snapshot.role == Roles.admin && normalizedText.contains('@admin')) {
      return true;
    }
    return false;
  }

  Future<List<_TrackedChannel>> _remote_resolveTrackedChannels({
    required String compoundId,
    required String? buildingName,
  }) async {
    final out = <_TrackedChannel>[];
    final generalChannelId =
        await AppServices.chatRepository.resolveChannelDocumentId(
      compoundId: compoundId,
      channelType: 'COMPOUND_GENERAL',
      buildingNameForScopedChat: null,
    );
    if (generalChannelId != null && generalChannelId.isNotEmpty) {
      out.add(
        _TrackedChannel(
          channelId: generalChannelId,
          scopeKey: 'COMPOUND_GENERAL',
          groupKey: 'COMPOUND_GENERAL',
        ),
      );
    }

    final bn = buildingName?.trim();
    if (bn != null && bn.isNotEmpty) {
      final buildingChannelId =
          await AppServices.chatRepository.resolveChannelDocumentId(
        compoundId: compoundId,
        channelType: 'BUILDING_CHAT',
        buildingNameForScopedChat: bn,
      );
      if (buildingChannelId != null && buildingChannelId.isNotEmpty) {
        out.add(
          _TrackedChannel(
            channelId: buildingChannelId,
            scopeKey: 'BUILDING_CHAT:$bn',
            groupKey: 'BUILDING_CHAT',
          ),
        );
      }
    }
    return out;
  }

  String _lastSeenKey({
    required String userId,
    required String compoundId,
    required String channelScope,
  }) {
    return 'mentions_last_seen_${userId}_${compoundId}_$channelScope';
  }

  @override
  Future<void> close() {
    _refreshTimer?.cancel();
    return super.close();
  }
}

class _TrackedChannel {
  final String channelId;
  final String scopeKey;
  final String groupKey;

  const _TrackedChannel({
    required this.channelId,
    required this.scopeKey,
    required this.groupKey,
  });
}

class _MentionAuthSnapshot {
  final String userId;
  final Roles? role;
  final String selectedCompoundId;
  final String? currentUserBuilding;
  final String? currentUserDisplayName;

  const _MentionAuthSnapshot({
    required this.userId,
    required this.role,
    required this.selectedCompoundId,
    required this.currentUserBuilding,
    required this.currentUserDisplayName,
  });

  factory _MentionAuthSnapshot.fromAuthState(Authenticated authState) {
    return _MentionAuthSnapshot(
      userId: authState.user.id,
      role: authState.role,
      selectedCompoundId: authState.selectedCompoundId ?? '',
      currentUserBuilding: authState.currentUser?.building,
      currentUserDisplayName: authState.currentUser?.displayName,
    );
  }

}
