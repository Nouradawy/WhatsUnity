import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:WhatsUnity/core/config/appwrite.dart';

// APPWRITE_SCHEMA.md §2.14 / §2.15 — provision collection ids (tools/provision_spec.json)
const String _collectionPosts = 'posts';
const String _collectionBrainstorms = 'brainstorms';

abstract class SocialRemoteDataSource {
  Future<List<Map<String, dynamic>>> getPosts(String compoundId);
  Future<void> createPost({
    required String postHead,
    required bool getCalls,
    required String compoundId,
    required String authorId,
    required List<Map<String, dynamic>> imageSources,
  });
  Future<void> updatePostComments({
    required String postId,
    required List<Map<String, dynamic>> comments,
  });

  Future<List<Map<String, dynamic>>> getBrainStorms(
    String channelId,
    String compoundId,
  );
  Future<void> createBrainStorm({
    required String id,
    required String title,
    required String authorId,
    required String createdAt,
    required String channelId,
    required String compoundId,
    required List<Map<String, dynamic>> imageSources,
    required dynamic options,
  });
  Future<void> updateBrainStormVote({
    required String pollId,
    required Map<String, Map<String, bool>> votes,
    required List<Map<String, dynamic>> options,
  });
  Future<void> updateBrainStormComments({
    required String pollId,
    required List<Map<String, dynamic>> comments,
  });
}

List<Map<String, dynamic>> _decodeMapList(dynamic value) {
  if (value == null) return [];
  if (value is String) {
    if (value.isEmpty) return [];
    final decoded = jsonDecode(value);
    if (decoded is! List) return [];
    return decoded
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
  if (value is List) {
    return value
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
  return [];
}

Map<String, dynamic>? _decodeObjectMap(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    if (value.isEmpty) return null;
    final decoded = jsonDecode(value);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

String _jsonAttr(dynamic value) => jsonEncode(value);

Map<String, dynamic> _postDocumentToRow(
  String id,
  String createdAt,
  Map<String, dynamic> data,
) {
  return {
    'id': id,
    'compound_id': data['compound_id']?.toString() ?? '',
    'author_id': data['author_id']?.toString() ?? '',
    'post_head': data['post_head'] as String? ?? '',
    'source_url': _decodeMapList(data['source_url']),
    'getCalls': data['getCalls'] as bool? ?? false,
    'Comments': _decodeMapList(data['Comments']),
    'created_at': createdAt,
  };
}

Map<String, dynamic> _brainstormDocumentToRow(
  String id,
  String createdAt,
  Map<String, dynamic> data,
) {
  final votes = _decodeObjectMap(data['votes']);
  return {
    'id': id,
    'author_id': data['author_id']?.toString() ?? '',
    'created_at': createdAt,
    'compound_id': data['compound_id']?.toString() ?? '',
    'channel_id': data['channel_id']?.toString() ?? '',
    'title': data['title'] as String? ?? '',
    'imageSources': _decodeMapList(data['imageSources']),
    'options': _decodeMapList(data['options']),
    'comments': _decodeMapList(data['comments']),
    'votes': votes,
  };
}

class SocialRemoteDataSourceImpl implements SocialRemoteDataSource {
  SocialRemoteDataSourceImpl({required Databases databases})
      : _databases = databases;

  final Databases _databases;

  @override
  Future<List<Map<String, dynamic>>> getPosts(String compoundId) async {
    final list = await _databases.listDocuments(
      databaseId: appwriteDatabaseId,
      collectionId: _collectionPosts,
      queries: [
        Query.equal('compound_id', compoundId),
        Query.isNull('deleted_at'),
        Query.orderDesc(r'$createdAt'),
        Query.limit(2000),
      ],
    );
    return list.documents
        .map(
          (d) => _postDocumentToRow(
            d.$id,
            d.$createdAt,
            d.data,
          ),
        )
        .toList();
  }

  @override
  Future<void> createPost({
    required String postHead,
    required bool getCalls,
    required String compoundId,
    required String authorId,
    required List<Map<String, dynamic>> imageSources,
  }) async {
    await _databases.createDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _collectionPosts,
      documentId: ID.unique(),
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
  Future<void> updatePostComments({
    required String postId,
    required List<Map<String, dynamic>> comments,
  }) async {
    await _databases.updateDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _collectionPosts,
      documentId: postId,
      data: {
        'Comments': _jsonAttr(comments),
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getBrainStorms(
    String channelId,
    String compoundId,
  ) async {
    final list = await _databases.listDocuments(
      databaseId: appwriteDatabaseId,
      collectionId: _collectionBrainstorms,
      queries: [
        Query.equal('channel_id', channelId),
        Query.equal('compound_id', compoundId),
        Query.isNull('deleted_at'),
        Query.orderDesc(r'$createdAt'),
        Query.limit(2000),
      ],
    );
    return list.documents
        .map(
          (d) => _brainstormDocumentToRow(
            d.$id,
            d.$createdAt,
            d.data,
          ),
        )
        .toList();
  }

  @override
  Future<void> createBrainStorm({
    required String id,
    required String title,
    required String authorId,
    required String createdAt,
    required String channelId,
    required String compoundId,
    required List<Map<String, dynamic>> imageSources,
    required dynamic options,
  }) async {
    await _databases.createDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _collectionBrainstorms,
      // Schema: $id = client UUID (APPWRITE_SCHEMA.md §2.15)
      documentId: ID.custom(id),
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
  Future<void> updateBrainStormVote({
    required String pollId,
    required Map<String, Map<String, bool>> votes,
    required List<Map<String, dynamic>> options,
  }) async {
    await _databases.updateDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _collectionBrainstorms,
      documentId: pollId,
      data: {
        'votes': _jsonAttr(votes),
        'options': _jsonAttr(options),
      },
    );
  }

  @override
  Future<void> updateBrainStormComments({
    required String pollId,
    required List<Map<String, dynamic>> comments,
  }) async {
    await _databases.updateDocument(
      databaseId: appwriteDatabaseId,
      collectionId: _collectionBrainstorms,
      documentId: pollId,
      data: {
        'comments': _jsonAttr(comments),
      },
    );
  }
}
