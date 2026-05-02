/// [AuthLocalDataSource]
///
/// This file handles local persistence for authentication and member data.
/// - Stores session snapshots in the 'sessions' table for offline-first restoration.
/// - Caches compound member profiles in the 'members' table to reduce data consumption.
/// - Manages delta-sync timestamps for members via 'member_sync_metadata'.
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../../core/services/database_helper.dart';
import '../../../chat/data/models/chat_member_model.dart';

/// Contract for local session storage in SQLite.
/// Uses the 'sessions' table to persist user data for offline restoration.
abstract class AuthLocalDataSource {
  /// Persists a session snapshot for the given [userId].
  Future<void> localSaveSession({
    required String userId,
    required String? email,
    required Map<String, dynamic>? userMetadata,
    required String? selectedCompoundId,
    required Map<String, dynamic> myCompounds,
    required String? roleId,
  });

  /// Fetches the last saved session for a given [userId].
  Future<Map<String, dynamic>?> localFetchSession(String userId);

  /// Deletes the local session for a given [userId].
  Future<void> localDeleteSession(String userId);

  // ── Member Caching ───────────────────────────────────────────────────────

  /// Upserts a list of members into the local 'members' table.
  Future<void> localUpsertMembers(String compoundId, List<ChatMember> members);

  /// Fetches cached members for a given [compoundId].
  Future<List<ChatMember>> localFetchMembers(String compoundId);

  /// Gets the last sync timestamp for a given [compoundId].
  Future<String?> localGetMembersLastSync(String compoundId);

  /// Updates the last sync timestamp for a given [compoundId].
  Future<void> localUpdateMembersLastSync(String compoundId, String timestamp);
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl({required DatabaseHelper databaseHelper})
      : _dbHelper = databaseHelper;

  final DatabaseHelper _dbHelper;

  @override
  Future<void> localSaveSession({
    required String userId,
    required String? email,
    required Map<String, dynamic>? userMetadata,
    required String? selectedCompoundId,
    required Map<String, dynamic> myCompounds,
    required String? roleId,
  }) async {
    final db = await _dbHelper.database;
    await db.insert(
      'sessions',
      {
        'user_id': userId,
        'email': email,
        'user_metadata_json': userMetadata != null ? jsonEncode(userMetadata) : null,
        'selected_compound_id': selectedCompoundId,
        'my_compounds_json': jsonEncode(myCompounds),
        'role_id': roleId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Map<String, dynamic>?> localFetchSession(String userId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'sessions',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first;
  }

  @override
  Future<void> localDeleteSession(String userId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'sessions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  @override
  Future<void> localUpsertMembers(String compoundId, List<ChatMember> members) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final m in members) {
      batch.insert(
        'members',
        {
          'id': m.id,
          'compound_id': compoundId,
          'display_name': m.displayName,
          'full_name': m.fullName,
          'avatar_url': m.avatarUrl,
          'building_num': m.building,
          'apartment_num': m.apartment,
          'phone_number': m.phoneNumber,
          'owner_type': m.ownerType?.name,
          'user_state': m.userState?.name,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<ChatMember>> localFetchMembers(String compoundId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'members',
      where: 'compound_id = ?',
      whereArgs: [compoundId],
    );

    return results.map((r) => ChatMember.fromJson({
      'id': r['id'],
      'display_name': r['display_name'],
      'full_name': r['full_name'],
      'avatar_url': r['avatar_url'],
      'building_num': r['building_num'],
      'apartment_num': r['apartment_num'],
      'phone_number': r['phone_number'],
      'owner_type': r['owner_type'],
      'userState': r['user_state'],
    })).toList();
  }

  @override
  Future<String?> localGetMembersLastSync(String compoundId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'member_sync_metadata',
      where: 'compound_id = ?',
      whereArgs: [compoundId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['last_sync_timestamp'] as String?;
  }

  @override
  Future<void> localUpdateMembersLastSync(String compoundId, String timestamp) async {
    final db = await _dbHelper.database;
    await db.insert(
      'member_sync_metadata',
      {
        'compound_id': compoundId,
        'last_sync_timestamp': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
