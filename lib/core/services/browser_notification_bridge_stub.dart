import 'browser_notification_bridge.dart';

class _NoopBrowserNotificationBridge implements BrowserNotificationBridge {
  @override
  Future<void> requestPermissionIfNeeded() async {}

  @override
  Future<void> show({
    required String title,
    required String body,
    String? tag,
  }) async {}
}

BrowserNotificationBridge createBrowserNotificationBridgeImpl() =>
    _NoopBrowserNotificationBridge();
