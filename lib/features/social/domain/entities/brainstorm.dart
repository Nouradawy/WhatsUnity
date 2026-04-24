import 'package:equatable/equatable.dart';

class BrainStorm extends Equatable {
  final String id;
  final String authorId;
  final DateTime createdAt;
  final String compoundId;
  final String channelId;
  final String title;
  final List<Map<String, dynamic>> image;
  final List<Map<String, dynamic>> options;
  final Map<String, dynamic>? votes;
  final List<Map<String, dynamic>> comments;

  const BrainStorm({
    required this.id,
    required this.authorId,
    required this.createdAt,
    required this.compoundId,
    required this.channelId,
    required this.title,
    required this.image,
    required this.options,
    required this.comments,
    this.votes,
  });

  @override
  List<Object?> get props => [
        id,
        authorId,
        createdAt,
        compoundId,
        channelId,
        title,
        image,
        options,
        votes,
        comments,
      ];
}
