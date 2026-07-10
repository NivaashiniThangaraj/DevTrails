/// ─────────────────────────────────────────────────────────────────────────
/// DEMO / OFFLINE MODE
///
/// Returns canned, helpful replies so the in-app Aegis AI assistant works
/// with no backend. Replace with a real LLM/backend call to go live.
/// ─────────────────────────────────────────────────────────────────────────
class ChatService {
  static Future<String> generateResponse(String userInput) async {
    // Simulate a little thinking time for a natural feel.
    await Future.delayed(const Duration(milliseconds: 500));

    final q = userInput.toLowerCase();

    if (q.contains('hello') || q.contains('hi') || q.contains('hey')) {
      return "Hi! I'm Aegis AI 🤖 Ask me about insurance, claims, coverage, or how the app works!";
    }
    if (q.contains('claim')) {
      return "You can file a claim from the Alerts tab when a disruption is active. "
          "In this demo, claims are pre-filled with sample data so you can see the full flow. 📝";
    }
    if (q.contains('plan') || q.contains('premium')) {
      return "We offer Basic, Standard and Premium plans. Your premium is computed from your "
          "zone risk and average earnings — pick one on the Plans screen. 💡";
    }
    if (q.contains('payout')) {
      return "Payouts trigger automatically once both risk gates pass. Demo payouts show up as "
          "\"Paid\" in your Claims tab. 💸";
    }
    if (q.contains('weather') || q.contains('rain') || q.contains('heat')) {
      return "Weather drives your risk score. Heavy rain, extreme heat and hazardous AQI all "
          "raise your score — and your payout potential. 🌦️";
    }
    if (q.contains('kyc') || q.contains('aadhaar')) {
      return "KYC verifies your identity with your Aadhaar number. It's a one-time step and "
          "unlocks subscriptions. ✅";
    }
    return "I'm your Aegis assistant 🤖 In this demo everything runs offline with sample data. "
        "Try asking about claims, plans, payouts, or weather!";
  }
}
