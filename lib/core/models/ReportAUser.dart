class ReportAUsers {
  final String? id;
  final String authorId;
  final DateTime createdAt;
  final String reportedUserId;
  final String state;
  final String description;
  final String messageId;
  final String reportedFor;


  ReportAUsers({
    this.id,
    required this.authorId,
    required this.createdAt,
    required this.reportedUserId,
    required this.state,
    required this.description,
    required this.messageId,
    required this.reportedFor,
  });

  factory ReportAUsers.fromJson(Map<String, dynamic> json) {
    return ReportAUsers(
      id: json['id'] != null ? json['id'].toString() : null,
      authorId: json['authorId'],
      createdAt: DateTime.tryParse(json['createdAt'])!,
      reportedUserId: json['reportedUserId'],
      state: json['state'],
      description: json['description'],
      messageId: json['messageId'],
      reportedFor: json['reportedFor'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'authorId': authorId.trim(),
      'createdAt': createdAt.toIso8601String(),
      'reportedUserId': reportedUserId.trim(),
      'state': state,
      'description': description,
      'messageId': messageId,
      'reportedFor': reportedFor,
    };
  }


}

