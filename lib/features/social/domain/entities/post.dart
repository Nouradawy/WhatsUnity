import 'package:equatable/equatable.dart';

class Post extends Equatable {
  final String id;
  final String compoundId;
  final String authorId;
  final String postHead;
  final List<Map<String, dynamic>> sourceUrl;
  final bool getCalls;
  final List<Map<String, dynamic>> comments;
  final DateTime? createdAt;

  const Post({
    required this.id,
    required this.compoundId,
    required this.authorId,
    required this.postHead,
    required this.sourceUrl,
    required this.getCalls,
    required this.comments,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        compoundId,
        authorId,
        postHead,
        sourceUrl,
        getCalls,
        comments,
        createdAt,
      ];
}

class Comment extends Equatable {
  final String authorId;
  final String comment;

  const Comment({
    required this.authorId,
    required this.comment,
  });

  @override
  List<Object?> get props => [authorId, comment];
}
