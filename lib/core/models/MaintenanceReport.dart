import '../config/Enums.dart';

class MaintenanceReports {
  final String? id;
  final String userId;
  final String reportCode;
  final String title;
  final String description;
  final String category;
  final String states;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final MaintenanceReportType type;

  MaintenanceReports({
    this.id,
    required this.userId,
    required this.reportCode,
    required this.title,
    required this.description,
    required this.category,
    required this.states,
    this.createdAt,
    this.updatedAt,
    required this.type
  });

  factory MaintenanceReports.fromJson(Map<String, dynamic> json) {
    return MaintenanceReports(
      id: json["id"]?.toString(),
      userId: json["user_id"],
      reportCode: json['report_code'],
      title: json["title"],
      description: json["description"],
      category: json["category"],
      states: json["status"],
      createdAt:  DateTime.tryParse(json["created_at"]),
      updatedAt:  DateTime.tryParse(json["updated_at"]),
      type: MaintenanceReportType.values.firstWhere((main) => main.name == json["type"]) ,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'report_code': reportCode,
      'title': title,
      'description': description,
      'category': category,
      'status': states,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'type': type.name,
    };
  }

}

class MaintenanceReportsHistory {
  final String? id;
  final String reportId;
  final String actorId;
  final String action;
  final DateTime createdAt;

  MaintenanceReportsHistory({
    this.id,
    required this.reportId,
    required this.actorId,
    required this.action,
    required this.createdAt

});

  factory MaintenanceReportsHistory.fromJson(Map<String, dynamic> json) {
    return MaintenanceReportsHistory(
        id: json["id"]?.toString(),
        reportId: json["report_id"].toString(),
        actorId: json["actor_id"],
        action: json["action"],
        createdAt: DateTime.tryParse(json["created_at"])!.toLocal(),
    );
  }

  Map<String,dynamic> toJson(){
    return{
      'report_id':reportId,
      'actor_id':actorId,
      'action' : action,
      'created_at' : createdAt.toIso8601String()
    };
  }
}

class MaintenanceReportsAttachments {
  final String? id;
  final String? reportId;
  final List? sourceUrl;
  final DateTime? createdAt;

  MaintenanceReportsAttachments({
    this.id,
    required this.reportId,
    required this.sourceUrl,
    required this.createdAt
});

  factory MaintenanceReportsAttachments.fromJson(Map<String, dynamic> json) {
    return MaintenanceReportsAttachments(
        id: json['id']?.toString(),
        reportId: json['report_id']?.toString(),
        sourceUrl: json['source_url'],
        createdAt: DateTime.tryParse(json['created_at']),
    );
  }
}

