import '../../domain/entities/admin_user.dart';

class AdminUserModel extends AdminUser {
  const AdminUserModel({
    required super.authorId,
    required super.phoneNumber,
    required super.updatedAt,
    required super.ownerShipType,
    required super.userState,
    required super.actionTakenBy,
    required super.verFiles,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    return AdminUserModel(
      authorId: json['id'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      ownerShipType: json['owner_type'] ?? '',
      userState: json['userState'] ?? '',
      actionTakenBy: json['actionTakenBy'] ?? '',
      verFiles: (json['verFiles'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': authorId,
      'phone_number': phoneNumber,
      'updated_at': updatedAt.toIso8601String(),
      'owner_type': ownerShipType,
      'userState': userState,
      'actionTakenBy': actionTakenBy,
      'verFiles': verFiles,
    };
  }
}
