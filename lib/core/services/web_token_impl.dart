import 'dart:js_interop';

@JS('getWhatsUnityFCMToken')
external JSPromise<JSString?> _jsGetFCMToken(JSString vapidKey);

Future<String?> getWebTokenViaJS(String vapidKey) async {
  final tokenJS = await _jsGetFCMToken(vapidKey.toJS).toDart;
  return tokenJS?.toDart;
}