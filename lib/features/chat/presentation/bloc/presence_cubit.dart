import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:appwrite/appwrite.dart';

import '../../../../core/config/appwrite.dart';
import 'presence_state.dart';

/// Presence is a **non-critical** UX signal. Supabase Realtime was removed; this
/// cubit keeps the same surface so member lists render with "offline" until
/// [MIGRATION_PLAN.md] Phase-3 wires `presence_sessions` + Appwrite Realtime.
class PresenceCubit extends Cubit<PresenceState> {
  PresenceCubit() : super(PresenceInitial());

  List<SinglePresenceState> currentPresence = [];
  RealtimeSubscription? _presenceSubscription;
  String? _currentUserId;
  String? _currentCompoundId;

  static const String _kPresenceTableId = 'presence_sessions';

  Future<void> _refreshPresenceRows() async {
    final compoundId = _currentCompoundId;
    if (compoundId == null || compoundId.isEmpty) {
      currentPresence = [];
      emit(PresenceUpdated(currentPresence));
      return;
    }
    try {
      final rows = await appwriteTables.listRows(
        databaseId: appwriteDatabaseId,
        tableId: _kPresenceTableId,
        queries: [
          Query.equal('compound_id', compoundId),
          Query.orderDesc('last_seen_at'),
          Query.limit(500),
        ],
      );
      currentPresence = rows.rows.map((row) {
        final payload = <String, dynamic>{
          'user_id': (row.data['user_id'] ?? row.$id).toString(),
          'status': (row.data['status'] ?? 'offline').toString(),
          'last_seen_at': row.data['last_seen_at'],
          'compound_id': row.data['compound_id']?.toString(),
        };
        return SinglePresenceState([PresencePayloadEntry(payload)]);
      }).toList();
      emit(PresenceUpdated(currentPresence));
    } catch (_) {
      // Presence is non-critical; keep UX graceful on transient failures.
    }
  }

  Future<void> initializePresence({
    required String userId,
    required String compoundId,
  }) async {
    _currentUserId = userId.trim();
    _currentCompoundId = compoundId.trim();

    await _presenceSubscription?.close();
    _presenceSubscription = appwriteRealtime.subscribe([
      'databases.$appwriteDatabaseId.tables.$_kPresenceTableId.rows',
    ]);
    _presenceSubscription!.stream.listen((_) {
      _refreshPresenceRows();
    });

    await updatePresenceStatus('online');
    await _refreshPresenceRows();
  }

  Future<void> updatePresenceStatus(String status) async {
    final userId = _currentUserId;
    final compoundId = _currentCompoundId;
    if (userId == null ||
        userId.isEmpty ||
        compoundId == null ||
        compoundId.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await appwriteTables.updateRow(
        databaseId: appwriteDatabaseId,
        tableId: _kPresenceTableId,
        rowId: userId,
        data: {
          'user_id': userId,
          'compound_id': compoundId,
          'status': status,
          'last_seen_at': now,
        },
      );
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        await appwriteTables.createRow(
          databaseId: appwriteDatabaseId,
          tableId: _kPresenceTableId,
          rowId: userId,
          data: {
            'user_id': userId,
            'compound_id': compoundId,
            'status': status,
            'last_seen_at': now,
            'version': 0,
          },
        );
      }
    }
    await _refreshPresenceRows();
  }

  Future<void> untrackPresence() async {
    await updatePresenceStatus('offline');
  }

  void disconnectPresence() {
    currentPresence = [];
    emit(PresenceUpdated(currentPresence));
    _presenceSubscription?.close();
    _presenceSubscription = null;
    _currentUserId = null;
    _currentCompoundId = null;
  }

  @override
  Future<void> close() {
    disconnectPresence();
    return super.close();
  }
}
