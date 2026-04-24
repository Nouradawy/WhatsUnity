import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'social_state.dart';
import '../../domain/repositories/social_repository.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/brainstorm.dart';

class SocialCubit extends Cubit<SocialState> {
  final SocialRepository repository;

  SocialCubit({required this.repository}) : super(SocialInitial());

  static SocialCubit get(context) =>  BlocProvider.of<SocialCubit>(context);

  /// Maps legacy [int] call sites and new [String] ids to repository [String] ids.
  static String _compoundIdStr(Object compoundId) => compoundId.toString();

  List<Post> posts = [];
  List<BrainStorm> brainStorms = [];
  int currentCarouselIndex = 0;

  void changeCarouselIndex(int index) {
    currentCarouselIndex = index;
    emit(CarouselIndexChanged(index));
  }

  Future<void> getPosts(Object compoundId) async {
    emit(SocialLoading());
    try {
      final id = _compoundIdStr(compoundId);
      posts = await repository.getPosts(id);
      emit(PostsLoaded(List.from(posts)));
    } catch (e) {
      emit(SocialError(e.toString()));
    }
  }

  Future<void> createPost({
    required String postHead,
    required bool getCalls,
    required Object compoundId,
    required String authorId,
    List<XFile>? files,
  }) async {
    emit(SocialLoading());
    try {
      final id = _compoundIdStr(compoundId);
      await repository.createPost(
        postHead: postHead,
        getCalls: getCalls,
        compoundId: id,
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
    required Object compoundId,
    required String postId,
    required String commentText,
    required String authorId,
    required List<Map<String, dynamic>> currentComments,
  }) async {
    try {
      final id = _compoundIdStr(compoundId);
      await repository.addComment(
        compoundId: id,
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

  Future<void> getBrainStorms(Object channelId, Object compoundId) async {
    emit(SocialLoading());
    try {
      final ch = _compoundIdStr(channelId);
      final co = _compoundIdStr(compoundId);
      brainStorms = await repository.getBrainStorms(ch, co);
      emit(BrainStormsLoaded(List.from(brainStorms)));
    } catch (e) {
      emit(SocialError(e.toString()));
    }
  }

  Future<void> createBrainStorm({
    required String title,
    required List<XFile>? images,
    required dynamic options,
    required Object channelId,
    required Object compoundId,
    required String authorId,
  }) async {
    emit(SocialLoading());
    try {
      final ch = _compoundIdStr(channelId);
      final co = _compoundIdStr(compoundId);
      await repository.createBrainStorm(
        title: title,
        images: images,
        options: options,
        channelId: ch,
        compoundId: co,
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
    required Object channelId,
    required Object compoundId,
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
      // Refresh to get updated votes
      await getBrainStorms(channelId, compoundId);
    } catch (e) {
      emit(SocialError(e.toString()));
    }
  }

  Future<void> addBrainStormComment({
    required Object channelId,
    required Object compoundId,
    required String pollId,
    required String commentText,
    required String authorId,
    required List<Map<String, dynamic>> currentComments,
  }) async {
    try {
      final ch = _compoundIdStr(channelId);
      final co = _compoundIdStr(compoundId);
      await repository.addBrainStormComment(
        channelId: ch,
        compoundId: co,
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
