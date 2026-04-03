import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});
  @override State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _fade;
  bool _submitting = false;
  String? _submittedClaimId;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _fade = Tween<double>(begin: 0.4, end: 1.0).animate(_pulse);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AegisProvider>().fetchAlerts();
    });
  }

  @override void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<AegisProvider>(builder: (_, prov, __) {
      final activeAlerts = prov.alerts
          .where((a) => a.status == 'active' && a.gate1Pass && a.gate2Pass)
          .toList();

      return Stack(children: [
        RefreshIndicator(
          onRefresh: prov.fetchAlerts,
          color: AppColors.blue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(children: [
              _buildHeader(context, activeAlerts.isNotEmpty),
              Padding(
                padding: const EdgeInsets.all(16),
                child: prov.loadingAlerts
                    ? _buildLoadingCard()
                    : activeAlerts.isEmpty
                        ? _buildNoAlertCard()
                        : Column(children: [
                            ...activeAlerts.map((a) => _buildAlertCard(context, a, prov)),
                            const SizedBox(height: 24),
                          ]),
              ),
            ]),
          ),
        ),
        if (_submitting) const LoadingOverlay(message: 'Verifying your location...\nPlease take a photo when prompted.'),
      ]);
    });
  }

  Widget _buildHeader(BuildContext context, bool hasAlert) => Container(
    width: double.infinity, color: hasAlert ? AppColors.red : AppColors.navy,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16, right: 16, bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(
            color: hasAlert ? const Color(0xFFF7C1C1) : AppColors.blue,
            borderRadius: BorderRadius.circular(8)),
          child: Icon(
            hasAlert ? Icons.warning_rounded : Icons.notifications,
            color: hasAlert ? AppColors.red : AppColors.white, size: 18)),
        const SizedBox(width: 10),
        Text('Aegis', style: GoogleFonts.nunito(
          fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.white)),
      ]),
      const SizedBox(height: 10),
      Text(hasAlert ? 'Disruption Detected' : 'Disruption Alerts',
        style: GoogleFonts.nunito(
          fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.white)),
      Text(hasAlert ? 'Active trigger confirmed in your zone'
          : 'No active disruptions right now',
        style: GoogleFonts.nunito(fontSize: 12,
          color: hasAlert ? const Color(0xFFF7C1C1) : const Color(0xFF85B7EB))),
    ]),
  );

  Widget _buildLoadingCard() => AppCard(
    child: Column(children: [
      const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(AppColors.blue)),
      const SizedBox(height: 12),
      Text('Checking disruption signals in your zone...',
        style: GoogleFonts.nunito(fontSize: 13, color: AppColors.mid),
        textAlign: TextAlign.center),
    ]),
  );

  Widget _buildNoAlertCard() => AppCard(
    child: Column(children: [
      const Icon(Icons.check_circle_outline, color: AppColors.green, size: 44),
      const SizedBox(height: 12),
      Text('Your zone is clear', style: GoogleFonts.nunito(
        fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.dark)),
      const SizedBox(height: 6),
      Text('Aegis is monitoring 24/7. You\'ll be notified instantly if a disruption is detected.',
        style: GoogleFonts.nunito(fontSize: 12, color: AppColors.muted),
        textAlign: TextAlign.center),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.blueLight, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          const Icon(Icons.schedule, color: AppColors.blue, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text('Signals refreshed every 30 minutes. Pull down to check now.',
            style: GoogleFonts.nunito(fontSize: 11, color: AppColors.blue))),
        ])),
    ]),
  );

  Widget _buildAlertCard(BuildContext context, DisruptionAlert alert, AegisProvider prov) {
    return Column(children: [
      // Gate status card
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle(alert.typeLabel),
        const SizedBox(height: 8),
        StatRow(label: 'Affected zone', value: alert.zone),
        const Divider(height: 10, color: Color(0xFFF1EFE8)),
        StatRow(label: 'Detected at',
          value: _formatTime(alert.detectedAt)),
        const Divider(height: 10, color: Color(0xFFF1EFE8)),
        StatRow(label: 'Payout coverage',
          value: '${(alert.payoutPct * 100).toInt()}% of daily earnings',
          valueColor: AppColors.green),
        const SizedBox(height: 10),
        // Dual gate display
        Row(children: [
          _gateChip('Gate 1\nExternal Signal', alert.gate1Pass),
          const SizedBox(width: 8),
          _gateChip('Gate 2\nBusiness Impact', alert.gate2Pass),
        ]),
        if (alert.gate1Pass && alert.gate2Pass) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.greenLight, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.greenMid, width: 0.8)),
            child: Row(children: [
              const Icon(Icons.verified, color: AppColors.green, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Both gates confirmed — you qualify for a payout',
                style: GoogleFonts.nunito(fontSize: 11,
                  fontWeight: FontWeight.w600, color: AppColors.green))),
            ]),
          ),
        ],
      ])),
      const SizedBox(height: 12),

      // Location auth card
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Location verification'),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const PipelineStep(label: 'GPS check', state: PipelineStepState.done),
          const PipelineStep(label: 'Tower ID', state: PipelineStepState.done),
          PipelineStep(label: 'Photo verify', state: _submittedClaimId != null
              ? PipelineStepState.done : PipelineStepState.active),
          PipelineStep(label: 'AI score', state: _submittedClaimId != null
              ? PipelineStepState.done : PipelineStepState.pending, isLast: true),
        ]),
        const SizedBox(height: 10),
        FadeTransition(
          opacity: _submittedClaimId == null ? _fade : const AlwaysStoppedAnimation(1.0),
          child: Center(child: Text(
            _submittedClaimId != null
                ? 'Verification submitted — claim processing'
                : 'Tap below to verify your location',
            style: GoogleFonts.nunito(fontSize: 12,
              color: _submittedClaimId != null ? AppColors.green : AppColors.blue))),
        ),
      ])),
      const SizedBox(height: 12),

      // GPS warning
      const InfoBanner(
        title: 'GPS spoofing detected = instant disqualification',
        message: 'We cross-check GPS, cell tower ID, photo location, and delivery activity. Fake locations are automatically rejected.',
        bg: AppColors.amberLight, borderColor: AppColors.amberMid,
        titleColor: AppColors.amber, messageColor: AppColors.amber,
        icon: Icons.gps_off),
      const SizedBox(height: 12),

      // Claim submission button
      if (_submittedClaimId == null)
        ElevatedButton.icon(
          onPressed: _submitting ? null : () => _submitClaim(alert, prov),
          icon: const Icon(Icons.camera_alt, size: 18),
          label: Text('Verify location & claim payout',
            style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )
      else
        AppCard(
          color: AppColors.greenLight,
          borderColor: AppColors.greenMid,
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Claim submitted',
                style: GoogleFonts.nunito(fontSize: 13,
                  fontWeight: FontWeight.w700, color: AppColors.green)),
              Text('Processing — check Payouts tab for updates',
                style: GoogleFonts.nunito(fontSize: 11, color: AppColors.greenMid)),
            ])),
          ]),
        ),
    ]);
  }

  Widget _gateChip(String label, bool passed) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: passed ? AppColors.greenLight : AppColors.redLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: passed ? AppColors.greenMid : AppColors.redMid,
          width: 0.8)),
      child: Row(children: [
        Icon(passed ? Icons.check_circle : Icons.cancel_outlined,
          color: passed ? AppColors.green : AppColors.red, size: 14),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: GoogleFonts.nunito(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: passed ? AppColors.green : AppColors.red))),
      ]),
    ),
  );

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Future<void> _submitClaim(DisruptionAlert alert, AegisProvider prov) async {
    setState(() => _submitting = true);
    try {
      final claim = await prov.submitClaim(alert.id);
      setState(() => _submittedClaimId = claim.id);
      if (mounted) {
        SuccessSnack.show(context,
          claim.status == ClaimStatus.paid
              ? '₹${claim.amount.toInt()} credited to your UPI!'
              : 'Claim submitted — processing in progress.');
      }
    } catch (e) {
      if (mounted) ErrorSnack.show(context, e.toString());
    }
    setState(() => _submitting = false);
  }
}
