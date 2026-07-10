import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Returns a best-effort stable device identifier.
///
/// On the web this is a fixed client tag (browsers do not expose a hardware
/// id). On native it uses the platform device-info plugins. No `dart:io`
/// reference is made so this compiles cleanly for the web target.
Future<String> getDeviceId() async {
  final info = DeviceInfoPlugin();

  if (kIsWeb) {
    try {
      return (await info.webBrowserInfo).vendor ?? 'web-client';
    } catch (_) {
      return 'web-client';
    }
  }

  // Native: try Android, then iOS, then fall back. The platform-specific
  // getters throw when called on the wrong OS, so we probe defensively.
  try {
    return (await info.androidInfo).id;
  } catch (_) {
    try {
      return (await info.iosInfo).identifierForVendor ?? 'ios-client';
    } catch (_) {
      return 'native-client';
    }
  }
}
