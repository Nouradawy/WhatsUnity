import 'dart:html' as html;

import 'browser_notification_bridge.dart';

class _WebBrowserNotificationBridge implements BrowserNotificationBridge {
  @override
  Future<void> requestPermissionIfNeeded() async {
    if (!html.Notification.supported) return;
    if (html.Notification.permission == 'default') {
      await html.Notification.requestPermission();
    }
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    String? tag,
  }) async {
    if (!html.Notification.supported) return;
    if (html.Notification.permission != 'granted') return;
    html.Notification(
      title,
      body: body,
      tag: tag,
    );
  }
}

BrowserNotificationBridge createBrowserNotificationBridgeImpl() =>
    _WebBrowserNotificationBridge();
