// ─────────────────────────────────────────────
// WORKER / AUTH
// ─────────────────────────────────────────────
class Worker {
  final String id;
  final String name;
  final String phone;
  final String platform;     // Zomato | Swiggy | Amazon Flex | Zepto
  final String city;
  final String zone;
  final bool kycComplete;
  final bool subscribed;
  final String upiId;
  final double weeklyEarningsAvg; // 12-week trailing avg
  final int riskScore;            // 0-100
  final double weeklyPremium;
  final String planTier;          // basic | standard | premium
  final String? token;

  Worker({
    required this.id,
    required this.name,
    required this.phone,
    required this.platform,
    required this.city,
    required this.zone,
    required this.kycComplete,
    required this.subscribed,
    required this.upiId,
    required this.weeklyEarningsAvg,
    required this.riskScore,
    required this.weeklyPremium,
    required this.planTier,
    this.token,
  });

  factory Worker.fromJson(Map<String, dynamic> j) => Worker(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    phone: j['phone'] ?? '',
    platform: j['platform'] ?? '',
    city: j['city'] ?? '',
    zone: j['zone'] ?? '',
    kycComplete: j['kycComplete'] ?? false,
    subscribed: j['subscribed'] ?? false,
    upiId: j['upiId'] ?? '',
    weeklyEarningsAvg: (j['weeklyEarningsAvg'] ?? 0).toDouble(),
    riskScore: j['riskScore'] ?? 0,
    weeklyPremium: (j['weeklyPremium'] ?? 0).toDouble(),
    planTier: j['planTier'] ?? 'standard',
    token: j['token'],
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'phone': phone, 'platform': platform,
    'city': city, 'zone': zone, 'kycComplete': kycComplete,
    'subscribed': subscribed, 'upiId': upiId,
    'weeklyEarningsAvg': weeklyEarningsAvg, 'riskScore': riskScore,
    'weeklyPremium': weeklyPremium, 'planTier': planTier,
  };
}

// ─────────────────────────────────────────────
// WEATHER / TRIGGER
// ─────────────────────────────────────────────
class WeatherData {
  final double tempC;
  final double rainfallMm3h;
  final double windKmh;
  final int aqi;
  final String description;
  final String city;
  final DateTime fetchedAt;

  WeatherData({
    required this.tempC,
    required this.rainfallMm3h,
    required this.windKmh,
    required this.aqi,
    required this.description,
    required this.city,
    required this.fetchedAt,
  });

  factory WeatherData.fromJson(Map<String, dynamic> j) => WeatherData(
    tempC: (j['tempC'] ?? 0).toDouble(),
    rainfallMm3h: (j['rainfallMm3h'] ?? 0).toDouble(),
    windKmh: (j['windKmh'] ?? 0).toDouble(),
    aqi: j['aqi'] ?? 0,
    description: j['description'] ?? '',
    city: j['city'] ?? '',
    fetchedAt: DateTime.tryParse(j['fetchedAt'] ?? '') ?? DateTime.now(),
  );
}

// ─────────────────────────────────────────────
// TRIGGER / DISRUPTION
// ─────────────────────────────────────────────
enum TriggerType { heavyRainfall, severeFLooding, extremeHeat, cyclone, hazardousAqi, curfew, transportStrike, zoneSuspension }

class DisruptionAlert {
  final String id;
  final TriggerType type;
  final String zone;
  final String city;
  final DateTime detectedAt;
  final double severity;       // 0-1
  final double payoutPct;      // e.g. 0.80
  final bool gate1Pass;
  final bool gate2Pass;
  final String description;
  final String status;         // active | resolved | processing

  DisruptionAlert({
    required this.id,
    required this.type,
    required this.zone,
    required this.city,
    required this.detectedAt,
    required this.severity,
    required this.payoutPct,
    required this.gate1Pass,
    required this.gate2Pass,
    required this.description,
    required this.status,
  });

  factory DisruptionAlert.fromJson(Map<String, dynamic> j) => DisruptionAlert(
    id: j['id'] ?? '',
    type: TriggerType.values.firstWhere(
      (e) => e.name == j['type'], orElse: () => TriggerType.heavyRainfall),
    zone: j['zone'] ?? '',
    city: j['city'] ?? '',
    detectedAt: DateTime.tryParse(j['detectedAt'] ?? '') ?? DateTime.now(),
    severity: (j['severity'] ?? 0).toDouble(),
    payoutPct: (j['payoutPct'] ?? 0).toDouble(),
    gate1Pass: j['gate1Pass'] ?? false,
    gate2Pass: j['gate2Pass'] ?? false,
    description: j['description'] ?? '',
    status: j['status'] ?? 'active',
  );

  String get typeLabel {
    switch (type) {
      case TriggerType.heavyRainfall: return 'Heavy Rainfall';
      case TriggerType.severeFLooding: return 'Severe Flooding';
      case TriggerType.extremeHeat: return 'Extreme Heat';
      case TriggerType.cyclone: return 'Cyclone / Storm';
      case TriggerType.hazardousAqi: return 'Hazardous AQI';
      case TriggerType.curfew: return 'Curfew / Section 144';
      case TriggerType.transportStrike: return 'Transport Strike';
      case TriggerType.zoneSuspension: return 'Zone Suspension';
    }
  }
}

// ─────────────────────────────────────────────
// CLAIM
// ─────────────────────────────────────────────
enum ClaimStatus { pending, fraudCheck, approved, held, blocked, paid }

class Claim {
  final String id;
  final String workerId;
  final String alertId;
  final ClaimStatus status;
  final double amount;
  final double fraudScore;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String triggerType;
  final String zone;
  final String? reviewNote;

  Claim({
    required this.id,
    required this.workerId,
    required this.alertId,
    required this.status,
    required this.amount,
    required this.fraudScore,
    required this.createdAt,
    this.resolvedAt,
    required this.triggerType,
    required this.zone,
    this.reviewNote,
  });

  factory Claim.fromJson(Map<String, dynamic> j) => Claim(
    id: j['id'] ?? '',
    workerId: j['workerId'] ?? '',
    alertId: j['alertId'] ?? '',
    status: ClaimStatus.values.firstWhere(
      (e) => e.name == j['status'], orElse: () => ClaimStatus.pending),
    amount: (j['amount'] ?? 0).toDouble(),
    fraudScore: (j['fraudScore'] ?? 0).toDouble(),
    createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
    resolvedAt: j['resolvedAt'] != null ? DateTime.tryParse(j['resolvedAt']) : null,
    triggerType: j['triggerType'] ?? '',
    zone: j['zone'] ?? '',
    reviewNote: j['reviewNote'],
  );

  String get statusLabel {
    switch (status) {
      case ClaimStatus.pending: return 'Processing';
      case ClaimStatus.fraudCheck: return 'Under Review';
      case ClaimStatus.approved: return 'Approved';
      case ClaimStatus.held: return 'On Hold';
      case ClaimStatus.blocked: return 'Blocked';
      case ClaimStatus.paid: return 'Paid';
    }
  }
}

// ─────────────────────────────────────────────
// RISK SCORE RESULT
// ─────────────────────────────────────────────
class RiskResult {
  final int score;         // 0-100
  final double multiplier; // 1.0 - 1.4
  final double weeklyPremium;
  final double dailyCoverage;
  final double maxWeekly;
  final Map<String, double> breakdown; // condition -> weight contribution
  final String band;       // low | medium | high | extreme

  RiskResult({
    required this.score,
    required this.multiplier,
    required this.weeklyPremium,
    required this.dailyCoverage,
    required this.maxWeekly,
    required this.breakdown,
    required this.band,
  });

  factory RiskResult.fromJson(Map<String, dynamic> j) => RiskResult(
    score: j['score'] ?? 0,
    multiplier: (j['multiplier'] ?? 1.0).toDouble(),
    weeklyPremium: (j['weeklyPremium'] ?? 0).toDouble(),
    dailyCoverage: (j['dailyCoverage'] ?? 0).toDouble(),
    maxWeekly: (j['maxWeekly'] ?? 0).toDouble(),
    breakdown: Map<String, double>.from(
      (j['breakdown'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble()))),
    band: j['band'] ?? 'medium',
  );
}

// ─────────────────────────────────────────────
// LOCATION VERIFICATION
// ─────────────────────────────────────────────
class LocationVerification {
  final bool gpsMatch;
  final bool imageMatch;
  final bool towerMatch;
  final double fraudScore;
  final String verdict; // approved | held | blocked

  LocationVerification({
    required this.gpsMatch,
    required this.imageMatch,
    required this.towerMatch,
    required this.fraudScore,
    required this.verdict,
  });

  factory LocationVerification.fromJson(Map<String, dynamic> j) => LocationVerification(
    gpsMatch: j['gpsMatch'] ?? false,
    imageMatch: j['imageMatch'] ?? false,
    towerMatch: j['towerMatch'] ?? false,
    fraudScore: (j['fraudScore'] ?? 0).toDouble(),
    verdict: j['verdict'] ?? 'held',
  );
}
