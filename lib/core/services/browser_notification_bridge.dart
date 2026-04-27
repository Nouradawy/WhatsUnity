import 'browser_notification_bridge_stub.dart'
    if (dart.library.html) 'browser_notification_bridge_web.dart';

abstract class BrowserNotificationBridge {
  Future<void> requestPermissionIfNeeded();
  Future<void> show({
    required String title,
    required String body,
    String? tag,
  });
}

BrowserNotificationBridge createBrowserNotificationBridge() =>
    createBrowserNotificationBridgeImpl();
