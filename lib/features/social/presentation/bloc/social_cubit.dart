import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'social_state.dart';
import '../../domain/repositories/social_repository.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/brainstorm.dart';

class SocialCubit extends Cubit<SocialState> {
  final SocialRepository repository;

  SocialCubit({required this.repository}) : super(SocialInitial());

  static SocialCubit get(context) => BlocProvider.of<SocialCubit>(context);

  List<Post> posts = [];
  List<BrainStorm> brainStorms = [];
  int currentCarouselIndex = 0;

  void changeCarouselIndex(int index) {
    currentCarouselIndex = index;
    emit(CarouselIndexChanged(index));
  }

  /// Loads posts for [compoundId] (Appwrite `compounds` document `\$id`).
  Future<void> getPosts(String compoundId) async {
    emit(SocialLoading());
    try {
      posts = await repository.getPosts(compoundId);
      emit(PostsLoaded(List.from(posts)));
    } catch (e) {
      emit(SocialError(e.toString()));
    }
  }

  Future<void> deleteMyPost({
    required String compoundId,
    required String authorId,
    required String postId,
  }) async {
    try {
      await repository.deleteMyPost(authorId: authorId, postId: postId);
      await getPosts(compoundId);
    } catch (e) {
      emit(SocialError(e.toString()));
    }
  }

  Future<void> createPost({
    required String postHead,
    required bool getCalls,
    required String compoundId,
    required String authorId,
    List<XFile>? files,
  }) async {
    emit(SocialLoading());
    try {
      await repository.createPost(
        postHead: postHead,
        getCalls: getCalls,
        compoundId: compoundId,
        authorId: authorId,
        files: files,
      );
      emit(PostCreated());
      await getPosts(compoundId);
    } catch (e) {
      emit(SocialError(e.toString()));
    }
  }

  Future<void> addComment({
    required String compoundId,
    required String postId,
    required String commentText,
    required String authorId,
    required List<Map<String, dynamic>> currentComments,
  }) async {
    try {
      await repository.addComment(
        compoundId: compoundId,
        postId: postId,
        commentText: commentText,
        authorId: authorId,
        currentComments: currentComments,
      );
      emit(PostCommentUpdated());
      await getPosts(compoundId);
    } catch (e) {
      emit(SocialError(e.toString()));
    }
  }

  /// [channelId] is the Appwrite `channels` document `\$id` stored on messages as `channel_id`.
  Future<void> getBrainStorms(String channelId, String compoundId) async {
    emit(SocialLoading());
    try {
      brainStorms = await repository.getBrainStorms(channelId, compoundId);
      emit(BrainStormsLoaded(List.from(brainStorms)));
    } catch (e) {
      emit(SocialError(e.toString()));
    }
  }

  Future<void> createBrainStorm({
    required String title,
    required List<XFile>? images,
    required dynamic options,
    required String channelId,
    required String compoundId,
    required String authorId,
  }) async {
    emit(SocialLoading());
    try {
      await repository.createBrainStorm(
        title: title,
        images: images,
        options: options,
        channelId: channelId,
        compoundId: compoundId,
        authorId: authorId,
      );
      emit(BrainStormCreated());
      await getBrainStorms(channelId, compoundId);
    } catch (e) {
      emit(SocialError(e.toString()));
    }
  }

  Future<void> voteBrainStorm({
    required String pollId,
    required String optionId,
    required String userId,
    required List<Map<String, dynamic>> currentOptions,
    required Map<String, dynamic>? currentVotes,
    required String channelId,
    required String compoundId,
  }) async {
    try {
      await repository.voteBrainStorm(
        pollId: pollId,
        optionId: optionId,
        userId: userId,
        currentOptions: currentOptions,
        currentVotes: currentVotes,
      );
      emit(BrainStormVoteUpdated());
      await getBrainStorms(channelId, compoundId);
    } catch (e) {
      emit(SocialError(e.toString()));
    }
  }

  Future<void> addBrainStormComment({
    required String channelId,
    required String compoundId,
    required String pollId,
    required String commentText,
    required String authorId,
    required List<Map<String, dynamic>> currentComments,
  }) async {
    try {
      await repository.addBrainStormComment(
        channelId: channelId,
        compoundId: compoundId,
        pollId: pollId,
        commentText: commentText,
        authorId: authorId,
        currentComments: currentComments,
      );
      emit(BrainStormCommentUpdated());
      await getBrainStorms(channelId, compoundId);
    } catch (e) {
      emit(SocialError(e.toString()));
    }
  }
}
