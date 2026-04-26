import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as aw_models;
import 'package:WhatsUnity/core/config/appwrite.dart';

// APPWRITE_SCHEMA.md §2.14 / §2.15 — provision collection ids (tools/provision_spec.json)
const String _collectionPosts = 'posts';
const String _collectionBrainstorms = 'brainstorms';

Map<String, dynamic> _mergedDocumentJson(aw_models.Row d) => {
      r'$id': d.$id,
      r'$createdAt': d.$createdAt,
      r'$updatedAt': d.$updatedAt,
      ...d.data,
    };

String _jsonAttr(dynamic value) => jsonEncode(value);

/// Appwrite social collections. All methods use the `remote_` prefix (local SQLite peers use `local_`).
abstract class SocialRemoteDataSource {
  /// Lists `posts` for [compoundId] (`compound_id` equals the compound document `\$id`).
  Future<List<Map<String, dynamic>>> remote_getPosts(String compoundId);

  Future<void> remote_createPost({
    required String postHead,
    required bool getCalls,
    required String compoundId,
    required String authorId,
    required List<Map<String, dynamic>> imageSources,
  });

  Future<void> remote_updatePostComments({
    required String postId,
    required List<Map<String, dynamic>> comments,
  });

  /// Soft-delete: sets `deleted_at` when [postId] belongs to [authorId].
  Future<void> remote_softDeletePostByAuthorAndId({
    required String authorId,
    required String postId,
  });

  Future<List<Map<String, dynamic>>> remote_getBrainStorms(
    String channelId,
    String compoundId,
  );

  /// [id] becomes the brainstorm document `\$id` via `ID.custom`.
  Future<void> remote_createBrainStorm({
    required String id,
    required String title,
    required String authorId,
    required String createdAt,
    required String channelId,
    required String compoundId,
    required List<Map<String, dynamic>> imageSources,
    required dynamic options,
  });

  Future<void> remote_updateBrainStormVote({
    required String pollId,
    required Map<String, Map<String, bool>> votes,
    required List<Map<String, dynamic>> options,
  });

  Future<void> remote_updateBrainStormComments({
    required String pollId,
    required List<Map<String, dynamic>> comments,
  });
}

class SocialRemoteDataSourceImpl implements SocialRemoteDataSource {
  SocialRemoteDataSourceImpl({required TablesDB databases})
      : _databases = databases;

  final TablesDB _databases;

  @override
  Future<List<Map<String, dynamic>>> remote_getPosts(String compoundId) async {
    final list = await _databases.listRows(
      databaseId: appwriteDatabaseId,
      tableId: _collectionPosts,
      queries: [
        Query.equal('compound_id', compoundId),
        Query.isNull('deleted_at'),
        Query.orderDesc(r'$createdAt'),
        Query.limit(2000),
      ],
    );
    return list.rows.map(_mergedDocumentJson).toList();
  }

  @override
  Future<void> remote_createPost({
    required String postHead,
    required bool getCalls,
    required String compoundId,
    required String authorId,
    required List<Map<String, dynamic>> imageSources,
  }) async {
    await _databases.createRow(
      databaseId: appwriteDatabaseId,
      tableId: _collectionPosts,
      rowId: ID.unique(),
      data: {
        'compound_id': compoundId,
        'author_id': authorId,
        'post_head': postHead,
        'getCalls': getCalls,
        'source_url': _jsonAttr(imageSources),
        'Comments': _jsonAttr(<Map<String, dynamic>>[]),
        'version': 0,
      },
    );
  }

  @override
  Future<void> remote_updatePostComments({
    required String postId,
    required List<Map<String, dynamic>> comments,
  }) async {
    await _databases.updateRow(
      databaseId: appwriteDatabaseId,
      tableId: _collectionPosts,
      rowId: postId,
      data: {
        'Comments': _jsonAttr(comments),
      },
    );
  }

  @override
  Future<void> remote_softDeletePostByAuthorAndId({
    required String authorId,
    required String postId,
  }) async {
    final doc = await _databases.getRow(
      databaseId: appwriteDatabaseId,
      tableId: _collectionPosts,
      rowId: postId,
    );
    if (doc.data['author_id']?.toString() != authorId) return;
    final v = int.tryParse(doc.data['version']?.toString() ?? '') ?? 0;
    await _databases.updateRow(
      databaseId: appwriteDatabaseId,
      tableId: _collectionPosts,
      rowId: postId,
      data: {
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'version': v + 1,
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> remote_getBrainStorms(
    String channelId,
    String compoundId,
  ) async {
    final list = await _databases.listRows(
      databaseId: appwriteDatabaseId,
      tableId: _collectionBrainstorms,
      queries: [
        Query.equal('channel_id', channelId),
        Query.equal('compound_id', compoundId),
        Query.isNull('deleted_at'),
        Query.orderDesc(r'$createdAt'),
        Query.limit(2000),
      ],
    );
    return list.rows.map(_mergedDocumentJson).toList();
  }

  @override
  Future<void> remote_createBrainStorm({
    required String id,
    required String title,
    required String authorId,
    required String createdAt,
    required String channelId,
    required String compoundId,
    required List<Map<String, dynamic>> imageSources,
    required dynamic options,
  }) async {
    await _databases.createRow(
      databaseId: appwriteDatabaseId,
      tableId: _collectionBrainstorms,
      rowId: ID.custom(id),
      data: {
        'channel_id': channelId,
        'compound_id': compoundId,
        'author_id': authorId,
        'title': title,
        'imageSources': _jsonAttr(imageSources),
        'options': _jsonAttr(options),
        'votes': _jsonAttr(<String, Map<String, bool>>{}),
        'comments': _jsonAttr(<Map<String, dynamic>>[]),
        'version': 0,
      },
    );
  }

  @override
  Future<void> remote_updateBrainStormVote({
    required String pollId,
    required Map<String, Map<String, bool>> votes,
    required List<Map<String, dynamic>> options,
  }) async {
    await _databases.updateRow(
      databaseId: appwriteDatabaseId,
      tableId: _collectionBrainstorms,
      rowId: pollId,
      data: {
        'votes': _jsonAttr(votes),
        'options': _jsonAttr(options),
      },
    );
  }

  @override
  Future<void> remote_updateBrainStormComments({
    required String pollId,
    required List<Map<String, dynamic>> comments,
  }) async {
    await _databases.updateRow(
      databaseId: appwriteDatabaseId,
      tableId: _collectionBrainstorms,
      rowId: pollId,
      data: {
        'comments': _jsonAttr(comments),
      },
    );
  }
}
