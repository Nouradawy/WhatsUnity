import '../../../../core/config/Enums.dart';

/// Encapsulates the result of [AuthRepository.processRegistration].
class RegistrationResult {
  final Roles role;
  final String selectedCompoundId;
  final String compoundName;
  final Map<String, dynamic> myCompounds;

  RegistrationResult({
    required this.role,
    required this.selectedCompoundId,
    required this.compoundName,
    required this.myCompounds,
  });
}
