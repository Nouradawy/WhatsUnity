import 'browser_notification_bridge.dart';

class _NoopBrowserNotificationBridge implements BrowserNotificationBridge {


  @override
  Future<bool> requestPermissionIfNeeded() async => false;


  @override
  String getPermissionStatus() => 'unsupported';

  @override
  bool isAppleWeb() => false;

  @override
  bool isStandalone() => false;



  @override
  Future<void> show({
    required String title,
    required String body,
    String? tag,
  }) async {}
}

BrowserNotificationBridge createBrowserNotificationBridgeImpl() =>
    _NoopBrowserNotificationBridge();
