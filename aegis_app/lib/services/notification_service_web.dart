class NotificationService {
  static Future<void> init() async {}
  static Future<void> showDisruptionAlert({required String title, required String body}) async {}
  static Future<void> showPayoutNotification({required double amount, required String trigger}) async {}
  static Future<void> showClaimHeld(String reason) async {}
}
