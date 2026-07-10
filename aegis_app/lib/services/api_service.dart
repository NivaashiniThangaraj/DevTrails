import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import '../services/risk_engine.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// DEMO / OFFLINE MODE
///
/// Every method below returns hardcoded sample data so the app works
/// end-to-end with NO backend. Replace these bodies with real HTTP calls
/// (and set the base URL) to go live. The public method signatures are
/// identical to a networked client, so the UI/provider layer is untouched.
/// ─────────────────────────────────────────────────────────────────────────
class ApiService {
  static const _demoOtp = '123456';
  static const _storage = FlutterSecureStorage();

  // In-memory session (lost on reload; getProfile falls back to a demo worker).
  static Worker? _currentWorker;

  static Future<String?> _storedToken() async =>
      _storage.read(key: 'jwt_token');

  static Future<bool> hasToken() async {
    final t = await _storedToken();
    return t != null && t.isNotEmpty;
  }

  // Simulated network latency so the UI shows realistic loading states.
  static Future<void> _demoDelay() =>
      Future.delayed(const Duration(milliseconds: 400));

  static Worker _defaultWorker() => Worker(
        id: 'worker_demo_001',
        name: 'Demo Rider',
        phone: '+919999999999',
        platform: 'Swiggy',
        city: 'Chennai',
        zone: 'Zone 4 — Central',
        kycComplete: false,
        subscribed: false,
        upiId: 'demo@oksbi',
        weeklyEarningsAvg: 3200,
        riskScore: 0,
        weeklyPremium: 0,
        planTier: 'standard',
        token: 'demo-jwt-token',
      );

  // ── AUTH ──────────────────────────────────────────────────────────────
  static Future<String> requestOtp(String phone) async {
    await _demoDelay();
    return _demoOtp; // demo OTP — shown in the UI for convenience
  }

  static Future<Worker> verifyOtp(String phone, String otp) async {
    await _demoDelay();
    final w = _defaultWorker().copyWith(phone: phone, token: 'demo-jwt-token');
    _currentWorker = w;
    await _storage.write(key: 'jwt_token', value: w.token!);
    return w;
  }

  static Future<Worker> register({
    required String name,
    required String phone,
    required String platform,
    required String city,
    required String zone,
    required String upiId,
  }) async {
    await _demoDelay();
    final w = Worker(
      id: 'worker_demo_001',
      name: name,
      phone: phone,
      platform: platform,
      city: city,
      zone: zone,
      kycComplete: false,
      subscribed: false,
      upiId: upiId,
      weeklyEarningsAvg: 3200,
      riskScore: 0,
      weeklyPremium: 0,
      planTier: 'standard',
      token: 'demo-jwt-token',
    );
    _currentWorker = w;
    await _storage.write(key: 'jwt_token', value: w.token!);
    return w;
  }

  static Future<void> logout() async => _storage.delete(key: 'jwt_token');

  // ── WORKER ────────────────────────────────────────────────────────────
  static Future<Worker> getProfile() async {
    await _demoDelay();
    return _currentWorker ?? _defaultWorker();
  }

  static Future<Worker> completeKyc({
    required String aadhaarNumber,
    required String workerId,
  }) async {
    await _demoDelay();
    final base = _currentWorker ?? _defaultWorker();
    final updated = base.copyWith(kycComplete: true);
    _currentWorker = updated;
    return updated;
  }

  // ── RISK ──────────────────────────────────────────────────────────────
  static Future<RiskResult> computeRiskScore({
    required String city,
    required String zone,
    required double weeklyEarningsAvg,
    required double rainfallMm,
    required double tempC,
    required int aqi,
    required bool monsoonSeason,
  }) async {
    await _demoDelay();
    // Demo order/earnings drops so the engine produces a realistic score.
    return RiskEngine.compute(
      zone: zone,
      weeklyEarningsAvg: weeklyEarningsAvg,
      rainfallMm: rainfallMm,
      tempC: tempC,
      aqi: aqi,
      orderDropPct: 0.35,
      earningsDropPct: 0.25,
      hasClaimsLast12Weeks: false,
      monsoonSeason: monsoonSeason,
    );
  }

  // ── SUBSCRIPTION ──────────────────────────────────────────────────────
  static Future<Worker> subscribe({
    required String planTier,
    required double weeklyPremium,
  }) async {
    await _demoDelay();
    final base = _currentWorker ?? _defaultWorker();
    final updated = base.copyWith(
      subscribed: true,
      planTier: planTier,
      weeklyPremium: weeklyPremium,
    );
    _currentWorker = updated;
    return updated;
  }

  // ── ALERTS ────────────────────────────────────────────────────────────
  static Future<List<DisruptionAlert>> getAlerts(String zone) async {
    await _demoDelay();
    final now = DateTime.now();
    return [
      DisruptionAlert(
        id: 'alert_001',
        type: TriggerType.heavyRainfall,
        zone: zone,
        city: 'Chennai',
        detectedAt: now.subtract(const Duration(hours: 2)),
        severity: 0.72,
        payoutPct: 0.80,
        gate1Pass: true,
        gate2Pass: true,
        description: 'Heavy rainfall detected in your zone. Payout trigger armed.',
        status: 'active',
      ),
      DisruptionAlert(
        id: 'alert_002',
        type: TriggerType.extremeHeat,
        zone: zone,
        city: 'Chennai',
        detectedAt: now.subtract(const Duration(hours: 5)),
        severity: 0.51,
        payoutPct: 0.60,
        gate1Pass: true,
        gate2Pass: false,
        description: 'Extreme heat alert. Monitoring order-drop gate.',
        status: 'active',
      ),
    ];
  }

  // ── CLAIMS ────────────────────────────────────────────────────────────
  static Future<List<Claim>> getClaims() async {
    await _demoDelay();
    final now = DateTime.now();
    final wid = _currentWorker?.id ?? 'worker_demo_001';
    final wzone = _currentWorker?.zone ?? 'Zone 4 — Central';
    return [
      Claim(
        id: 'claim_001',
        workerId: wid,
        alertId: 'alert_001',
        status: ClaimStatus.paid,
        amount: 640,
        fraudScore: 0.05,
        createdAt: now.subtract(const Duration(days: 2)),
        resolvedAt: now.subtract(const Duration(days: 2, minutes: 30)),
        triggerType: 'Heavy Rainfall',
        zone: wzone,
      ),
      Claim(
        id: 'claim_002',
        workerId: wid,
        alertId: 'alert_002',
        status: ClaimStatus.pending,
        amount: 420,
        fraudScore: 0.12,
        createdAt: now.subtract(const Duration(hours: 6)),
        triggerType: 'Extreme Heat',
        zone: wzone,
      ),
    ];
  }

  static Future<Claim> submitClaim({
    required String alertId,
    required double lat,
    required double lng,
    required String imageBase64,
    required String deviceId,
  }) async {
    await _demoDelay();
    return Claim(
      id: 'claim_${DateTime.now().millisecondsSinceEpoch}',
      workerId: _currentWorker?.id ?? 'worker_demo_001',
      alertId: alertId,
      status: ClaimStatus.held,
      amount: 520,
      fraudScore: 0.20,
      createdAt: DateTime.now(),
      triggerType: 'Heavy Rainfall',
      zone: _currentWorker?.zone ?? 'Zone 4 — Central',
      reviewNote: 'Under review (demo)',
    );
  }

  // ── WEATHER (demo, no OpenWeatherMap key needed) ──────────────────────
  static Future<WeatherData> fetchWeather(String city) async {
    await _demoDelay();
    return WeatherData(
      tempC: 32.5,
      rainfallMm3h: 0,
      windKmh: 12,
      aqi: 80,
      description: 'Partly cloudy (demo data)',
      city: city,
      fetchedAt: DateTime.now(),
    );
  }

  static Future<int> fetchAqi(double lat, double lng) async {
    await _demoDelay();
    return 80;
  }
}

extension _WorkerCopy on Worker {
  Worker copyWith({
    String? name,
    String? phone,
    String? platform,
    String? city,
    String? zone,
    bool? kycComplete,
    bool? subscribed,
    String? upiId,
    double? weeklyEarningsAvg,
    int? riskScore,
    double? weeklyPremium,
    String? planTier,
    String? token,
  }) =>
      Worker(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        platform: platform ?? this.platform,
        city: city ?? this.city,
        zone: zone ?? this.zone,
        kycComplete: kycComplete ?? this.kycComplete,
        subscribed: subscribed ?? this.subscribed,
        upiId: upiId ?? this.upiId,
        weeklyEarningsAvg: weeklyEarningsAvg ?? this.weeklyEarningsAvg,
        riskScore: riskScore ?? this.riskScore,
        weeklyPremium: weeklyPremium ?? this.weeklyPremium,
        planTier: planTier ?? this.planTier,
        token: token ?? this.token,
      );
}
