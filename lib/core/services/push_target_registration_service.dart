import 'dart:async';

import 'package:WhatsUnity/core/config/appwrite.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_state.dart';
import 'package:appwrite/appwrite.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Registers/updates Appwrite Messaging push targets for the signed-in user.
///
/// - Retrieves device token from Firebase Messaging.
/// - Upserts target using Appwrite Account push-target APIs.
/// - Tracks created target ID per user in SharedPreferences.
class PushTargetRegistrationService {
  PushTargetRegistrationService();

  StreamSubscription<String>? _tokenRefreshSub;
  String? _activeUserId;
  bool _firebaseReady = false;

  static const String _kPushTargetIdKeyPrefix = 'push_target_id_v1_';
  static const String _kPushTokenKeyPrefix = 'push_token_v1_';

  Future<void> startForAuthState(Authenticated authState) async {
    final userId = authState.user.id.trim();
    if (userId.isEmpty) return;
    if (_activeUserId == userId) return;
    _activeUserId = userId;

    await _ensureFirebaseInitialized();
    if (!_firebaseReady) return;

    final token = await _getMessagingToken();
    if (token != null && token.isNotEmpty) {
      await _upsertRemotePushTarget(
        userId: userId,
        token: token,
      );
    }

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (nextToken) {
        final activeUser = _activeUserId;
        if (activeUser == null || nextToken.trim().isEmpty) return;
        unawaited(
          _upsertRemotePushTarget(
            userId: activeUser,
            token: nextToken,
          ),
        );
      },
    );
  }

  Future<void> stop() async {
    _activeUserId = null;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  Future<void> _ensureFirebaseInitialized() async {
    if (_firebaseReady) return;
    try {
      if (Firebase.apps.isNotEmpty) {
        _firebaseReady = true;
        return;
      }

      if (kIsWeb) {
        final apiKey = dotenv.env['FIREBASE_WEB_API_KEY'];
        final appId = dotenv.env['FIREBASE_WEB_APP_ID'];
        final projectId = dotenv.env['FIREBASE_WEB_PROJECT_ID'];
        final messagingSenderId = dotenv.env['FIREBASE_WEB_MESSAGING_SENDER_ID'];
        if ([apiKey, appId, projectId, messagingSenderId].any((v) => v == null || v.isEmpty)) {
          debugPrint(
            'PushTargetRegistrationService: missing web Firebase env, skip web token registration.',
          );
          _firebaseReady = false;
          return;
        }
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: apiKey!,
            appId: appId!,
            projectId: projectId!,
            messagingSenderId: messagingSenderId!,
            authDomain: dotenv.env['FIREBASE_WEB_AUTH_DOMAIN'],
            storageBucket: dotenv.env['FIREBASE_WEB_STORAGE_BUCKET'],
            measurementId: dotenv.env['FIREBASE_WEB_MEASUREMENT_ID'],
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
      _firebaseReady = true;
    } catch (e) {
      debugPrint(
        'PushTargetRegistrationService: Firebase init failed: $e',
      );
      _firebaseReady = false;
    }
  }

  Future<String?> _getMessagingToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      final webVapidKey = dotenv.env['FIREBASE_WEB_VAPID_KEY'];
      final token = await messaging.getToken(vapidKey: kIsWeb ? webVapidKey : null);
      return token?.trim();
    } catch (e) {
      debugPrint('PushTargetRegistrationService: token fetch failed: $e');
      return null;
    }
  }

  Future<void> _upsertRemotePushTarget({
    required String userId,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final tokenKey = '$_kPushTokenKeyPrefix$userId';
    final previousToken = prefs.getString(tokenKey);
    if (previousToken == token) return;

    final targetIdKey = '$_kPushTargetIdKeyPrefix$userId';
    final savedTargetId = prefs.getString(targetIdKey);
    final providerId = dotenv.env['APPWRITE_PUSH_PROVIDER_ID']?.trim();

    try {
      if (savedTargetId != null && savedTargetId.isNotEmpty) {
        await appwriteAccount.updatePushTarget(
          targetId: savedTargetId,
          identifier: token,
        );
        await prefs.setString(tokenKey, token);
        return;
      }

      final created = await appwriteAccount.createPushTarget(
        targetId: ID.unique(),
        identifier: token,
        providerId: (providerId != null && providerId.isNotEmpty)
            ? providerId
            : null,
      );
      await prefs.setString(targetIdKey, created.$id);
      await prefs.setString(tokenKey, token);
    } on AppwriteException catch (e) {
      // If target id no longer exists or duplicate conditions occur, recreate target.
      if (e.code == 404 || e.code == 409 || e.type == 'document_not_found') {
        final created = await appwriteAccount.createPushTarget(
          targetId: ID.unique(),
          identifier: token,
          providerId: (providerId != null && providerId.isNotEmpty)
              ? providerId
              : null,
        );
        await prefs.setString(targetIdKey, created.$id);
        await prefs.setString(tokenKey, token);
        return;
      }
      debugPrint('PushTargetRegistrationService: Appwrite target upsert failed: ${e.message}');
    } catch (e) {
      debugPrint('PushTargetRegistrationService: target upsert failed: $e');
    }
  }
}
