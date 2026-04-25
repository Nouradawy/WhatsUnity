import 'package:ntp/ntp.dart';

/// NTP-adjusted time when the network allows; otherwise device UTC.
///
/// Raw [NTP.now] fails offline (DNS / UDP), which breaks offline-first send.
Future<DateTime> trustedUtcNow({
  Duration ntpTimeout = const Duration(seconds: 2),
}) async {
  try {
    return (await NTP.now(timeout: ntpTimeout)).toUtc();
  } catch (_) {
    return DateTime.now().toUtc();
  }
}
