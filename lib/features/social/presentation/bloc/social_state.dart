import 'package:equatable/equatable.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/brainstorm.dart';

abstract class SocialState extends Equatable {
  const SocialState();

  @override
  List<Object?> get props => [];
}

class SocialInitial extends SocialState {}

class SocialLoading extends SocialState {}

class SocialError extends SocialState {
  final String message;
  const SocialError(this.message);

  @override
  List<Object?> get props => [message];
}

// Posts States
class PostsLoaded extends SocialState {
  final List<Post> posts;
  const PostsLoaded(this.posts);

  @override
  List<Object?> get props => [posts];
}

class PostCreated extends SocialState {}

class PostCommentUpdated extends SocialState {}

// Brainstorm States
class BrainStormsLoaded extends SocialState {
  final List<BrainStorm> brainStorms;
  const BrainStormsLoaded(this.brainStorms);

  @override
  List<Object?> get props => [brainStorms];
}

class BrainStormCreated extends SocialState {}

class BrainStormVoteUpdated extends SocialState {}

class BrainStormCommentUpdated extends SocialState {}

class CarouselIndexChanged extends SocialState {
  final int index;
  const CarouselIndexChanged(this.index);

  @override
  List<Object?> get props => [index];
}
