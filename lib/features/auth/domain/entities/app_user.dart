/// Domain-level user entity.
///
/// Replaces [supabase_flutter.User] in the auth layer after migration to Appwrite.
/// Property names intentionally mirror the subset that existing UI and cubits
/// already access — [id], [email], [userMetadata] — so no widget code needs
/// to change when [AuthState.Authenticated.user] swaps to this type.
///
/// Appwrite mapping:
///   • [id]           ← appwrite_models.User.$id
///   • [email]        ← appwrite_models.User.email
///   • [userMetadata] ← appwrite_models.User.prefs.data
///     – should contain 'role_id' as a string (for example: '1', '2', '3').
class AppUser {
  const AppUser({
    required this.id,
    this.email,
    this.userMetadata,
  });

  final String id;
  final String? email;

  /// Arbitrary key-value store persisted as Appwrite Account Preferences.
  /// Convention: always store [role_id] here so the existing role-resolution
  /// logic in [AuthCubit._presetBeforeSigninImpl] works without change.
  final Map<String, dynamic>? userMetadata;

  AppUser copyWith({
    String? id,
    String? email,
    Map<String, dynamic>? userMetadata,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      userMetadata: userMetadata ?? this.userMetadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUser && other.id == id && other.email == email);

  @override
  int get hashCode => Object.hash(id, email);

  @override
  String toString() => 'AppUser(id: $id, email: $email)';
}
