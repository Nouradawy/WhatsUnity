import 'package:equatable/equatable.dart';

class UserReport extends Equatable {
  /// Appwrite document `$id` or legacy row id — always stored as [String].
  final String? id;
  final String authorId;
  final DateTime createdAt;
  final String reportedUserId;
  final String state;
  final String description;
  final String messageId;
  final String reportedFor;

  /// Optional Appwrite `compoundId` attribute for admin scoping (APPWRITE_SCHEMA.md §2.8).
  final String? compoundId;

  const UserReport({
    this.id,
    required this.authorId,
    required this.createdAt,
    required this.reportedUserId,
    required this.state,
    required this.description,
    required this.messageId,
    required this.reportedFor,
    this.compoundId,
  });

  @override
  List<Object?> get props => [
    id,
    authorId,
    createdAt,
    reportedUserId,
    state,
    description,
    messageId,
    reportedFor,
    compoundId,
  ];
}
