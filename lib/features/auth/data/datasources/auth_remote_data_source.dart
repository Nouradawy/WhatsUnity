import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:appwrite/models.dart' as aw_models;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../../../core/media/media_services.dart';
import '../../domain/entities/app_user.dart';

// ── Abstract contract ──────────────────────────────────────────────────────────

abstract class AuthRemoteDataSource {
  /// Returns the signed-in [AppUser] or `null` when no active session exists.
  Future<AppUser?> remote_getCurrentUser();

  /// Creates an email/password Appwrite session and returns the authenticated account.
  Future<AppUser?> remote_signInWithPassword({
    required String email,
    required String password,
  });

  /// Initiates Appwrite's native Google OAuth2 flow.
  ///
  /// On Android / iOS this opens a Custom Tab / SFSafariViewController and the
  /// Future resolves once the system deep-link redirect is received.
  ///
  /// **Platform setup required** (see MIGRATION_PLAN.md §4):
  ///   • **Web:** Appwrite opens Google in another tab/window (`flutter_web_auth_2`);
  ///     that is expected. Set `APPWRITE_OAUTH_SUCCESS` / `APPWRITE_OAUTH_FAILURE`
  ///     to your deployed **https** URLs (must match Appwrite Auth → Platforms and
  ///     Google OAuth redirect allowlists). If unset on web, the app uses the
  ///     current page origin + path as return URLs.
  ///   • **Android:** intent-filter with the URL scheme in AndroidManifest.xml
  ///   • **iOS:** CFBundleURLTypes entry in Info.plist
  Future<AppUser?> remote_signInWithGoogle();

  /// Creates an Appwrite account and an email session. Provisioning prefs for
  /// [functions/on_user_register] are written in [AuthRepositoryImpl] (after this call).
  /// Creates an Appwrite account and signs in with an active user session.
  Future<void> remote_signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  });

  /// Ends the current Appwrite session.
  Future<void> remote_signOut();

  /// Uploads verification images via [mediaUploadService] (R2 presign).
  Future<void> remote_uploadVerificationFiles({
    required List<XFile> files,
    required String userId,
    required void Function(int index, double progress) onProgress,
  });
}

// ── Appwrite implementation ────────────────────────────────────────────────────

class AppwriteAuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AppwriteAuthRemoteDataSourceImpl({
    required Account account,
    required Functions functions,
    String? googleServerClientId,
    String? nativeGoogleBridgeFunctionId,
    this.oauthSuccessUrl,
    this.oauthFailureUrl,
  })  : _account = account,
        _functions = functions,
        _googleServerClientId = googleServerClientId,
        _nativeGoogleBridgeFunctionId =
            (nativeGoogleBridgeFunctionId?.trim().isNotEmpty ?? false)
                ? nativeGoogleBridgeFunctionId!.trim()
                : _kDefaultNativeGoogleBridgeFunctionId;

  final Account _account;
  final Functions _functions;
  final String? _googleServerClientId;
  final String _nativeGoogleBridgeFunctionId;

  static const String _kDefaultNativeGoogleBridgeFunctionId =
      'google_native_signin_bridge';

  /// Deep-link URLs used by [signInWithGoogle] (non-web and optional overrides on web).
  /// On web, when null, [remote_signInWithGoogle] uses [Uri.base] without query/fragment.
  final String? oauthSuccessUrl;
  final String? oauthFailureUrl;

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// OAuth return base for web: current location without query or fragment so Appwrite
  /// can redirect back with `userId` / `secret` query params on success.
  Uri _webOAuthReturnBaseUri() {
    final b = Uri.base;
    final path = b.path.isEmpty ? '/' : b.path;
    return b.replace(path: path, query: '', fragment: '');
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  AppUser _toAppUser(aw_models.User user) => AppUser(
    id: user.$id,
    email: user.email,
    userMetadata: Map<String, dynamic>.from(user.prefs.data),
  );

  Future<Map<String, dynamic>> _invokeNativeGoogleBridge({
    required String idToken,
  }) async {
    final execution = await _functions.createExecution(
      functionId: _nativeGoogleBridgeFunctionId,
      body: jsonEncode({'idToken': idToken}),
      xasync: false,
    );

    if (execution.status == ExecutionStatus.failed) {
      throw Exception(
        'google_native_signin_bridge failed: '
        'http=${execution.responseStatusCode} body=${execution.responseBody}',
      );
    }
    if (execution.responseStatusCode >= 400) {
      throw Exception(
        'google_native_signin_bridge HTTP ${execution.responseStatusCode}: '
        '${execution.responseBody}',
      );
    }

    final raw = execution.responseBody.trim();
    if (raw.isEmpty) {
      throw Exception('google_native_signin_bridge returned empty response body.');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw Exception('google_native_signin_bridge response must be JSON object.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<AppUser?> _remote_signInWithGoogleAndroidNative() async {
    final serverClientId = _googleServerClientId?.trim();
    if (serverClientId == null || serverClientId.isEmpty) {
      throw Exception(
        'Missing GOOGLE_SERVER_CLIENT_ID at build time '
        '(e.g. --dart-define-from-file=.env). '
        'Use your Google Cloud "Web application" client ID.',
      );
    }

    final googleSignIn = GoogleSignIn(
      scopes: const ['email', 'profile', 'openid'],
      serverClientId: serverClientId,
    );

    final selectedAccount = await googleSignIn.signIn();
    if (selectedAccount == null) return null; // User cancelled picker.

    final auth = await selectedAccount.authentication;
    final idToken = auth.idToken?.trim();
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Google Sign-In did not return idToken. '
        'Check GOOGLE_SERVER_CLIENT_ID (must be Web client ID).',
      );
    }

    final bridge = await _invokeNativeGoogleBridge(idToken: idToken);
    final userId = (bridge['userId'] ?? '').toString().trim();
    final secret = (bridge['secret'] ?? '').toString().trim();
    final email = (bridge['email'] ?? '').toString().trim();
    final name = (bridge['name'] ?? '').toString().trim();
    final avatarUrl = (bridge['picture'] ?? '').toString().trim();
    if (userId.isEmpty || secret.isEmpty) {
      throw Exception(
        'google_native_signin_bridge returned invalid userId/secret payload: $bridge',
      );
    }

    await _account.createSession(userId: userId, secret: secret);
    // Avoid an immediate extra /account call after session creation.
    // We already have user identity from the bridge payload.
    return AppUser(
      id: userId,
      email: email.isEmpty ? null : email,
      userMetadata: <String, dynamic>{
        if (name.isNotEmpty) 'name': name,
        if (avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
      },
    );
  }

  // ── AuthRemoteDataSource ──────────────────────────────────────────────────

  @override
  Future<AppUser?> remote_getCurrentUser() async {
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
  Future<AppUser?> remote_signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _account.createEmailPasswordSession(email: email, password: password);
    return await remote_getCurrentUser();
  }

  @override
  Future<AppUser?> remote_signInWithGoogle() async {
    if (_isAndroid) {
      return _remote_signInWithGoogleAndroidNative();
    }

    String? success = oauthSuccessUrl?.trim();
    if (success != null && success.isEmpty) success = null;
    String? failure = oauthFailureUrl?.trim();
    if (failure != null && failure.isEmpty) failure = null;

    if (kIsWeb) {
      final base = _webOAuthReturnBaseUri();
      success ??= base.toString();
      failure ??= base.replace(
        queryParameters: const {'appwrite_oauth': 'google_failure'},
      ).toString();
    }

    await _account.createOAuth2Session(
      provider: OAuthProvider.google,
      success: success,
      failure: failure,
    );
    return await remote_getCurrentUser();
  }

  @override
  Future<void> remote_signUp({
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
    final accountName = fullName ?? displayName ?? '';

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
    await _account.createEmailPasswordSession(email: email, password: password);
    // 6-digit OTP is sent from [OtpScreen] (first frame + resend) via
    // [Account.createEmailToken] so the user only completes verification in-app.
    // Do not call [createEmailToken] here — it would duplicate the email and push
    // a second code before the OTP screen opens.
  }

  @override
  Future<void> remote_signOut() async {
    await _account.deleteSession(sessionId: 'current');
  }

  @override
  Future<void> remote_uploadVerificationFiles({
    required List<XFile> files,
    required String userId,
    required void Function(int index, double progress) onProgress,
  }) async {
    for (int i = 0; i < files.length; i++) {
      final xfile = files[i];
      // MIGRATION_PLAN §5 — verification images via R2 (Appwrite Function presign).
      await _uploadVerificationToR2(xfile);
      onProgress(i, 1.0);
    }
  }

  Future<void> _uploadVerificationToR2(XFile xfile) async {
    final mime = lookupMimeType(xfile.path);
    await mediaUploadService.uploadFromLocalPath(
      localFilePath: xfile.path,
      filenameOverride: xfile.name,
      mimeType: mime,
    );
  }
}
