import '../../domain/entities/user_report.dart';

class UserReportModel extends UserReport {
  const UserReportModel({
    super.id,
    required super.authorId,
    required super.createdAt,
    required super.reportedUserId,
    required super.state,
    required super.description,
    required super.messageId,
    required super.reportedFor,
  });

  factory UserReportModel.fromJson(Map<String, dynamic> json) {
    return UserReportModel(
      id: json['id'] != null ? json['id'].toString() : null,
      authorId: json['authorId'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      reportedUserId: json['reportedUserId'] ?? '',
      state: json['state'] ?? '',
      description: json['description'] ?? '',
      messageId: json['messageId'] ?? '',
      reportedFor: json['reportedFor'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'authorId': authorId,
      'createdAt': createdAt.toIso8601String(),
      'reportedUserId': reportedUserId,
      'state': state,
      'description': description,
      'messageId': messageId,
      'reportedFor': reportedFor,
    };
  }
}
