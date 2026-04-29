import 'dart:async';

import 'package:WhatsUnity/core/config/appwrite.dart';
import 'package:WhatsUnity/core/di/app_services.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_state.dart';
import 'package:WhatsUnity/features/chat/data/datasources/chat_realtime_handle.dart';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'browser_notification_bridge.dart';

/// Lifecycle-aware message notification service.
///
/// - Foreground: suppresses local push (chat UI already updates in realtime).
/// - Background/inactive: shows a local notification for new remote messages.
/// - Web: uses browser Notifications API.
/// - Android/iOS: uses flutter_local_notifications.
///
/// Note: terminated-state delivery requires server push (Appwrite Messaging).
class MessageNotificationLifecycleService {
  MessageNotificationLifecycleService();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final List<ChatRealtimeHandle> _realtimeHandles = <ChatRealtimeHandle>[];

  AppLifecycleState _currentLifecycleState = AppLifecycleState.resumed;
  String? _activeUserId;
  String? _activeCompoundId;
  String? _activeBuildingName;
  bool _isInitialized = false;

  static const String _kMessageNotifySeenPrefix = 'message_notify_seen_v1_';
  static const String _kMessageNotifySeenIndexPrefix =
      'message_notify_seen_index_v1_';
  static const String _kNotificationPreferencePrefix =
      'notification_channel_enabled_v1_';
  static const int _kMaxStoredNotifiedMessageIds = 500;
  static const int _kGeneralChatNotificationId = 1101;
  static const int _kBuildingChatNotificationId = 1102;
  static const int _kAdminNotificationId = 1103;
  static const int _kMaintenanceNotificationId = 1104;

  static const String _kNotificationPrefsCollectionId = 'notification_preferences';

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (!kIsWeb) {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const settings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(settings);
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  void updateLifecycleState(AppLifecycleState state) {
    _currentLifecycleState = state;
  }

  Future<void> startForAuthState(Authenticated authState) async {
    await initialize();
    final userId = authState.user.id.trim();
    final compoundId = authState.selectedCompoundId?.trim();
    final buildingName = authState.currentUser?.building.trim();
    if (userId.isEmpty || compoundId == null || compoundId.isEmpty) {
      stop();
      return;
    }

    final contextChanged =
        userId != _activeUserId ||
        compoundId != _activeCompoundId ||
        buildingName != _activeBuildingName;
    if (!contextChanged) return;

    _activeUserId = userId;
    _activeCompoundId = compoundId;
    _activeBuildingName = buildingName;

    _unsubscribeAllChannels();
    final trackedChannels = await _resolveTrackedChannels(
      compoundId: compoundId,
      buildingName: buildingName,
    );

    for (final trackedChannel in trackedChannels) {
      final handle = AppServices.chatRepository.subscribeToChannel(
        channelId: trackedChannel.channelId,
        onInsert: (message) {
          _handleIncomingMessage(
            trackedChannel: trackedChannel,
            message: message,
            currentUserId: userId,
          );
        },
        onUpdate: (_) {},
      );
      _realtimeHandles.add(handle);
    }
  }

  void stop() {
    _activeUserId = null;
    _activeCompoundId = null;
    _activeBuildingName = null;
    _unsubscribeAllChannels();
  }

  Future<void> _handleIncomingMessage({
    required _TrackedNotificationChannel trackedChannel,
    required types.Message message,
    required String currentUserId,
  }) async {
    final authorId = message.authorId.toString().trim();
    if (authorId.isEmpty || authorId == currentUserId) return;
    if (_currentLifecycleState == AppLifecycleState.resumed) return;

    // Check user preference for this specific notification channel.
    // This is honored on ALL platforms (including Web).
    final isChannelEnabled = await fetchIsNotificationChannelEnabled(
      userId: currentUserId,
      notificationPreferenceChannel:
          trackedChannel.notificationPreferenceChannel,
    );
    if (!isChannelEnabled) return;

    final messageId = message.id.toString();
    if (messageId.isEmpty) return;
    if (await _hasMessageAlreadyNotified(
      userId: currentUserId,
      messageId: messageId,
    )) {
      return;
    }

    final messageText = _resolveNotificationBody(message);
    final body = messageText.isEmpty ? 'You have a new message' : messageText;
    final title = trackedChannel.title;

    // Web/PWA: Avoid showing a "local" browser notification via Realtime while 
    // in background/inactive state. The Service Worker (FCM) already handles 
    // these states, and showing both results in duplication.
    if (kIsWeb) return;

    final id = _resolveChannelNotificationId(
      trackedChannel.notificationChannelType,
    );
    final details = NotificationDetails(
      android: _resolveAndroidNotificationDetails(
        notificationChannelType: trackedChannel.notificationChannelType,
        body: body,
      ),
    );
    await _localNotifications.show(id, title, body, details);

    await _markMessageNotified(userId: currentUserId, messageId: messageId);
  }

  /// Returns whether notifications are enabled for a specific channel type.
  Future<bool> fetchIsNotificationChannelEnabled({
    required String userId,
    required NotificationPreferenceChannel notificationPreferenceChannel,
  }) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) return true;
    final prefs = await SharedPreferences.getInstance();
    final preferenceKey = _buildNotificationPreferenceKey(
      userId: trimmedUserId,
      notificationPreferenceChannel: notificationPreferenceChannel,
    );
    return prefs.getBool(preferenceKey) ?? true;
  }

  /// Persists channel notification preference for the current user.
  Future<void> updateNotificationChannelEnabled({
    required String userId,
    required NotificationPreferenceChannel notificationPreferenceChannel,
    required bool isEnabled,
  }) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final preferenceKey = _buildNotificationPreferenceKey(
      userId: trimmedUserId,
      notificationPreferenceChannel: notificationPreferenceChannel,
    );
    await prefs.setBool(preferenceKey, isEnabled);

    // Sync to Appwrite so server-side push (FCM) honors the preference.
    unawaited(_syncRemoteNotificationPreferences(trimmedUserId));
  }

  /// Pushes all local notification toggles to the Appwrite `notification_preferences`
  /// collection so Cloud Functions can honor them in terminated states.
  Future<void> _syncRemoteNotificationPreferences(String userId) async {
    try {
      final general = await fetchIsNotificationChannelEnabled(
        userId: userId,
        notificationPreferenceChannel: NotificationPreferenceChannel.generalChat,
      );
      final building = await fetchIsNotificationChannelEnabled(
        userId: userId,
        notificationPreferenceChannel: NotificationPreferenceChannel.buildingChat,
      );
      final admin = await fetchIsNotificationChannelEnabled(
        userId: userId,
        notificationPreferenceChannel: NotificationPreferenceChannel.adminNotification,
      );
      final maintenance = await fetchIsNotificationChannelEnabled(
        userId: userId,
        notificationPreferenceChannel: NotificationPreferenceChannel.maintenanceNotification,
      );

      final data = {
        'profile': userId,
        'user_id': userId,
        'general_chat_enabled': general,
        'building_chat_enabled': building,
        'admin_notifications_enabled': admin,
        'maintenance_notifications_enabled': maintenance,
        'version': 0, // Server sync / LWW
      };

      try {
        await appwriteTables.updateRow(
          databaseId: appwriteDatabaseId,
          tableId: _kNotificationPrefsCollectionId,
          rowId: userId,
          data: data,
        );
      } on AppwriteException catch (e) {
        if (e.code == 404 || e.type == 'document_not_found') {
          await appwriteTables.createRow(
            databaseId: appwriteDatabaseId,
            tableId: _kNotificationPrefsCollectionId,
            rowId: userId,
            data: data,
          );
        } else {
          rethrow;
        }
      }
    } catch (e, st) {
      debugPrint('Failed to sync notification preferences to server: $e\n$st');
    }
  }

  String _resolveNotificationBody(types.Message message) {
    if (message is types.TextMessage) {
      return message.text.trim();
    }
    if (message is types.ImageMessage) {
      return 'sent a photo';
    }
    if (message is types.FileMessage) {
      return 'sent a file';
    }
    if (message is types.AudioMessage) {
      return 'sent a voice note';
    }
    return 'You have a new message';
  }

  Future<List<_TrackedNotificationChannel>> _resolveTrackedChannels({
    required String compoundId,
    required String? buildingName,
  }) async {
    final channels = <_TrackedNotificationChannel>[];
    final generalChannelId = await AppServices.chatRepository
        .resolveChannelDocumentId(
          compoundId: compoundId,
          channelType: 'COMPOUND_GENERAL',
          buildingNameForScopedChat: null,
        );
    if (generalChannelId != null && generalChannelId.isNotEmpty) {
      channels.add(
        _TrackedNotificationChannel(
          channelId: generalChannelId,
          title: 'General chat',
          notificationChannelType: _NotificationChannelType.generalChat,
          notificationPreferenceChannel:
              NotificationPreferenceChannel.generalChat,
        ),
      );
    }

    final trimmedBuildingName = buildingName?.trim();
    if (trimmedBuildingName != null && trimmedBuildingName.isNotEmpty) {
      final buildingChannelId = await AppServices.chatRepository
          .resolveChannelDocumentId(
            compoundId: compoundId,
            channelType: 'BUILDING_CHAT',
            buildingNameForScopedChat: trimmedBuildingName,
          );
      if (buildingChannelId != null && buildingChannelId.isNotEmpty) {
        channels.add(
          _TrackedNotificationChannel(
            channelId: buildingChannelId,
            title: 'Building chat',
            notificationChannelType: _NotificationChannelType.buildingChat,
            notificationPreferenceChannel:
                NotificationPreferenceChannel.buildingChat,
          ),
        );
      }
    }

    final adminChannelId = await AppServices.chatRepository
        .resolveChannelDocumentId(
          compoundId: compoundId,
          channelType: 'ADMIN_NOTIFICATION',
          buildingNameForScopedChat: null,
        );
    if (adminChannelId != null && adminChannelId.isNotEmpty) {
      channels.add(
        _TrackedNotificationChannel(
          channelId: adminChannelId,
          title: 'Admin notification',
          notificationChannelType: _NotificationChannelType.adminNotification,
          notificationPreferenceChannel:
              NotificationPreferenceChannel.adminNotification,
        ),
      );
    }

    final maintenanceChannelId = await AppServices.chatRepository
        .resolveChannelDocumentId(
          compoundId: compoundId,
          channelType: 'MAINTENANCE_NOTIFICATION',
          buildingNameForScopedChat: null,
        );
    if (maintenanceChannelId != null && maintenanceChannelId.isNotEmpty) {
      channels.add(
        _TrackedNotificationChannel(
          channelId: maintenanceChannelId,
          title: 'Maintenance notification',
          notificationChannelType:
              _NotificationChannelType.maintenanceNotification,
          notificationPreferenceChannel:
              NotificationPreferenceChannel.maintenanceNotification,
        ),
      );
    }
    return channels;
  }

  int _resolveChannelNotificationId(
    _NotificationChannelType notificationChannelType,
  ) {
    switch (notificationChannelType) {
      case _NotificationChannelType.generalChat:
        return _kGeneralChatNotificationId;
      case _NotificationChannelType.buildingChat:
        return _kBuildingChatNotificationId;
      case _NotificationChannelType.adminNotification:
        return _kAdminNotificationId;
      case _NotificationChannelType.maintenanceNotification:
        return _kMaintenanceNotificationId;
    }
  }

  AndroidNotificationDetails _resolveAndroidNotificationDetails({
    required _NotificationChannelType notificationChannelType,
    required String body,
  }) {
    final (
      channelId,
      channelName,
      channelDescription,
    ) = switch (notificationChannelType) {
      _NotificationChannelType.generalChat => (
        'general_chat_notifications',
        'GeneralChat',
        'General chat message notifications',
      ),
      _NotificationChannelType.buildingChat => (
        'building_chat_notifications',
        'BuildingChat',
        'Building chat message notifications',
      ),
      _NotificationChannelType.adminNotification => (
        'admin_notifications',
        'Admin',
        'Admin notification messages',
      ),
      _NotificationChannelType.maintenanceNotification => (
        'maintenance_notifications',
        'Maintenance',
        'Maintenance notification messages',
      ),
    };

    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(body),
      groupAlertBehavior: GroupAlertBehavior.all,
      setAsGroupSummary: false,
    );
  }

  Future<bool> _hasMessageAlreadyNotified({
    required String userId,
    required String messageId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_kMessageNotifySeenPrefix${userId}_$messageId') ??
        false;
  }

  Future<void> _markMessageNotified({
    required String userId,
    required String messageId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dedupeKey = '$_kMessageNotifySeenPrefix${userId}_$messageId';
    await prefs.setBool(dedupeKey, true);

    final indexKey = '$_kMessageNotifySeenIndexPrefix$userId';
    final current = prefs.getStringList(indexKey) ?? <String>[];
    if (!current.contains(messageId)) {
      current.add(messageId);
    }

    if (current.length > _kMaxStoredNotifiedMessageIds) {
      final toRemoveCount = current.length - _kMaxStoredNotifiedMessageIds;
      final staleIds = current.take(toRemoveCount).toList();
      for (final staleId in staleIds) {
        await prefs.remove('$_kMessageNotifySeenPrefix${userId}_$staleId');
      }
      current.removeRange(0, toRemoveCount);
    }

    await prefs.setStringList(indexKey, current);
  }

  void _unsubscribeAllChannels() {
    for (final handle in _realtimeHandles) {
      handle.unsubscribe();
    }
    _realtimeHandles.clear();
  }

  String _buildNotificationPreferenceKey({
    required String userId,
    required NotificationPreferenceChannel notificationPreferenceChannel,
  }) {
    final channelSegment = switch (notificationPreferenceChannel) {
      NotificationPreferenceChannel.generalChat => 'general_chat',
      NotificationPreferenceChannel.buildingChat => 'building_chat',
      NotificationPreferenceChannel.adminNotification => 'admin_notification',
      NotificationPreferenceChannel.maintenanceNotification =>
        'maintenance_notification',
    };
    return '$_kNotificationPreferencePrefix${userId}_$channelSegment';
  }
}

class _TrackedNotificationChannel {
  final String channelId;
  final String title;
  final _NotificationChannelType notificationChannelType;
  final NotificationPreferenceChannel notificationPreferenceChannel;

  const _TrackedNotificationChannel({
    required this.channelId,
    required this.title,
    required this.notificationChannelType,
    required this.notificationPreferenceChannel,
  });
}

enum _NotificationChannelType {
  generalChat,
  buildingChat,
  adminNotification,
  maintenanceNotification,
}

enum NotificationPreferenceChannel {
  generalChat,
  buildingChat,
  adminNotification,
  maintenanceNotification,
}
