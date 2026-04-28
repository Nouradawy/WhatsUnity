import 'browser_notification_bridge_stub.dart'
    if (dart.library.html) 'browser_notification_bridge_web.dart';

abstract class BrowserNotificationBridge {
  Future<bool> requestPermissionIfNeeded();
  String getPermissionStatus();
  bool isStandalone();
  bool isAppleWeb();
  Future<void> show({
    required String title,
    required String body,
    String? tag,
  });
}

BrowserNotificationBridge createBrowserNotificationBridge() =>
    createBrowserNotificationBridgeImpl();
