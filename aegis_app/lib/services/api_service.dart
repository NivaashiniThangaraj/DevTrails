import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

class ApiService {
  // ── CONFIGURE THESE ───────────────────────────────────────────────────
  // For physical device on same WiFi as your PC:
  //   find your PC's IP with `ipconfig` (Windows), use that IP
  //   e.g.  http://192.168.1.5:3000
  // For Android emulator:  http://10.0.2.2:3000
  // For deployed backend:  https://your-backend.onrender.com
  static const _base = "https://aegis-backend-i4z5.onrender.com";

  // OpenWeatherMap free key — get one at openweathermap.org/api (30 seconds)
  // App works fine without it — shows demo weather data
  static const _owmKey = '01ac88a5e0346da8ff0a895919476c20';
  // ──────────────────────────────────────────────────────────────────────

  // Hard 5-second timeout on all backend calls
  static const _timeout = Duration(seconds: 35);
  static const _storage = FlutterSecureStorage();

  // ── TOKEN HELPERS ─────────────────────────────────────────────────────
  static Future<String?> _token() async =>
      _storage.read(key: 'jwt_token');

  /// True only when a JWT is already saved on this device.
  static Future<bool> hasToken() async {
    final t = await _storage.read(key: 'jwt_token');
    return t != null && t.isNotEmpty;
  }

  static Map<String, String> _headers([String? tok]) => {
    'Content-Type': 'application/json',
    if (tok != null) 'Authorization': 'Bearer $tok',
  };

  // ── AUTH ──────────────────────────────────────────────────────────────
  static Future<String> requestOtp(String phone) async {
    final res = await http
        .post(Uri.parse('$_base/auth/otp/request'),
            headers: _headers(),
            body: jsonEncode({'phone': phone}))
        .timeout(_timeout);
    _check(res);
    return jsonDecode(res.body)['otp']?.toString() ?? '';
  }

  static Future<Worker> verifyOtp(String phone, String otp) async {
    final res = await http
        .post(Uri.parse('$_base/auth/otp/verify'),
            headers: _headers(),
            body: jsonEncode({'phone': phone, 'otp': otp}))
        .timeout(_timeout);
    _check(res);
    final d = jsonDecode(res.body);
    await _storage.write(key: 'jwt_token', value: d['token']);
    return Worker.fromJson({...d['worker'], 'token': d['token']});
  }

  static Future<Worker> register({
    required String name, required String phone,
    required String platform, required String city,
    required String zone, required String upiId,
  }) async {
    final res = await http
        .post(Uri.parse('$_base/auth/register'),
            headers: _headers(),
            body: jsonEncode({'name': name, 'phone': phone,
              'platform': platform, 'city': city,
              'zone': zone, 'upiId': upiId}))
        .timeout(_timeout);
    _check(res);
    final d = jsonDecode(res.body);
    await _storage.write(key: 'jwt_token', value: d['token']);
    return Worker.fromJson({...d['worker'], 'token': d['token']});
  }

  static Future<void> logout() async => _storage.delete(key: 'jwt_token');

  // ── WORKER ────────────────────────────────────────────────────────────
  static Future<Worker> getProfile() async {
    final tok = await _token();
    final res = await http
        .get(Uri.parse('$_base/worker/profile'), headers: _headers(tok))
        .timeout(_timeout);
    _check(res);
    return Worker.fromJson(jsonDecode(res.body));
  }

  static Future<Worker> completeKyc({
    required String aadhaarNumber, required String workerId,
  }) async {
    final tok = await _token();
    final res = await http
        .post(Uri.parse('$_base/worker/kyc'),
            headers: _headers(tok),
            body: jsonEncode({'aadhaarNumber': aadhaarNumber, 'workerId': workerId}))
        .timeout(_timeout);
    _check(res);
    return Worker.fromJson(jsonDecode(res.body));
  }

  // ── RISK ──────────────────────────────────────────────────────────────
  static Future<RiskResult> computeRiskScore({
    required String city, required String zone,
    required double weeklyEarningsAvg,
    required double rainfallMm, required double tempC,
    required int aqi, required bool monsoonSeason,
  }) async {
    final tok = await _token();
    final res = await http
        .post(Uri.parse('$_base/risk/score'),
            headers: _headers(tok),
            body: jsonEncode({
              'city': city, 'zone': zone,
              'weeklyEarningsAvg': weeklyEarningsAvg,
              'rainfallMm': rainfallMm, 'tempC': tempC,
              'aqi': aqi, 'monsoonSeason': monsoonSeason,
            }))
        .timeout(_timeout);
    _check(res);
    return RiskResult.fromJson(jsonDecode(res.body));
  }

  // ── SUBSCRIPTION ──────────────────────────────────────────────────────
  static Future<Worker> subscribe({
    required String planTier, required double weeklyPremium,
  }) async {
    final tok = await _token();
    final res = await http
        .post(Uri.parse('$_base/subscription/activate'),
            headers: _headers(tok),
            body: jsonEncode({'planTier': planTier, 'weeklyPremium': weeklyPremium}))
        .timeout(_timeout);
    _check(res);
    return Worker.fromJson(jsonDecode(res.body));
  }

  // ── ALERTS ────────────────────────────────────────────────────────────
  static Future<List<DisruptionAlert>> getAlerts(String zone) async {
    final tok = await _token();
    final res = await http
        .get(Uri.parse('$_base/triggers/alerts?zone=${Uri.encodeComponent(zone)}'),
            headers: _headers(tok))
        .timeout(_timeout);
    _check(res);
    final List list = jsonDecode(res.body);
    return list.map((e) => DisruptionAlert.fromJson(e)).toList();
  }

  // ── CLAIMS ────────────────────────────────────────────────────────────
  static Future<List<Claim>> getClaims() async {
    final tok = await _token();
    final res = await http
        .get(Uri.parse('$_base/claims/my'), headers: _headers(tok))
        .timeout(_timeout);
    _check(res);
    final List list = jsonDecode(res.body);
    return list.map((e) => Claim.fromJson(e)).toList();
  }

  static Future<Claim> submitClaim({
    required String alertId, required double lat, required double lng,
    required String imageBase64, required String deviceId,
  }) async {
    final tok = await _token();
    final res = await http
        .post(Uri.parse('$_base/claims/submit'),
            headers: _headers(tok),
            body: jsonEncode({
              'alertId': alertId, 'gpsLat': lat, 'gpsLng': lng,
              'imageBase64': imageBase64, 'deviceId': deviceId,
            }))
        .timeout(const Duration(seconds: 30));
    _check(res);
    return Claim.fromJson(jsonDecode(res.body));
  }

  // ── WEATHER (direct OWM — no backend needed) ──────────────────────────
  static Future<WeatherData> fetchWeather(String city) async {
    // Return demo data instantly if no key configured
    if (_owmKey == 'YOUR_OWM_API_KEY' || _owmKey.isEmpty) {
      return WeatherData(
        tempC: 32.5, rainfallMm3h: 0, windKmh: 12, aqi: 80,
        description: 'clear sky (demo — add OWM key for live data)',
        city: city, fetchedAt: DateTime.now(),
      );
    }
    final res = await http
        .get(Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather'
          '?q=${Uri.encodeComponent(city)},IN&appid=$_owmKey&units=metric'))
        .timeout(_timeout);
    _check(res);
    final j = jsonDecode(res.body);
    double rain = 0;
    if (j['rain'] != null) rain = ((j['rain']['3h'] ?? j['rain']['1h'] ?? 0)).toDouble();
//     return WeatherData(
//   tempC: 45,           // extreme heat
//   rainfallMm3h: 80,    // heavy rain
//   windKmh: 50,
//   aqi: 350,            // dangerous AQI
//   description: 'EXTREME WEATHER (DEMO)',
//   city: city,
//   fetchedAt: DateTime.now(),
// );
return WeatherData(
      tempC: (j['main']['temp'] as num).toDouble(),
      rainfallMm3h: rain,
      windKmh: ((j['wind']['speed'] as num) * 3.6),
      aqi: 0, description: j['weather'][0]['description'] ?? '',
      city: city, fetchedAt: DateTime.now(),
    );
  }

  static Future<int> fetchAqi(double lat, double lng) async {
    if (_owmKey == 'YOUR_OWM_API_KEY' || _owmKey.isEmpty) return 80;
    try {
      final res = await http
          .get(Uri.parse(
            'https://api.openweathermap.org/data/2.5/air_pollution'
            '?lat=$lat&lon=$lng&appid=$_owmKey'))
          .timeout(_timeout);
      _check(res);
      final j = jsonDecode(res.body);
      final aqi = j['list'][0]['main']['aqi'] as int;
      const m = {1: 25, 2: 75, 3: 150, 4: 250, 5: 375};
      return m[aqi] ?? 80;
    } catch (_) { return 80; }
  }

  // ── ERROR HANDLING ────────────────────────────────────────────────────
  static void _check(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Request failed (${res.statusCode})';
      try { msg = jsonDecode(res.body)['message'] ?? msg; } catch (_) {}
      throw ApiException(msg, res.statusCode);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override String toString() => message;
}
