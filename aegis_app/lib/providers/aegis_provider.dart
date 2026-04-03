import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/risk_engine.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

enum AppState { initial, loading, authenticated, unauthenticated, error }

class AegisProvider extends ChangeNotifier {
  AppState _appState = AppState.initial;
  Worker?  _worker;
  WeatherData? _weather;
  RiskResult?  _riskResult;
  List<DisruptionAlert> _alerts = [];
  List<Claim> _claims = [];
  String? _errorMessage;
  bool _loadingWeather = false;
  bool _loadingAlerts  = false;
  bool _loadingClaims  = false;
  String? _deviceId;
  Timer? _pollTimer;

  // ── Getters ────────────────────────────────────────────────────────────
  AppState get appState        => _appState;
  Worker?  get worker          => _worker;
  WeatherData? get weather     => _weather;
  RiskResult?  get riskResult  => _riskResult;
  List<DisruptionAlert> get alerts => _alerts;
  List<Claim> get claims       => _claims;
  String? get errorMessage     => _errorMessage;
  bool get loadingWeather      => _loadingWeather;
  bool get loadingAlerts       => _loadingAlerts;
  bool get loadingClaims       => _loadingClaims;
  bool get isLoggedIn          => _worker != null;
  bool get hasActiveAlert      =>
      _alerts.any((a) => a.status == 'active' && a.gate1Pass && a.gate2Pass);


  // KEY FIX: check if a JWT token is stored before hitting the network.
  // On a fresh install or when the backend is unreachable, we skip the
  // getProfile() call and go straight to unauthenticated (= onboarding).
  Future<void> init() async {
    _appState = AppState.loading;
    notifyListeners();

    await NotificationService.init();
    await _loadDeviceId();

    // Only try to restore session if we have a saved token
    final tokenExists = await ApiService.hasToken();
    if (!tokenExists) {
      _appState = AppState.unauthenticated;
      notifyListeners();
      return;
    }

    // Token found — try to restore session (with hard 5s timeout)
    try {
      _worker = await ApiService.getProfile();
      _appState = AppState.authenticated;
      // Load background data without blocking the UI
      _refreshAll().catchError((_) {});
      _startPolling();
    } catch (_) {
      // Backend unreachable or token expired — clear token, go to onboarding
      await ApiService.logout();
      _appState = AppState.unauthenticated;
    }
    notifyListeners();
  }

  // ── AUTH ───────────────────────────────────────────────────────────────
  Future<String> requestOtp(String phone) async {
    _setLoading();
    try {
      final otp = await ApiService.requestOtp(phone);
      _clearLoading();
      return otp;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> verifyOtp(String phone, String otp) async {
    _setLoading();
    try {
      _worker = await ApiService.verifyOtp(phone, otp);
      _appState = AppState.authenticated;
      _refreshAll().catchError((_) {});
      _startPolling();
      _clearLoading();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> register({
    required String name, required String phone,
    required String platform, required String city,
    required String zone, required String upiId,
  }) async {
    _setLoading();
    try {
      _worker = await ApiService.register(
        name: name, phone: phone, platform: platform,
        city: city, zone: zone, upiId: upiId,
      );
      _appState = AppState.authenticated;
      _clearLoading();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> completeKyc(String aadhaarNumber) async {
    if (_worker == null) return;
    _setLoading();
    try {
      _worker = await ApiService.completeKyc(
        aadhaarNumber: aadhaarNumber, workerId: _worker!.id);
      _clearLoading();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    _pollTimer?.cancel();
    await ApiService.logout();
    _worker   = null;
    _weather  = null;
    _riskResult = null;
    _alerts = [];
    _claims = [];
    _appState = AppState.unauthenticated;
    notifyListeners();
  }

Future<void> fetchWeatherAndScore() async {
    if (_worker == null) return;
    
    _loadingWeather = true;
    notifyListeners();

    try {
      // 1. Fetch live weather (keep your existing logic here)
      _weather = await ApiService.fetchWeather(_worker!.city);

      // 2. NEW: Ask the Node.js backend for the ML Risk Prediction
      _riskResult = await ApiService.computeRiskScore(
        city: _worker!.city,
        zone: _worker!.zone,
        weeklyEarningsAvg: _worker!.weeklyEarningsAvg,
        rainfallMm: _weather!.rainfallMm3h,
        tempC: _weather!.tempC,
        aqi: _weather!.aqi,
        monsoonSeason: true, // You can make this dynamic if needed
      );

    } catch (e) {
      print("Error fetching weather or AI score: $e");
      // Handle error state appropriately
    } finally {
      _loadingWeather = false;
      notifyListeners();
    }
  }

  // ── SUBSCRIBE ──────────────────────────────────────────────────────────
  Future<void> subscribe({
    required String planTier, required double premium,
  }) async {
    if (_worker == null) return;
    _setLoading();
    try {
      _worker = await ApiService.subscribe(
        planTier: planTier, weeklyPremium: premium);
      _clearLoading();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  // ── ALERTS ─────────────────────────────────────────────────────────────
  Future<void> fetchAlerts() async {
    if (_worker == null) return;
    _loadingAlerts = true;
    notifyListeners();
    try {
      _alerts = await ApiService.getAlerts(_worker!.zone);
    } catch (_) { _alerts = []; }
    _loadingAlerts = false;
    notifyListeners();
  }

  // ── CLAIMS ─────────────────────────────────────────────────────────────
  Future<void> fetchClaims() async {
    if (_worker == null) return;
    _loadingClaims = true;
    notifyListeners();
    try {
      _claims = await ApiService.getClaims();
      for (final c in _claims) {
        if (c.status == ClaimStatus.paid && c.resolvedAt != null &&
            DateTime.now().difference(c.resolvedAt!).inMinutes < 5) {
          await NotificationService.showPayoutNotification(
            amount: c.amount, trigger: c.triggerType);
        }
      }
    } catch (_) { _claims = []; }
    _loadingClaims = false;
    notifyListeners();
  }

  Future<Claim> submitClaim(String alertId) async {
    final pos = await LocationService.getCurrentPosition();
    if (pos == null) {
      throw Exception('Could not get location. Enable GPS and try again.');
    }
    final isMock = await LocationService.isMockLocation();
    if (isMock) {
      throw Exception('Mock location detected. Disable GPS spoofing apps.');
    }
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(
      source: ImageSource.camera, imageQuality: 60, maxWidth: 800);
    if (xfile == null) {
      throw Exception('Photo is required to verify your location.');
    }
    final bytes = await File(xfile.path).readAsBytes();
    final b64   = base64Encode(bytes);

    final claim = await ApiService.submitClaim(
      alertId: alertId, lat: pos.latitude, lng: pos.longitude,
      imageBase64: b64, deviceId: _deviceId ?? 'unknown',
    );
    await fetchClaims();
    if (claim.status == ClaimStatus.held) {
      await NotificationService.showClaimHeld(
          'Your claim is under review. You\'ll hear back within 4 hours.');
    }
    return claim;
  }

  // ── DEVICE ID ──────────────────────────────────────────────────────────
  Future<void> _loadDeviceId() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        _deviceId = (await info.androidInfo).id;
      } else if (Platform.isIOS) {
        _deviceId = (await info.iosInfo).identifierForVendor;
      }
    } catch (_) {}
  }

  // ── POLLING ────────────────────────────────────────────────────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 30), (_) async {
      await fetchWeatherAndScore();
      await fetchAlerts();
      await fetchClaims();
    });
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      fetchWeatherAndScore(),
      fetchAlerts(),
      fetchClaims(),
    ]);
  }

  // ── HELPERS ────────────────────────────────────────────────────────────
  List<double> _cityCoords(String city) {
    const m = {
      'Chennai':   [13.0827, 80.2707],
      'Mumbai':    [19.0760, 72.8777],
      'Delhi':     [28.6139, 77.2090],
      'Bengaluru': [12.9716, 77.5946],
      'Hyderabad': [17.3850, 78.4867],
    };
    return m[city] ?? [13.0827, 80.2707];
  }

  void _setLoading() {
    _appState = AppState.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _clearLoading() {
    _appState = AppState.authenticated;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _appState = _worker != null
        ? AppState.authenticated
        : AppState.unauthenticated;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void reset() {}
}
