import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:appwrite/models.dart' as aw_models;
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/GoogleDriveService.dart';
import '../../domain/entities/app_user.dart';

// ── Abstract contract ──────────────────────────────────────────────────────────

abstract class AuthRemoteDataSource {
  /// Returns the signed-in [AppUser] or `null` when no active session exists.
  Future<AppUser?> getCurrentUser();

  Future<AppUser?> signInWithPassword({
    required String email,
    required String password,
  });

  /// Initiates Appwrite's native Google OAuth2 flow.
  ///
  /// On Android / iOS this opens a Custom Tab / SFSafariViewController and the
  /// Future resolves once the system deep-link redirect is received.
  ///
  /// **Platform setup required** (see MIGRATION_PLAN.md §4):
  ///   • `.env` APPWRITE_OAUTH_SUCCESS and APPWRITE_OAUTH_FAILURE URL-scheme values
  ///   • Android: intent-filter with the scheme in AndroidManifest.xml
  ///   • iOS: CFBundleURLTypes entry in Info.plist
  Future<AppUser?> signInWithGoogle();

  /// Creates an Appwrite account and an email session. Provisioning prefs for
  /// [functions/on_user_register] are written in [AuthRepositoryImpl] (after this call).
  Future<void> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  });

  Future<void> signOut();

  /// Uploads [files] to Google Drive (unchanged; Cloudflare R2 replaces this
  /// in Phase-4 Storage of the migration plan).
  Future<void> uploadVerificationFiles({
    required List<XFile> files,
    required String userId,
    required GoogleDriveService driveService,
    required void Function(int index, double progress) onProgress,
  });
}

// ── Appwrite implementation ────────────────────────────────────────────────────

class AppwriteAuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AppwriteAuthRemoteDataSourceImpl({
    required Account account,
    this.oauthSuccessUrl,
    this.oauthFailureUrl,
  }) : _account = account;

  final Account _account;

  /// Deep-link URLs used by [signInWithGoogle].
  /// Falls back to Appwrite's built-in callback when null.
  final String? oauthSuccessUrl;
  final String? oauthFailureUrl;

  // ── Internal helpers ──────────────────────────────────────────────────────

  AppUser _toAppUser(aw_models.User user) => AppUser(
        id: user.$id,
        email: user.email,
        userMetadata: Map<String, dynamic>.from(user.prefs.data),
      );

  // ── AuthRemoteDataSource ──────────────────────────────────────────────────

  @override
  Future<AppUser?> getCurrentUser() async {
    try {
      final user = await _account.get();
      return _toAppUser(user);
    } on AppwriteException catch (e) {
      // 401 = no active session; surface as null rather than an exception.
      if (e.code == 401) return null;
      rethrow;
    }
  }

  @override
  Future<AppUser?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _account.createEmailPasswordSession(
      email: email,
      password: password,
    );
    return await getCurrentUser();
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    await _account.createOAuth2Session(
      provider: OAuthProvider.google,
      success: oauthSuccessUrl,
      failure: oauthFailureUrl,
    );
    return await getCurrentUser();
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) async {
    // Appwrite Account `name` must be 1–128 chars. Prefer full_name, then display_name.
    // Sign-up UI must send `full_name` (legacy used `FullName`, which was never read here).
    String? trimmed(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    final fullName = trimmed(data['full_name']);
    final displayName = trimmed(data['display_name']);
    final accountName =
        fullName ?? displayName ?? '';

    if (accountName.isEmpty) {
      throw Exception(
        'Full name and display name are required to create an account.',
      );
    }

    await _account.create(
      userId: ID.unique(),
      email: email,
      password: password,
      name: accountName,
    );
    // [Account.create] does not leave the client in a *user* session — without this
    // the project role stays `guests`, and [Account.getPrefs] / [updatePrefs] in
    // [AuthRepositoryImpl.signUp] throw `general_unauthorized_scope` (missing
    // `account` scope for guests).
    await _account.createEmailPasswordSession(
      email: email,
      password: password,
    );
    // 6-digit OTP is sent from [OtpScreen] (first frame + resend) via
    // [Account.createEmailToken] so the user only completes verification in-app.
    // Do not call [createEmailToken] here — it would duplicate the email and push
    // a second code before the OTP screen opens.
  }

  @override
  Future<void> signOut() async {
    await _account.deleteSession(sessionId: 'current');
  }

  @override
  Future<void> uploadVerificationFiles({
    required List<XFile> files,
    required String userId,
    required GoogleDriveService driveService,
    required void Function(int index, double progress) onProgress,
  }) async {
    for (int i = 0; i < files.length; i++) {
      final xfile = files[i];
      final file = File(xfile.path);
      // TODO(Phase-4 Storage): replace with a signed Cloudflare R2 upload.
      await driveService.uploadFile(file, xfile.name, 'image');
      onProgress(i, 1.0);
    }
  }
}
