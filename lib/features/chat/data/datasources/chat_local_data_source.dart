import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/services/database_helper.dart';
import '../utils/chat_message_map_codec.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

/// Local persistence for chat messages (offline-first, pagination).
abstract class ChatLocalDataSource {
  Future<void> insertMessage(Map<String, dynamic> row);

  Future<void> insertMessages(List<Map<String, dynamic>> rows);

  /// Newest-first page matching remote pagination windows (offset = page * limit).
  Future<List<Map<String, dynamic>>> getMessagesByChannelWithPagination({
    required String channelId,
    required int limit,
    required int offset,
  });

  Future<void> clearChannelMessages(String channelId);

  /// Upsert messages built from UI [types.Message] (e.g. on dispose).
  Future<void> insertMessagesFromTypes(String channelId, List<types.Message> messages);

  Future<void> deleteMessageById(String messageId);

  /// All messages for a channel, oldest first (for UI hydration).
  Future<List<Map<String, dynamic>>> getAllMessagesForChannelAscending(String channelId);

  /// Full `messages` table row (for LWW + sync worker), or null.
  Future<Map<String, dynamic>?> getRawMessageRow(String messageId);

  /// After a successful outbound sync, align local metadata with the server.
  Future<void> markMessageSyncClean({
    required String messageId,
    required int entityVersion,
    String? remoteUpdatedAt,
  });
}

class ChatLocalDataSourceImpl implements ChatLocalDataSource {
  ChatLocalDataSourceImpl(this._dbHelper);

  final DatabaseHelper _dbHelper;

  static const _table = 'messages';

  Future<Database> get _db => _dbHelper.database;

  @override
  Future<void> insertMessage(Map<String, dynamic> row) async {
    try {
      final db = await _db;
      final record = _normalizeRow(row);
      await db.insert(
        _table,
        record,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on DatabaseException catch (e, st) {
      debugPrint('ChatLocalDataSource.insertMessage: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> insertMessages(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      final db = await _db;
      final batch = db.batch();
      for (final row in rows) {
        batch.insert(
          _table,
          _normalizeRow(row),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } on DatabaseException catch (e, st) {
      debugPrint('ChatLocalDataSource.insertMessages: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMessagesByChannelWithPagination({
    required String channelId,
    required int limit,
    required int offset,
  }) async {
    try {
      final db = await _db;
      final rows = await db.query(
        _table,
        columns: ['payload_json'],
        where: 'channel_id = ?',
        whereArgs: [channelId],
        orderBy: 'created_at_ms DESC',
        limit: limit,
        offset: offset,
      );
      final out = <Map<String, dynamic>>[];
      for (final r in rows) {
        final raw = r['payload_json'] as String?;
        if (raw == null || raw.isEmpty) continue;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            out.add(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      }
      // Remote/UI lists are chronological ascending; this page was fetched DESC.
      return out.reversed.toList();
    } on DatabaseException catch (e, st) {
      debugPrint('ChatLocalDataSource.getMessagesByChannelWithPagination: $e\n$st');
      return [];
    }
  }

  @override
  Future<void> clearChannelMessages(String channelId) async {
    try {
      final db = await _db;
      await db.delete(
        _table,
        where: 'channel_id = ?',
        whereArgs: [channelId],
      );
    } on DatabaseException catch (e, st) {
      debugPrint('ChatLocalDataSource.clearChannelMessages: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAllMessagesForChannelAscending(String channelId) async {
    try {
      final db = await _db;
      final rows = await db.query(
        _table,
        columns: ['payload_json'],
        where: 'channel_id = ?',
        whereArgs: [channelId],
        orderBy: 'created_at_ms ASC',
      );
      final out = <Map<String, dynamic>>[];
      for (final r in rows) {
        final raw = r['payload_json'] as String?;
        if (raw == null || raw.isEmpty) continue;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) out.add(Map<String, dynamic>.from(decoded));
        } catch (_) {}
      }
      return out;
    } on DatabaseException catch (e, st) {
      debugPrint('ChatLocalDataSource.getAllMessagesForChannelAscending: $e\n$st');
      return [];
    }
  }

  @override
  Future<void> deleteMessageById(String messageId) async {
    if (messageId.isEmpty) return;
    try {
      final db = await _db;
      await db.delete(_table, where: 'id = ?', whereArgs: [messageId]);
    } on DatabaseException catch (e, st) {
      debugPrint('ChatLocalDataSource.deleteMessageById: $e\n$st');
    }
  }

  @override
  Future<void> insertMessagesFromTypes(String channelId, List<types.Message> messages) async {
    if (messages.isEmpty) return;
    final rows = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final m in messages) {
      if (!seen.add(m.id)) continue;
      final map = ChatMessageMapCodec.messageToMap(m);
      map['channel_id'] = channelId;
      rows.add(map);
    }
    await insertMessages(rows);
  }

  Map<String, dynamic> _normalizeRow(Map<String, dynamic> raw) {
    final id = raw['id']?.toString() ?? '';
    final channelId = _channelIdString(raw['channel_id']);
    final authorId = raw['author_id']?.toString() ?? '';
    final ms = ChatMessageMapCodec.extractCreatedAtMs(Map<String, dynamic>.from(raw));
    final meta = raw['metadata'];
    final metaStr = meta is String ? meta : jsonEncode(meta ?? <String, dynamic>{});
    final createdAt = raw['created_at']?.toString() ?? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
    final payload = Map<String, dynamic>.from(raw);
    payload['channel_id'] = channelId;
    payload['author_id'] = authorId;
    payload['metadata'] = meta is Map ? meta : _decodeMeta(metaStr);
    final typeStr = (payload['metadata'] is Map ? (payload['metadata']['type']) : null)?.toString() ??
        raw['type']?.toString() ??
        'text';

    final entityVersion = int.tryParse(
          raw['entity_version']?.toString() ??
              raw['version']?.toString() ??
              '',
        ) ??
        0;
    final syncStateStr = raw['sync_state']?.toString() ??
        (((raw['is_synced'] is int && raw['is_synced'] == 0) ||
                raw['is_synced'] == false)
            ? 'dirty'
            : 'clean');

    return {
      'id': id,
      'channel_id': channelId,
      'author_id': authorId,
      'content': raw['text']?.toString(),
      'uri': raw['uri']?.toString(),
      'type': typeStr,
      'created_at': createdAt,
      'created_at_ms': ms,
      'metadata': metaStr,
      'sent_at': raw['sent_at']?.toString(),
      'deleted_at': raw['deleted_at']?.toString(),
      'is_synced': syncStateStr == 'clean' ? 1 : 0,
      'entity_version': entityVersion,
      'sync_state': syncStateStr,
      'local_updated_at': raw['local_updated_at']?.toString(),
      'remote_updated_at': raw['remote_updated_at']?.toString(),
      'last_sync_error': raw['last_sync_error']?.toString(),
      'payload_json': jsonEncode(payload),
    };
  }

  dynamic _decodeMeta(String metaStr) {
    try {
      final d = jsonDecode(metaStr);
      if (d is Map) return d;
    } catch (_) {}
    return <String, dynamic>{};
  }

  String _channelIdString(dynamic v) {
    if (v == null) return '';
    return v.toString();
  }

  @override
  Future<Map<String, dynamic>?> getRawMessageRow(String messageId) async {
    if (messageId.isEmpty) return null;
    try {
      final db = await _db;
      final rows = await db.query(
        _table,
        where: 'id = ?',
        whereArgs: [messageId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    } on DatabaseException catch (e, st) {
      debugPrint('ChatLocalDataSource.getRawMessageRow: $e\n$st');
      return null;
    }
  }

  @override
  Future<void> markMessageSyncClean({
    required String messageId,
    required int entityVersion,
    String? remoteUpdatedAt,
  }) async {
    if (messageId.isEmpty) return;
    try {
      final db = await _db;
      await db.update(
        _table,
        {
          'entity_version': entityVersion,
          'sync_state': 'clean',
          'last_sync_error': null,
          if (remoteUpdatedAt != null) 'remote_updated_at': remoteUpdatedAt,
          'is_synced': 1,
        },
        where: 'id = ?',
        whereArgs: [messageId],
      );
    } on DatabaseException catch (e, st) {
      debugPrint('ChatLocalDataSource.markMessageSyncClean: $e\n$st');
    }
  }
}
