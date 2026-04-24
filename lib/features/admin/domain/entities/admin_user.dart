import 'package:equatable/equatable.dart';

class AdminUser extends Equatable {
  final String authorId;
  final String phoneNumber;
  final DateTime updatedAt;
  final String ownerShipType;
  final String userState;
  final String actionTakenBy;
  final List<Map<String, dynamic>> verFiles;

  const AdminUser({
    required this.authorId,
    required this.phoneNumber,
    required this.updatedAt,
    required this.ownerShipType,
    required this.userState,
    required this.actionTakenBy,
    required this.verFiles,
  });

  @override
  List<Object?> get props => [
    authorId,
    phoneNumber,
    updatedAt,
    ownerShipType,
    userState,
    actionTakenBy,
    verFiles,
  ];
}
