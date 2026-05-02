/**
 * [AuthRemoteDataSource]
 *
 * This file manages all remote-facing authentication and user profile operations with Appwrite.
 */
import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:appwrite/models.dart' as aw_models;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../../../core/config/appwrite.dart' show appwriteDatabaseId;
import '../../../../core/media/media_services.dart';
import '../../domain/entities/app_user.dart';

// ── Abstract contract ──────────────────────────────────────────────────────────

/// Contract for Appwrite authentication and user operations.
/// Logic here is strictly remote-facing and prefixed with 'remote'.
abstract class AuthRemoteDataSource {
  // ── Core Authentication ──────────────────────────────────────────────────

  /// Returns the signed-in [AppUser] or `null` when no active session exists.
  Future<AppUser?> remoteFetchCurrentUser();

  /// Creates an email/password Appwrite session and returns the authenticated account.
  Future<AppUser?> remoteSignInWithPassword({
    required String email,
    required String password,
  });

  /// Initiates Appwrite's native Google OAuth2 flow.
  /// Handles Android native bridge and fallback for other platforms.
  Future<AppUser?> remoteSignInWithGoogle();

  /// Completes the Google login on Web using an idToken via the backend bridge.
  Future<AppUser?> remoteCompleteWebGoogleLogin(String idToken);

  /// Creates an Appwrite account and an email session.
  /// Triggers [functions/on_user_register] via Appwrite prefs update.
  Future<void> remoteSignUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  });

  /// Ends the current Appwrite session.
  Future<void> remoteSignOut();

  /// Fetches members for a compound that have been updated since [sinceIso].
  Future<List<Map<String, dynamic>>> remoteFetchMembersDelta({
    required String compoundId,
    String? sinceIso,
  });

  // ── Side Effects ─────────────────────────────────────────────────────────

  /// Uploads verification images via [mediaUploadService] (R2 presign).
  Future<void> remoteUploadVerificationFiles({
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
    required TablesDB tables,
    String? googleServerClientId,
    String? nativeGoogleBridgeFunctionId,
    this.oauthSuccessUrl,
    this.oauthFailureUrl,
  }) : _account = account,
       _functions = functions,
       _tables = tables,
       _googleServerClientId = googleServerClientId,
       _nativeGoogleBridgeFunctionId =
           (nativeGoogleBridgeFunctionId?.trim().isNotEmpty ?? false)
               ? nativeGoogleBridgeFunctionId!.trim()
               : _kDefaultNativeGoogleBridgeFunctionId;

  final Account _account;
  final Functions _functions;
  final TablesDB _tables;
  final String? _googleServerClientId;
  final String _nativeGoogleBridgeFunctionId;

  static const String _kDefaultNativeGoogleBridgeFunctionId =
      'google_native_signin_bridge';

  static const String _kUserApartmentsCollectionId = 'user_apartments';
  static const String _kProfilesCollectionId = 'profiles';

  /// Deep-link URLs used by [signInWithGoogle] (non-web and optional overrides on web).
  final String? oauthSuccessUrl;
  final String? oauthFailureUrl;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // ── Core Auth Implementation ───────────────────────────────────────────────

  @override
  Future<AppUser?> remoteFetchCurrentUser() async {
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
  Future<AppUser?> remoteSignInWithPassword({
    required String email,
    required String password,
  }) async {
    // Authenticate with Appwrite
    await _account.createEmailPasswordSession(email: email, password: password);
    // Fetch full user profile including prefs/metadata
    return await remoteFetchCurrentUser();
  }

  @override
  Future<AppUser?> remoteSignInWithGoogle() async {
    if (_isAndroid) {
      return _remoteSignInWithGoogleAndroidNative();
    }

    if (kIsWeb) {
      // Handled by the Google HTML button natively on web.
      return null;
    }
    // iOS/Others: Appwrite OAuth flow
    await _account.createOAuth2Session(provider: OAuthProvider.google);
    return await remoteFetchCurrentUser();
  }

  @override
  Future<AppUser?> remoteCompleteWebGoogleLogin(String idToken) async {
    // Uses a Cloud Function bridge to create an Appwrite session from a Google idToken
    final bridge = await _invokeNativeGoogleBridge(idToken: idToken);
    final userId = (bridge['userId'] ?? '').toString().trim();
    final secret = (bridge['secret'] ?? '').toString().trim();

    if (userId.isEmpty || secret.isEmpty) {
      throw Exception('Web Google bridge failed: missing userId/secret');
    }

    await _account.createSession(userId: userId, secret: secret);
    
    // Sync Google picture to Appwrite prefs if it's a new or empty profile
    final googlePicture = (bridge['picture'] ?? '').toString().trim();
    if (googlePicture.isNotEmpty) {
      final user = await _account.get();
      final currentPrefs = Map<String, dynamic>.from(user.prefs.data);
      if (currentPrefs['avatar_url'] == null || currentPrefs['avatar_url'].toString().isEmpty) {
        currentPrefs['avatar_url'] = googlePicture;
        await _account.updatePrefs(prefs: currentPrefs);
      }
    }

    return await remoteFetchCurrentUser();
  }

  @override
  Future<void> remoteSignUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) async {
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
    
    // Auto-sign-in after creation to establish session context for metadata updates
    await _account.createEmailPasswordSession(email: email, password: password);
  }

  @override
  Future<void> remoteSignOut() async {
    // Kills the 'current' Appwrite session
    await _account.deleteSession(sessionId: 'current');
  }

  @override
  Future<List<Map<String, dynamic>>> remoteFetchMembersDelta({
    required String compoundId,
    String? sinceIso,
  }) async {
    final queries = [
      Query.equal('compound_id', compoundId),
      if (sinceIso != null) Query.greaterThan(r'$updatedAt', sinceIso),
      Query.limit(500),
    ];

    // 1. Fetch from user_apartments
    final apartments = await _tables.listRows(
      databaseId: appwriteDatabaseId,
      tableId: _kUserApartmentsCollectionId,
      queries: queries,
    );

    if (apartments.rows.isEmpty) return [];

    final userIds = apartments.rows.map((doc) => doc.data['user_id'].toString()).toList();

    // 2. Fetch profiles for these users
    final profiles = await _tables.listRows(
      databaseId: appwriteDatabaseId,
      tableId: _kProfilesCollectionId,
      queries: [
        Query.equal(r'$id', userIds),
      ],
    );

    // 3. Join the data
    final profileMap = {for (var p in profiles.rows) p.$id: p.data};
    final out = <Map<String, dynamic>>[];

    for (final apt in apartments.rows) {
      final uid = apt.data['user_id'].toString();
      final p = profileMap[uid];
      if (p == null) continue;

      out.add({
        'id': uid,
        'display_name': p['display_name'],
        'full_name': p['full_name'],
        'avatar_url': p['avatar_url'],
        'building_num': apt.data['building_name'],
        'apartment_num': apt.data['apartment_num'],
        'phone_number': p['phone_number'],
        'owner_type': p['owner_type'],
        'userState': p['userState'],
      });
    }

    return out;
  }

  // ── Side Effects Implementation ───────────────────────────────────────────

  @override
  Future<void> remoteUploadVerificationFiles({
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

  // ── Internal Helpers ──────────────────────────────────────────────────────

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
        'google_native_signin_bridge failed: http=${execution.responseStatusCode}',
      );
    }
    
    final decoded = jsonDecode(execution.responseBody);
    return Map<String, dynamic>.from(decoded);
  }

  Future<AppUser?> _remoteSignInWithGoogleAndroidNative() async {
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(serverClientId: _googleServerClientId);

    final selectedAccount = await googleSignIn.authenticate();
    // Use the account if not null
    if (selectedAccount == null) return null;

    final auth = selectedAccount.authentication;
    final bridge = await _invokeNativeGoogleBridge(idToken: auth.idToken!);
    
    final userId = bridge['userId'].toString();
    final secret = bridge['secret'].toString();

    await _account.createSession(userId: userId, secret: secret);
    
    // Sync Google picture to Appwrite prefs if it's a new or empty profile
    final googlePicture = (bridge['picture'] ?? '').toString().trim();
    if (googlePicture.isNotEmpty) {
      final user = await _account.get();
      final currentPrefs = Map<String, dynamic>.from(user.prefs.data);
      if (currentPrefs['avatar_url'] == null || currentPrefs['avatar_url'].toString().isEmpty) {
        currentPrefs['avatar_url'] = googlePicture;
        await _account.updatePrefs(prefs: currentPrefs);
      }
    }

    return _toAppUser(await _account.get());
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
