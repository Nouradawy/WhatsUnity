import 'package:image_picker/image_picker.dart';

import '../../../../core/config/Enums.dart';
import '../../../../core/config/app_directory_types.dart' show CompoundMembersResult;
import '../../../../core/models/CompoundsList.dart';
import '../entities/app_user.dart';

abstract class AuthRepository {
  // ── Auth operations ─────────────────────────────────────────────────────────
  Future<AppUser?> signInWithGoogle();
  Future<AppUser?> signInWithPassword({required String email, required String password});
  Future<void> signUp({required String email, required String password, required Map<String, dynamic> data});
  Future<void> signOut();

  // ── Profile / account management ────────────────────────────────────────────
  Future<void> updateProfile({
    required String fullName,
    required String displayName,
    required OwnerTypes ownerType,
    required String phoneNumber,
  });
  Future<void> completeRegistration({
    required String fullName,
    required String userName,
    required OwnerTypes ownerType,
    required String phoneNumber,
    required int roleId,
    required String buildingName,
    required String apartmentNum,
    required String compoundId,
  });
  Future<void> uploadVerificationFiles({
    required List<XFile> files,
    required String userId,
    required void Function(int index, double progress) onProgress,
  });
  Future<bool> isApartmentTaken({
    required String compoundId,
    required String buildingName,
    required String apartmentNum,
  });
  Future<void> selectCompound({required String compoundId, required String compoundName, required bool atWelcome});
  Future<void> requestEmailChange(String newEmail, {String? redirectUrl});
  Future<void> updatePassword(String newPassword);
  Future<AppUser?> completeWebGoogleLogin(String idToken);

  // ── Data-loading helpers used by AuthCubit ──────────────────────────────────
  Future<List<Category>> loadCompounds();
  Future<CompoundMembersResult> loadCompoundMembers(String compoundId, {Roles? role});

  /// Resolves the compound ID that was last assigned to [userId] in
  /// user_apartments.  Used as a fallback inside presetBeforeSignin.
  Future<String?> getDefaultCompoundId(String userId);

  // ── Auth state stream (Appwrite-backed) ─
  /// Emits the current [AppUser] when signed in, or `null` when signed out.
  /// Both [AuthManager] and the [AuthCubit] constructor listen to this stream.
  Stream<AppUser?> get onAuthStateChange;

  /// Synchronously returns the last known user (populated after
  /// [_checkExistingSession] completes or after any sign-in / sign-out).
  AppUser? get currentUser;

  /// Calls account.get() and updates [currentUser]; safe to await before
  /// using the result in [AuthCubit._presetBeforeSigninImpl].
  Future<AppUser?> fetchCurrentUser();

  /// Sets [currentUser] without calling Appwrite (offline cold boot after
  /// [fetchCurrentUser] failed). Does not emit [onAuthStateChange].
  void primeCurrentUser(AppUser user);
}
