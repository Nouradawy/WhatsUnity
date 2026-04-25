import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/media/media_services.dart';
import '../../../../core/media/media_upload_metadata.dart';
import '../../domain/entities/brainstorm.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/social_repository.dart';
import '../datasources/social_remote_data_source.dart';
import '../models/brainstorm_model.dart';
import '../models/post_model.dart';

class SocialRepositoryImpl implements SocialRepository {
  SocialRepositoryImpl({required this.remoteDataSource});

  final SocialRemoteDataSource remoteDataSource;

  Future<String?> _uploadImageToR2(XFile xfile) async {
    final meta = await mediaUploadService.uploadFromLocalPath(
      localFilePath: xfile.path,
      filenameOverride: xfile.name,
      mimeType: lookupMimeType(xfile.path),
    );
    return meta[MediaUploadMetadataKeys.url] as String? ??
        meta[MediaUploadMetadataKeys.playbackUrl] as String?;
  }

  @override
  Future<List<Post>> getPosts(String compoundId) async {
    final results = await remoteDataSource.remote_getPosts(compoundId);
    return results.map(PostModel.fromAppwriteJson).toList();
  }

  @override
  Future<void> deleteMyPost({
    required String authorId,
    required String postId,
  }) {
    return remoteDataSource.remote_softDeletePostByAuthorAndId(
      authorId: authorId,
      postId: postId,
    );
  }

  @override
  Future<void> createPost({
    required String postHead,
    required bool getCalls,
    required String compoundId,
    required String authorId,
    List<XFile>? files,
  }) async {
    List<Map<String, dynamic>> imageSources = [];

    if (files != null) {
      for (final xfile in files) {
        final bytes = await xfile.readAsBytes();
        // Since we are in repository, we might not have access to UI-related decodeImageFromList easily without context or flutter/foundation
        // But the original code used it. We'll use it here as well.
        final image = await decodeImageFromList(bytes);
        final fileName = xfile.name;

        final publicUrl = await _uploadImageToR2(xfile);

        if (publicUrl != null && publicUrl.isNotEmpty) {
          imageSources.add({
            'uri': publicUrl,
            'name': fileName,
            'size': bytes.length.toString(),
            'height': image.height.toString(),
            'width': image.width.toString(),
          });
        }
      }
    }

    await remoteDataSource.remote_createPost(
      postHead: postHead,
      getCalls: getCalls,
      compoundId: compoundId,
      authorId: authorId,
      imageSources: imageSources,
    );
  }

  @override
  Future<void> addComment({
    required String compoundId,
    required String postId,
    required String commentText,
    required String authorId,
    required List<Map<String, dynamic>> currentComments,
  }) async {
    final List<Map<String, dynamic>> newComments = List.from(currentComments);
    newComments.add({
      'author_id': authorId,
      'comment': commentText,
    });

    await remoteDataSource.remote_updatePostComments(
      postId: postId,
      comments: newComments,
    );
  }

  @override
  Future<List<BrainStorm>> getBrainStorms(
      String channelId, String compoundId) async {
    final results =
        await remoteDataSource.remote_getBrainStorms(channelId, compoundId);
    return results.map(BrainStormModel.fromAppwriteJson).toList();
  }

  @override
  Future<void> createBrainStorm({
    required String title,
    required List<XFile>? images,
    required dynamic options,
    required String channelId,
    required String compoundId,
    required String authorId,
  }) async {
    List<Map<String, dynamic>> imageSources = [];

    if (images != null) {
      for (final xfile in images) {
        final bytes = await xfile.readAsBytes();
        final image = await decodeImageFromList(bytes);
        final fileName = xfile.name;

        final publicUrl = await _uploadImageToR2(xfile);

        if (publicUrl != null && publicUrl.isNotEmpty) {
          imageSources.add({
            'uri': publicUrl,
            'name': fileName,
            'size': bytes.length.toString(),
            'height': image.height.toString(),
            'width': image.width.toString(),
          });
        }
      }
    }

    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();

    await remoteDataSource.remote_createBrainStorm(
      id: id,
      title: title,
      authorId: authorId,
      createdAt: now,
      channelId: channelId,
      compoundId: compoundId,
      imageSources: imageSources,
      options: options,
    );
  }

  @override
  Future<void> voteBrainStorm({
    required String pollId,
    required String optionId,
    required String userId,
    required List<Map<String, dynamic>> currentOptions,
    required Map<String, dynamic>? currentVotes,
  }) async {
    final Map<String, Map<String, bool>> votes = {};
    if (currentVotes != null) {
      currentVotes.forEach((k, v) {
        final Map<String, bool> inner = {};
        if (v is Map) {
          v.forEach((vk, vv) => inner[vk.toString()] = vv == true);
        }
        votes[k.toString()] = inner;
      });
    }

    String? prevOptionId;
    votes.forEach((opId, voters) {
      if (voters.containsKey(userId)) prevOptionId = opId;
    });

    final bool isUnvote = prevOptionId == optionId;

    if (isUnvote) {
      votes[optionId]?.remove(userId);
      if (votes[optionId]?.isEmpty ?? true) votes.remove(optionId);
    } else {
      if (prevOptionId != null) {
        votes[prevOptionId]?.remove(userId);
        if (votes[prevOptionId]?.isEmpty ?? true) votes.remove(prevOptionId);
      }
      votes.putIfAbsent(optionId, () => <String, bool>{});
      votes[optionId]![userId] = true;
    }

    final List<Map<String, dynamic>> options = currentOptions.map((e) => Map<String, dynamic>.from(e)).toList();
    for (final o in options) {
      final idStr = o['id'].toString();
      o['votes'] = votes[idStr]?.length ?? 0;
    }

    await remoteDataSource.remote_updateBrainStormVote(
      pollId: pollId,
      votes: votes,
      options: options,
    );
  }

  @override
  Future<void> addBrainStormComment({
    required String channelId,
    required String compoundId,
    required String pollId,
    required String commentText,
    required String authorId,
    required List<Map<String, dynamic>> currentComments,
  }) async {
    final List<Map<String, dynamic>> newComments = List.from(currentComments);
    newComments.add({
      'author_id': authorId,
      'comment': commentText,
    });

    await remoteDataSource.remote_updateBrainStormComments(
      pollId: pollId,
      comments: newComments,
    );
  }
}
