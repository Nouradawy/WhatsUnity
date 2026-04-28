import 'dart:html' as html;

import 'browser_notification_bridge.dart';

class _WebBrowserNotificationBridge implements BrowserNotificationBridge {
  @override
  Future<bool> requestPermissionIfNeeded() async {
    if (!html.Notification.supported) return false;
    if (html.Notification.permission == 'default') {
      final status = await html.Notification.requestPermission();
      return status == 'granted';
    }
    return html.Notification.permission == 'granted';
  }

  @override
  String getPermissionStatus() {
    if (!html.Notification.supported) return 'unsupported';
    return html.Notification.permission ?? 'unsupported';
  }

  @override
  bool isStandalone() {
    return html.window.matchMedia('(display-mode: standalone)').matches == true;
  }

  @override
  bool isAppleWeb() {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    final isMobileApple = userAgent.contains('iphone') ||
        userAgent.contains('ipad') ||
        userAgent.contains('ipod');
    // iPad Safari in "Desktop" mode reports as Macintosh but has touch support
    final isMacTouch =
        userAgent.contains('macintosh') && html.window.navigator.maxTouchPoints! > 1;
    return isMobileApple || isMacTouch;
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
