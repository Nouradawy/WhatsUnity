import 'package:image_picker/image_picker.dart';
import '../entities/post.dart';
import '../entities/brainstorm.dart';

abstract class SocialRepository {
  Future<List<Post>> getPosts(String compoundId);
  Future<void> createPost({
    required String postHead,
    required bool getCalls,
    required String compoundId,
    required String authorId,
    List<XFile>? files,
  });
  /// [compoundId] is kept for call-site consistency; the remote call only updates post comments.
  Future<void> addComment({
    required String compoundId,
    required String postId,
    required String commentText,
    required String authorId,
    required List<Map<String, dynamic>> currentComments,
  });

  Future<List<BrainStorm>> getBrainStorms(
      String channelId, String compoundId);
  Future<void> createBrainStorm({
    required String title,
    required List<XFile>? images,
    required dynamic options,
    required String channelId,
    required String compoundId,
    required String authorId,
  });
  Future<void> voteBrainStorm({
    required String pollId,
    required String optionId,
    required String userId,
    required List<Map<String, dynamic>> currentOptions,
    required Map<String, dynamic>? currentVotes,
  });
  Future<void> addBrainStormComment({
    required String channelId,
    required String compoundId,
    required String pollId,
    required String commentText,
    required String authorId,
    required List<Map<String, dynamic>> currentComments,
  });
}
