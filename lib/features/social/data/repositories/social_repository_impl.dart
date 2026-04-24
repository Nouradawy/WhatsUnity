import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/GoogleDriveService.dart';
import '../../domain/entities/brainstorm.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/social_repository.dart';
import '../datasources/social_remote_data_source.dart';
import '../models/brainstorm_model.dart';
import '../models/post_model.dart';

class SocialRepositoryImpl implements SocialRepository {
  final SocialRemoteDataSource remoteDataSource;
  final GoogleDriveService driveService;

  SocialRepositoryImpl({
    required this.remoteDataSource,
    required this.driveService,
  });

  @override
  Future<List<Post>> getPosts(String compoundId) async {
    final results = await remoteDataSource.getPosts(compoundId);
    return results.map((json) => PostModel.fromJson(json)).toList();
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
        final file = File(xfile.path);
        final fileName = xfile.name;

        final driveLink = await driveService.uploadFile(
          file,
          fileName,
          'image',
        );

        if (driveLink != null) {
          imageSources.add({
            'uri': driveLink,
            'name': fileName,
            'size': bytes.length.toString(),
            'height': image.height.toString(),
            'width': image.width.toString(),
          });
        }
      }
    }

    await remoteDataSource.createPost(
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

    await remoteDataSource.updatePostComments(
      postId: postId,
      comments: newComments,
    );
  }

  @override
  Future<List<BrainStorm>> getBrainStorms(
      String channelId, String compoundId) async {
    final results = await remoteDataSource.getBrainStorms(channelId, compoundId);
    return results.map((json) => BrainStormModel.fromJson(json)).toList();
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
        final file = File(xfile.path);
        final fileName = xfile.name;

        final driveLink = await driveService.uploadFile(
          file,
          fileName,
          'image',
        );

        if (driveLink != null) {
          imageSources.add({
            'uri': driveLink,
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

    await remoteDataSource.createBrainStorm(
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

    await remoteDataSource.updateBrainStormVote(
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

    await remoteDataSource.updateBrainStormComments(
      pollId: pollId,
      comments: newComments,
    );
  }
}
