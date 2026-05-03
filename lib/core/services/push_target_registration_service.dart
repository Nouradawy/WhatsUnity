import 'dart:async';
import 'web_token_stub.dart' if (dart.library.js_interop) 'web_token_impl.dart';

import 'package:WhatsUnity/core/config/appwrite.dart';
import 'package:WhatsUnity/core/config/runtime_env.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_state.dart';
import 'package:WhatsUnity/core/utils/app_logger.dart';
import 'package:appwrite/appwrite.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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
    AppLogger.d("PushTargetRegistrationService: ensuring Firebase initialization...", tag: "push_target_registration");
    try {
      if (Firebase.apps.isNotEmpty) {
        AppLogger.d("PushTargetRegistrationService: Firebase already initialized.", tag: "push_target_registration");
        _firebaseReady = true;
        return;
      }

      if (kIsWeb) {
        final apiKey = RuntimeEnv.firebaseWebApiKey;
        final appId = RuntimeEnv.firebaseWebAppId;
        final projectId = RuntimeEnv.firebaseWebProjectId;
        final messagingSenderId = RuntimeEnv.firebaseWebMessagingSenderId;
        if ([apiKey, appId, projectId, messagingSenderId].any((v) => v == null || v.isEmpty)) {
          AppLogger.d(
            'PushTargetRegistrationService: missing web Firebase compile-time '
            'defines (FIREBASE_WEB_*). Run with --dart-define-from-file=.env, e.g. '
            'flutter run -d chrome --dart-define-from-file=.env. '
            'For the service worker, run: dart run tool/sync_firebase_web_push_env.dart',
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
            authDomain: RuntimeEnv.firebaseWebAuthDomain,
            storageBucket: RuntimeEnv.firebaseWebStorageBucket,
            measurementId: RuntimeEnv.firebaseWebMeasurementId,
          ),
        );
      } else {
        // On native platforms, we initialize in main.dart. 
        // If it was skipped or failed there, we try a fallback here with a timeout.
        AppLogger.d("PushTargetRegistrationService: performing fallback initialization for native...", tag: "push_target_registration");
        await Firebase.initializeApp().timeout(const Duration(seconds: 10));
      }
      AppLogger.d("PushTargetRegistrationService: Firebase initialization complete.", tag: "push_target_registration");
      _firebaseReady = true;
    } catch (e, st) {
      AppLogger.e("PushTargetRegistrationService: Firebase init failed or timed out",error: e, stackTrace: st);
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
        AppLogger.d("PushTargetRegistrationService: permission denied");
        return null;
      }
      final webVapidKey = RuntimeEnv.firebaseWebVapidKey;

      if (kIsWeb) {
        AppLogger.d("PushTargetRegistrationService: fetching web token via JS bridge with VAPID: ${webVapidKey != null ? 'present' : 'null'}");
        final token = await getWebTokenViaJS(webVapidKey ?? '');

        if (token == null || token.isEmpty) {
          AppLogger.d("PushTargetRegistrationService: JS bridge returned null or empty token");
        } else {
          AppLogger.d("PushTargetRegistrationService: web token fetched successfully via JS bridge");
        }
        return token;
      }

      final token = await messaging.getToken(vapidKey: null);
      if (token == null || token.isEmpty) {
        AppLogger.d("PushTargetRegistrationService: token is null or empty");
      }
      return token?.trim();
    } catch (e, st) {
      AppLogger.e("PushTargetRegistrationService: token fetch failed", error: e, stackTrace: st);
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
    final providerId = RuntimeEnv.appwritePushProviderId?.trim();

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
    } on AppwriteException catch (e,st) {
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
      AppLogger.e("PushTargetRegistrationService: Appwrite target upsert failed",error:  e,stackTrace: st);
    } catch (e, st) {
      AppLogger.e("PushTargetRegistrationService: target upsert failed",error:  e, stackTrace: st);
    }
  }
}
