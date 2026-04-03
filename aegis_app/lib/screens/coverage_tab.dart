import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class CoverageTab extends StatelessWidget {
  const CoverageTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AegisProvider>(builder: (_, prov, __) {
      final w = prov.worker;
      final risk = prov.riskResult;
      final weather = prov.weather;

      return RefreshIndicator(
        onRefresh: prov.fetchWeatherAndScore,
        color: AppColors.blue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(children: [
            _buildHeader(context, w),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                if (w?.subscribed == true) _buildActiveCoverage(w!, risk)
                else _buildNotSubscribed(context),
                const SizedBox(height: 12),
                if (risk != null) _buildRiskBreakdown(risk),
                const SizedBox(height: 12),
                if (weather != null) _buildLiveConditions(weather),
                const SizedBox(height: 12),
                _buildTriggerTable(),
                const SizedBox(height: 12),
                _buildPrivacyNote(),
                const SizedBox(height: 24),
              ]),
            ),
          ]),
        ),
      );
    });
  }

  Widget _buildHeader(BuildContext context, worker) => Container(
    width: double.infinity, color: AppColors.navy,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16, right: 16, bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(
            color: AppColors.blue, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.shield, color: AppColors.white, size: 18)),
        const SizedBox(width: 10),
        Text('Aegis', style: GoogleFonts.nunito(
          fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.white)),
      ]),
      const SizedBox(height: 10),
      Text('Your coverage', style: GoogleFonts.nunito(
        fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.white)),
      Text('${worker?.platform ?? ''} · ${worker?.zone ?? ''}',
        style: GoogleFonts.nunito(
          fontSize: 12, color: const Color(0xFF85B7EB))),
    ]),
  );

  Widget _buildActiveCoverage(worker, risk) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.navy, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(
          color: Color(0xFF639922), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('${worker.planTier[0].toUpperCase()}${worker.planTier.substring(1)} plan · Active',
          style: GoogleFonts.nunito(
            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.white)),
      ]),
      const SizedBox(height: 4),
      Text('${worker.platform} · ${worker.city} · ${worker.zone}',
        style: GoogleFonts.nunito(fontSize: 11, color: const Color(0xFF85B7EB))),
      const Divider(color: Color(0xFF1E3A6E), height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _covStat('Weekly fee', '₹${worker.weeklyPremium.toInt()}'),
        _covStat('Daily payout', risk != null
            ? '₹${risk.dailyCoverage.toInt()}' : '—'),
        _covStat('Max/week', risk != null
            ? '₹${risk.maxWeekly.toInt()}' : '—'),
      ]),
    ]),
  );

  Widget _covStat(String label, String value) => Column(children: [
    Text(label, style: GoogleFonts.nunito(
      fontSize: 10, color: const Color(0xFF85B7EB))),
    const SizedBox(height: 3),
    Text(value, style: GoogleFonts.nunito(
      fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.white)),
  ]);

  Widget _buildNotSubscribed(BuildContext context) => AppCard(
    borderColor: AppColors.amberMid,
    color: AppColors.amberLight,
    child: Column(children: [
      const Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 32),
      const SizedBox(height: 8),
      Text('No active coverage', style: GoogleFonts.nunito(
        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.amber)),
      const SizedBox(height: 4),
      Text('You are not protected against income disruptions.',
        style: GoogleFonts.nunito(fontSize: 12, color: AppColors.amber),
        textAlign: TextAlign.center),
    ]),
  );

  Widget _buildRiskBreakdown(risk) {
    final riskColors = {'low': AppColors.green, 'medium': AppColors.amber,
                        'high': AppColors.red, 'extreme': AppColors.red};
    final c = riskColors[risk.band] ?? AppColors.amber;

    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const SectionTitle('Live risk assessment'),
        Text('Score ${risk.score}/100',
          style: GoogleFonts.nunito(fontSize: 12,
            fontWeight: FontWeight.w700, color: c)),
      ]),
      const SizedBox(height: 10),
      ClipRRect(borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: risk.score / 100, minHeight: 10,
          backgroundColor: const Color(0xFFF1EFE8),
          valueColor: AlwaysStoppedAnimation(c))),
      const SizedBox(height: 12),
      const Divider(height: 1, color: Color(0xFFF1EFE8)),
      const SizedBox(height: 10),
      Text('Active risk conditions:', style: GoogleFonts.nunito(
        fontSize: 11, color: AppColors.muted)),
      const SizedBox(height: 6),
      if (risk.breakdown.isEmpty)
        Text('No active disruption conditions', style: GoogleFonts.nunito(
          fontSize: 12, color: AppColors.green))
      else ...risk.breakdown.entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(
            color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(_condLabel(e.key),
            style: GoogleFonts.nunito(fontSize: 11, color: AppColors.mid))),
          Text('+${e.value.toStringAsFixed(1)}',
            style: GoogleFonts.nunito(
              fontSize: 11, fontWeight: FontWeight.w600, color: c)),
        ]),
      )),
    ]));
  }

  Widget _buildLiveConditions(weather) => AppCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.cloud, color: AppColors.blue, size: 16),
        const SizedBox(width: 6),
        const SectionTitle('Live conditions'),
        const Spacer(),
        Text('Updated ${_minutesAgo(weather.fetchedAt)}',
          style: GoogleFonts.nunito(fontSize: 10, color: AppColors.muted)),
      ]),
      const Divider(height: 14, color: Color(0xFFF1EFE8)),
      Row(children: [
        _wxStat('Rainfall', '${weather.rainfallMm3h.toStringAsFixed(1)}mm',
          weather.rainfallMm3h > 65 ? AppColors.red : AppColors.dark),
        _wxStat('Temp', '${weather.tempC.toStringAsFixed(1)}°C',
          weather.tempC > 41 ? AppColors.red : AppColors.dark),
        _wxStat('AQI', '${weather.aqi}',
          weather.aqi > 300 ? AppColors.red : AppColors.dark),
        _wxStat('Wind', '${weather.windKmh.toStringAsFixed(0)}km/h', AppColors.dark),
      ]),
    ]),
  );

  Widget _wxStat(String label, String value, Color valColor) => Expanded(
    child: Column(children: [
      Text(label, style: GoogleFonts.nunito(fontSize: 10, color: AppColors.muted)),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.nunito(
        fontSize: 13, fontWeight: FontWeight.w700, color: valColor)),
    ]),
  );

  Widget _buildTriggerTable() {
    const triggers = [
      ['Heavy Rainfall', '>65mm/3hrs + IMD alert', '80%', 'active'],
      ['Severe Flooding', '>120mm/6hrs', '100%', 'monitoring'],
      ['Extreme Heat', '>41°C + activity drop', '75%', 'monitoring'],
      ['Cyclone/Storm', 'Wind >60km/h + IMD', '100%', 'monitoring'],
      ['Hazardous AQI', '>300 + order drop', '80%', 'monitoring'],
      ['Curfew Sec.144', 'Zone sealed', '90%', 'monitoring'],
      ['Zone Suspension', 'Platform halts zone', '85%', 'monitoring'],
    ];

    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Parametric trigger table'),
      const SizedBox(height: 10),
      ...triggers.map((t) => Column(children: [
        Row(children: [
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t[0], style: GoogleFonts.nunito(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark)),
            Text(t[1], style: GoogleFonts.nunito(
              fontSize: 10, color: AppColors.muted)),
          ])),
          Text(t[2], style: GoogleFonts.nunito(
            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
          const SizedBox(width: 10),
          StatusBadge(
            label: t[3] == 'active' ? 'Active' : 'Watching',
            bg: t[3] == 'active' ? AppColors.redLight : AppColors.blueLight,
            textColor: t[3] == 'active' ? AppColors.red : AppColors.blue),
        ]),
        if (t != triggers.last)
          const Divider(height: 12, color: Color(0xFFF1EFE8)),
      ])),
    ]));
  }

  Widget _buildPrivacyNote() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF1EFE8), borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
      const SizedBox(width: 8),
      Expanded(child: Text(
        'Location and sensor data is collected only during active disruption events to validate claims. You can withdraw consent at any time in Settings.',
        style: GoogleFonts.nunito(fontSize: 11, color: AppColors.mid))),
    ]),
  );

  String _condLabel(String k) {
    const m = {
      'rainfall_65mm': 'Rainfall >65mm active',
      'temp_41c': 'Temperature >41°C',
      'aqi_300': 'AQI >300',
      'order_drop_30pct': 'Order volume drop >30%',
      'earnings_drop_20': 'Earnings drop >20%',
    };
    return m[k] ?? k;
  }

  String _minutesAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    return '${diff.inMinutes}m ago';
  }
}
