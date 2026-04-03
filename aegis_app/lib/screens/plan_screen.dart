import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  String _selectedTier = 'standard';
  bool _subscribing = false;

  final _triggers = [
    {'label': 'Rainfall', 'icon': Icons.water_drop, 'color': AppColors.blue, 'bg': AppColors.blueLight},
    {'label': 'Temperature', 'icon': Icons.thermostat, 'color': AppColors.amber, 'bg': AppColors.amberLight},
    {'label': 'AQI', 'icon': Icons.air, 'color': AppColors.red, 'bg': AppColors.redLight},
    {'label': 'Order Volume', 'icon': Icons.receipt_long, 'color': AppColors.green, 'bg': AppColors.greenLight},
    {'label': 'Platform Runtime', 'icon': Icons.access_time, 'color': const Color(0xFF534AB7), 'bg': const Color(0xFFEEEDFE)},
    {'label': 'Local News', 'icon': Icons.newspaper, 'color': AppColors.mid, 'bg': const Color(0xFFF1EFE8)},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AegisProvider>().fetchWeatherAndScore();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AegisProvider>(builder: (_, prov, __) {
      final risk = prov.riskResult;
      final weather = prov.weather;
      final worker = prov.worker;

      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(children: [
          Column(children: [
            _buildHeader(worker?.city ?? 'Chennai'),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                if (prov.loadingWeather) _buildWeatherLoading()
                else if (weather != null) _buildWeatherCard(weather),
                const SizedBox(height: 12),
                _buildTriggersCard(),
                const SizedBox(height: 12),
                if (risk != null) ...[
                  _buildRiskCard(risk),
                  const SizedBox(height: 12),
                  _buildPlanOptions(risk),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _subscribing ? null : () => _subscribe(risk),
                    child: _subscribing
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(AppColors.white)))
                        : Text('Subscribe — ₹${_premiumForTier(risk).toInt()}/week',
                            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white)),
                  ),
                  const SizedBox(height: 8),
                  Center(child: Text('Auto-renews weekly · Cancel anytime',
                    style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted))),
                ],
                const SizedBox(height: 20),
              ]),
            )),
          ]),
          if (_subscribing) const LoadingOverlay(message: 'Activating coverage...'),
        ]),
      );
    });
  }

  Widget _buildHeader(String city) => Container(
    width: double.infinity, color: AppColors.navy,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16, right: 16, bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.shield, color: AppColors.white, size: 18)),
        const SizedBox(width: 10),
        Text('Aegis', style: GoogleFonts.nunito(
          fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.white)),
        const Spacer(),
        const StatusBadge(label: 'KYC Verified ✓',
          bg: AppColors.greenLight, textColor: AppColors.green),
      ]),
      const SizedBox(height: 10),
      Text('Choose your plan', style: GoogleFonts.nunito(
        fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.white)),
      Text('Live risk assessment for $city',
        style: GoogleFonts.nunito(fontSize: 12, color: const Color(0xFF85B7EB))),
    ]),
  );

  Widget _buildWeatherLoading() => AppCard(
    child: Row(children: [
      const SizedBox(width: 24, height: 24,
        child: CircularProgressIndicator(strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(AppColors.blue))),
      const SizedBox(width: 12),
      Text('Fetching live weather data...',
        style: GoogleFonts.nunito(fontSize: 13, color: AppColors.mid)),
    ]),
  );

  Widget _buildWeatherCard(weather) => AppCard(
    borderColor: AppColors.blueMid,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.cloud, color: AppColors.blue, size: 18),
        const SizedBox(width: 8),
        SectionTitle('Live conditions — ${weather.city}'),
        const Spacer(),
        Text('OpenWeatherMap',
          style: GoogleFonts.nunito(fontSize: 10, color: AppColors.muted)),
      ]),
      const Divider(height: 14, color: Color(0xFFF1EFE8)),
      Row(children: [
        _weatherStat('🌡', '${weather.tempC.toStringAsFixed(1)}°C'),
        _weatherStat('🌧', '${weather.rainfallMm3h.toStringAsFixed(1)}mm'),
        _weatherStat('💨', '${weather.windKmh.toStringAsFixed(0)}km/h'),
        _weatherStat('🌫', 'AQI ${weather.aqi}'),
      ]),
      const SizedBox(height: 6),
      Text(weather.description,
        style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted,
          fontStyle: FontStyle.italic)),
    ]),
  );

  Widget _weatherStat(String icon, String val) => Expanded(
    child: Column(children: [
      Text(icon, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 2),
      Text(val, style: GoogleFonts.nunito(
        fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.dark)),
    ]),
  );

  Widget _buildTriggersCard() => AppCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Parametric triggers monitored'),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 3, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.1,
        children: _triggers.map((t) => Container(
          decoration: BoxDecoration(
            color: t['bg'] as Color, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 0.5)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(t['icon'] as IconData, color: t['color'] as Color, size: 20),
            const SizedBox(height: 4),
            Text(t['label'] as String, style: GoogleFonts.nunito(
              fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.dark),
              textAlign: TextAlign.center),
          ]),
        )).toList(),
      ),
    ],
  ));

  Widget _buildRiskCard(risk) {
    final bandColors = {'low': AppColors.green, 'medium': AppColors.amber,
                        'high': AppColors.red, 'extreme': AppColors.red};
    final bandBgs = {'low': AppColors.greenLight, 'medium': AppColors.amberLight,
                     'high': AppColors.redLight, 'extreme': AppColors.redLight};
    final c = bandColors[risk.band] ?? AppColors.amber;
    final bg = bandBgs[risk.band] ?? AppColors.amberLight;

    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const SectionTitle('AI risk score'),
        StatusBadge(label: '${risk.band.toUpperCase()} RISK',
          bg: bg, textColor: c),
      ]),
      const SizedBox(height: 10),
      ClipRRect(borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: risk.score / 100, minHeight: 10,
          backgroundColor: const Color(0xFFF1EFE8),
          valueColor: AlwaysStoppedAnimation(c))),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Score: ${risk.score} / 100',
          style: GoogleFonts.nunito(fontSize: 12, color: AppColors.mid)),
        Text('Multiplier: ${risk.multiplier}×',
          style: GoogleFonts.nunito(fontSize: 12,
            fontWeight: FontWeight.w600, color: AppColors.dark)),
      ]),
      if (risk.breakdown.isNotEmpty) ...[
        const Divider(height: 14, color: Color(0xFFF1EFE8)),
        ...risk.breakdown.entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(
              color: c, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(_conditionLabel(e.key),
              style: GoogleFonts.nunito(fontSize: 11, color: AppColors.mid)),
            const Spacer(),
            Text('+${e.value.toStringAsFixed(1)}',
              style: GoogleFonts.nunito(fontSize: 11,
                fontWeight: FontWeight.w600, color: c)),
          ]),
        )),
      ],
    ]));
  }

  Widget _buildPlanOptions(risk) {
    final tiers = [
      {'tier': 'basic', 'label': 'Basic', 'mult': 0.8,
       'desc': 'Rainfall + AQI triggers only'},
      {'tier': 'standard', 'label': 'Standard', 'mult': 1.0,
       'desc': 'All 6 triggers · recommended'},
      {'tier': 'premium', 'label': 'Premium', 'mult': 1.2,
       'desc': 'All triggers + priority payout'},
    ];

    return Column(children: tiers.map((t) {
      final prem = (risk.weeklyPremium * (t['mult'] as double)).round();
      final coverage = (risk.dailyCoverage * (t['mult'] as double)).round();
      final isSelected = _selectedTier == t['tier'];

      return GestureDetector(
        onTap: () => setState(() => _selectedTier = t['tier'] as String),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.blueLight : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.blue : AppColors.border,
              width: isSelected ? 2 : 0.8)),
          child: Row(children: [
            Radio<String>(
              value: t['tier'] as String, groupValue: _selectedTier,
              onChanged: (v) => setState(() => _selectedTier = v!),
              activeColor: AppColors.blue),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t['label'] as String, style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.navy : AppColors.dark)),
              Text(t['desc'] as String, style: GoogleFonts.nunito(
                fontSize: 11, color: AppColors.muted)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹$prem', style: GoogleFonts.nunito(
                fontSize: 20, fontWeight: FontWeight.w800,
                color: isSelected ? AppColors.navy : AppColors.dark)),
              Text('/week', style: GoogleFonts.nunito(
                fontSize: 10, color: AppColors.muted)),
              Text('covers ₹$coverage/day',
                style: GoogleFonts.nunito(fontSize: 10, color: AppColors.blue)),
            ]),
          ]),
        ),
      );
    }).toList());
  }

  double _premiumForTier(risk) {
    final m = {'basic': 0.8, 'standard': 1.0, 'premium': 1.2};
    return (risk.weeklyPremium * (m[_selectedTier] ?? 1.0)).roundToDouble();
  }

  String _conditionLabel(String key) {
    const m = {
      'rainfall_65mm': 'Rainfall >65mm detected',
      'temp_41c': 'Temperature >41°C',
      'aqi_300': 'AQI >300',
      'order_drop_30pct': 'Order volume drop >30%',
      'earnings_drop_20': 'Earnings drop >20%',
    };
    return m[key] ?? key;
  }

  Future<void> _subscribe(risk) async {
    setState(() => _subscribing = true);
    try {
      await context.read<AegisProvider>().subscribe(
        planTier: _selectedTier,
        premium: _premiumForTier(risk),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      ErrorSnack.show(context, e.toString());
    }
    setState(() => _subscribing = false);
  }
}
