import 'dart:convert';

import 'package:WhatsUnity/core/sync/sync_metadata.dart';
import 'package:WhatsUnity/core/sync/sync_state.dart';
import '../../domain/entities/brainstorm.dart';

/// Appwrite `brainstorms` row (APPWRITE_SCHEMA.md §2.15).
///
/// [id] is the document `\$id` (client-chosen UUID on create).
class BrainStormModel extends BrainStorm implements SyncMetadata {
  @override
  final int version;

  @override
  final SyncState syncState;

  @override
  final DateTime? localUpdatedAt;

  @override
  final DateTime? remoteUpdatedAt;

  @override
  final DateTime? deletedAt;

  @override
  final String? lastSyncError;

  BrainStormModel({
    required super.id,
    required super.authorId,
    required super.createdAt,
    required super.compoundId,
    required super.channelId,
    required super.title,
    required super.image,
    required super.options,
    required super.comments,
    super.votes,
    this.version = 0,
    this.syncState = SyncState.clean,
    this.localUpdatedAt,
    this.remoteUpdatedAt,
    this.deletedAt,
    this.lastSyncError,
  });

  static List<Map<String, dynamic>> _decodeJsonMapList(dynamic value) {
    if (value == null) return [];
    if (value is String) {
      if (value.isEmpty) return [];
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      } catch (_) {}
      return [];
    }
    if (value is List) {
      return value
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  static Map<String, dynamic>? _decodeVotes(dynamic value) {
    if (value == null) return null;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      if (value.isEmpty) return null;
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s)?.toLocal();
  }

  /// Parses merged Appwrite document JSON using schema keys: `channel_id`, `compound_id`,
  /// `author_id`, `title`, `imageSources`, `options`, `votes`, `comments`, `version`, `deleted_at`.
  factory BrainStormModel.fromAppwriteJson(Map<String, dynamic> json) {
    final id = json[r'$id']?.toString() ?? json['id']?.toString() ?? '';
    final authorId = json['author_id']?.toString() ?? '';
    final createdAt =
        _parseDate(json[r'$createdAt']) ??
        _parseDate(json['created_at']) ??
        DateTime.now();
    final compoundId = json['compound_id']?.toString() ?? '';
    final channelId = json['channel_id']?.toString() ?? '';
    final title = json['title']?.toString() ?? '';
    final image = _decodeJsonMapList(json['imageSources']);
    final options = _decodeJsonMapList(json['options']);
    final comments = _decodeJsonMapList(json['comments']);
    final votes = _decodeVotes(json['votes']);
    final ver = int.tryParse(json['version']?.toString() ?? '') ?? 0;
    final deletedAt = _parseDate(json['deleted_at']);

    return BrainStormModel(
      id: id,
      authorId: authorId,
      createdAt: createdAt,
      compoundId: compoundId,
      channelId: channelId,
      title: title,
      image: image,
      options: options,
      comments: comments,
      votes: votes,
      version: ver,
      syncState: SyncState.clean,
      remoteUpdatedAt: _parseDate(json[r'$updatedAt']),
      deletedAt: deletedAt,
    );
  }

  Map<String, dynamic> toAppwriteJson() {
    return {
      'channel_id': channelId,
      'compound_id': compoundId,
      'author_id': authorId,
      'title': title,
      'imageSources': jsonEncode(image),
      'options': jsonEncode(options),
      'votes': jsonEncode(votes ?? <String, Map<String, bool>>{}),
      'comments': jsonEncode(comments),
      'version': version,
      if (deletedAt != null)
        'deleted_at': deletedAt!.toUtc().toIso8601String(),
    };
  }

  factory BrainStormModel.fromJson(Map<String, dynamic> json) =>
      BrainStormModel.fromAppwriteJson(json);

  Map<String, dynamic> toJson() {
    return {
      r'$id': id,
      'id': id,
      ...toAppwriteJson(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
