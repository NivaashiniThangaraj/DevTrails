// Platform-aware notification service.
// On native (Android/iOS/desktop) this uses flutter_local_notifications.
// On the web it is a no-op because the browser has no native notification API.
export 'notification_service_io.dart' if (dart.library.html) 'notification_service_web.dart';
