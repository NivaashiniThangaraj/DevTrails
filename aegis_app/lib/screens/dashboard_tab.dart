import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import 'package:intl/intl.dart';
import 'home_screen.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AegisProvider>(builder: (_, prov, __) {
      final worker = prov.worker;
      final claims = prov.claims;

      return RefreshIndicator(
        onRefresh: () async {
          await prov.fetchWeatherAndScore();
          await prov.fetchAlerts();
          await prov.fetchClaims();
        },
        color: AppColors.blue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(children: [
            _buildHero(context, worker, prov),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _buildEarningsTiles(claims),
                const SizedBox(height: 12),
                _buildAlertPreview(context, prov),
                const SizedBox(height: 12),
                _buildClaimsCard(claims),
                const SizedBox(height: 12),
                if (worker?.subscribed == true)
                  _buildRenewButton(context, prov),
                const SizedBox(height: 24),
              ]),
            ),
          ]),
        ),
      );
    });
  }

  Widget _buildHero(BuildContext context, Worker? w, AegisProvider prov) {
    final hasAlert = prov.alerts.isNotEmpty;
    return Container(
      width: double.infinity, color: AppColors.navy,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16, right: 16, bottom: 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Good ${_greeting()}, ${w?.name.split(' ').first ?? 'Shiva'}',
              style: GoogleFonts.nunito(fontSize: 12, color: const Color(0xFF85B7EB))),
            const SizedBox(height: 4),
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                color: w?.subscribed == true
                    ? const Color(0xFF639922) : AppColors.redMid,
                shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                w?.subscribed == true
                    ? '${w!.planTier[0].toUpperCase()}${w.planTier.substring(1)} plan · Active'
                    : 'Not subscribed',
                style: GoogleFonts.nunito(fontSize: 13,
                  fontWeight: FontWeight.w700, color: AppColors.white)),
            ]),
            if (hasAlert)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.redLight, borderRadius: BorderRadius.circular(5)),
                child: Text('⚠ Active disruption in your zone',
                  style: GoogleFonts.nunito(fontSize: 10,
                    fontWeight: FontWeight.w700, color: AppColors.red)),
              ),
          ])),
          Container(width: 36, height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF1E3A6E), shape: BoxShape.circle),
            child: Center(child: Text(
              (w?.name.isNotEmpty == true) ? w!.name[0].toUpperCase() : 'S',
              style: GoogleFonts.nunito(fontSize: 15,
                fontWeight: FontWeight.w700, color: const Color(0xFF85B7EB))))),
        ]),
        const SizedBox(height: 14),
        const Divider(color: Color(0xFF1E3A6E), height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _heroStat('Weekly fee', w != null ? '₹${w.weeklyPremium.toInt()}' : '—'),
            _heroDivider(),
            _heroStat('Coverage', w != null
                ? '₹${(w.weeklyEarningsAvg / 6 * 0.8).toInt()}' : '—'),
            _heroDivider(),
            _heroStat('Risk score', w != null ? '${w.riskScore}' : '—'),
          ]),
        ),
      ]),
    );
  }

  Widget _heroStat(String label, String value) => Column(children: [
    Text(label, style: GoogleFonts.nunito(fontSize: 10, color: const Color(0xFF85B7EB))),
    const SizedBox(height: 2),
    Text(value, style: GoogleFonts.nunito(
      fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.white)),
  ]);

  Widget _heroDivider() =>
    Container(width: 1, height: 36, color: const Color(0xFF1E3A6E));

  Widget _buildEarningsTiles(List<Claim> claims) {
    final totalPaid = claims
        .where((c) => c.status == ClaimStatus.paid)
        .fold(0.0, (s, c) => s + c.amount);
    final pending = claims
        .where((c) => c.status == ClaimStatus.pending ||
                      c.status == ClaimStatus.fraudCheck)
        .length;

    return Row(children: [
      Expanded(child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.greenLight, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Total paid out', style: GoogleFonts.nunito(
            fontSize: 10, color: AppColors.green)),
          Text('₹${totalPaid.toInt()}', style: GoogleFonts.nunito(
            fontSize: 22, fontWeight: FontWeight.w800,
            color: const Color(0xFF173404))),
          Text('this month', style: GoogleFonts.nunito(
            fontSize: 10, color: AppColors.greenMid)),
        ]),
      )),
      const SizedBox(width: 10),
      Expanded(child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: pending > 0 ? AppColors.amberLight : AppColors.blueLight,
          borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pending claims', style: GoogleFonts.nunito(
            fontSize: 10,
            color: pending > 0 ? AppColors.amber : AppColors.blue)),
          Text('$pending', style: GoogleFonts.nunito(
            fontSize: 22, fontWeight: FontWeight.w800,
            color: pending > 0
                ? const Color(0xFF412402) : const Color(0xFF042C53))),
          Text(pending > 0 ? 'under review' : 'all clear',
            style: GoogleFonts.nunito(fontSize: 10,
              color: pending > 0 ? AppColors.amberMid : AppColors.blueMid)),
        ]),
      )),
    ]);
  }

  Widget _buildAlertPreview(BuildContext context, AegisProvider prov) {
    final active = prov.alerts
        .where((a) => a.status == 'active' && a.gate1Pass && a.gate2Pass)
        .toList();

    if (active.isEmpty && !prov.loadingAlerts) {
      return AppCard(child: Row(children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(
            color: AppColors.greenLight, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.check_circle_outline,
            color: AppColors.green, size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('No active disruptions',
            style: GoogleFonts.nunito(fontSize: 13,
              fontWeight: FontWeight.w600, color: AppColors.dark)),
          Text('Your zone is clear right now',
            style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted)),
        ])),
        const StatusBadge(label: 'Safe',
          bg: AppColors.greenLight, textColor: AppColors.green),
      ]));
    }

    if (prov.loadingAlerts) {
      return AppCard(
      child: Row(children: [
        const SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.blue))),
        const SizedBox(width: 12),
        Text('Checking your zone...',
          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.mid)),
      ]),
    );
    }

    final a = active.first;
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const HomeScreen(initialTab: 1))),
      child: AppCard(
        borderColor: AppColors.redMid,
        color: AppColors.redLight,
        child: Row(children: [
          Container(width: 34, height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFF7C1C1), shape: BoxShape.circle),
            child: const Icon(Icons.warning_rounded,
              color: AppColors.red, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.typeLabel, style: GoogleFonts.nunito(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.red)),
            Text('${a.zone} · Tap to view',
              style: GoogleFonts.nunito(fontSize: 11, color: AppColors.redMid)),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.red, size: 18),
        ]),
      ),
    );
  }

  Widget _buildClaimsCard(List<Claim> claims) {
    if (claims.isEmpty) {
      return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Claim history'),
        const SizedBox(height: 10),
        Center(child: Column(children: [
          const Icon(Icons.history, color: AppColors.muted, size: 32),
          const SizedBox(height: 8),
          Text('No claims yet',
            style: GoogleFonts.nunito(fontSize: 13, color: AppColors.muted)),
          Text('Payouts will appear here after disruption events',
            style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted),
            textAlign: TextAlign.center),
        ])),
      ]),
    );
    }

    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Recent claims'),
      const SizedBox(height: 8),
      ...claims.take(3).map((c) {
        final isPaid = c.status == ClaimStatus.paid;
        final isHeld = c.status == ClaimStatus.held || c.status == ClaimStatus.fraudCheck;
        return Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.triggerType, style: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
              Text(DateFormat('MMM d').format(c.createdAt),
                style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(isPaid ? '+₹${c.amount.toInt()}' : '₹${c.amount.toInt()}',
                style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: isPaid ? AppColors.green
                      : isHeld ? AppColors.amber : AppColors.muted)),
              StatusBadge(
                label: c.statusLabel,
                bg: isPaid ? AppColors.greenLight
                    : isHeld ? AppColors.amberLight : AppColors.blueLight,
                textColor: isPaid ? AppColors.green
                    : isHeld ? AppColors.amber : AppColors.blue),
            ]),
          ]),
          if (c != claims.take(3).last)
            const Divider(height: 12, color: Color(0xFFF1EFE8)),
        ]);
      }),
    ]));
  }

  Widget _buildRenewButton(BuildContext context, AegisProvider prov) =>
    OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        side: const BorderSide(color: AppColors.blue, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text('Renew for next week',
        style: GoogleFonts.nunito(fontSize: 15,
          fontWeight: FontWeight.w700, color: AppColors.blue)),
    );

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}
