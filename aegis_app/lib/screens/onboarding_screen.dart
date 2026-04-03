import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'plan_screen.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0; // 0=phone, 1=otp, 2=profile, 3=kyc
  bool _loading = false;
  String? _demoOtp;

  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();
  final _nameCtrl  = TextEditingController();
  final _upiCtrl   = TextEditingController();
  final _aadhaarCtrl = TextEditingController();

  String _platform = 'Swiggy';
  String _city = 'Chennai';
  String _zone = 'Zone 4 — Central';

  final _platforms = ['Swiggy', 'Zomato', 'Amazon Flex', 'Zepto'];
  final _cities = ['Chennai', 'Mumbai', 'Delhi', 'Bengaluru', 'Hyderabad'];
  final _zones = ['Zone 1 — North', 'Zone 2 — South',
                  'Zone 3 — East', 'Zone 4 — Central', 'Zone 5 — West'];

  @override
  void dispose() {
    _phoneCtrl.dispose(); _otpCtrl.dispose();
    _nameCtrl.dispose(); _upiCtrl.dispose(); _aadhaarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        Column(children: [
          _buildHeader(),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: [_phoneStep, _otpStep, _profileStep, _kycStep][_step](),
          )),
        ]),
        if (_loading) const LoadingOverlay(message: 'Verifying...'),
      ]),
    );
  }

  Widget _buildHeader() => Container(
    width: double.infinity, color: AppColors.navy,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16, right: 16, bottom: 14,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.shield, color: AppColors.white, size: 18)),
        const SizedBox(width: 10),
        Text('Aegis', style: GoogleFonts.nunito(
          fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.white)),
        const Spacer(),
        _buildStepIndicator(),
      ]),
      const SizedBox(height: 10),
      Text(_stepTitles[_step], style: GoogleFonts.nunito(
        fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.white)),
      Text(_stepSubs[_step], style: GoogleFonts.nunito(
        fontSize: 12, color: const Color(0xFF85B7EB))),
    ]),
  );

  final _stepTitles = ['Enter your phone', 'Verify OTP',
                       'Complete profile', 'Aadhaar KYC'];
  final _stepSubs   = ['We\'ll send a one-time password',
                       'Enter the 6-digit code sent to you',
                       'Tell us about yourself',
                       'Required to activate coverage'];

  Widget _buildStepIndicator() => Row(
    children: List.generate(4, (i) => Container(
      width: i == _step ? 20 : 8, height: 8,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: i <= _step ? AppColors.blueLight : const Color(0xFF1E3A6E),
        borderRadius: BorderRadius.circular(4),
      ),
    )),
  );

  // ── Step 0: Phone ──────────────────────────────────────────────────────
  Widget _phoneStep() => Column(children: [
    const SizedBox(height: 20),
    AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Mobile number', style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted)),
      const SizedBox(height: 6),
      TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        maxLength: 10,
        style: GoogleFonts.nunito(fontSize: 15, color: AppColors.dark),
        decoration: InputDecoration(
          prefixText: '+91  ',
          prefixStyle: GoogleFonts.nunito(fontSize: 15, color: AppColors.mid),
          hintText: '9876543210',
          counterText: '',
        ),
      ),
    ])),
    const SizedBox(height: 20),
    ElevatedButton(
      onPressed: _phoneCtrl.text.length == 10 ? _sendOtp : null,
      child: const Text('Send OTP'),
    ),
    const SizedBox(height: 12),
    Center(child: Text('By continuing you agree to Aegis Terms of Service',
      style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted))),
  ]);

  // ── Step 1: OTP ────────────────────────────────────────────────────────
  Widget _otpStep() => Column(children: [
    const SizedBox(height: 20),
    AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('OTP sent to +91 ${_phoneCtrl.text}',
        style: GoogleFonts.nunito(fontSize: 12, color: AppColors.muted)),
      const SizedBox(height: 10),
      TextField(
        controller: _otpCtrl, keyboardType: TextInputType.number,
        maxLength: 6, textAlign: TextAlign.center,
        style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700,
          letterSpacing: 10, color: AppColors.navy),
        decoration: const InputDecoration(counterText: ''),
      ),
      if (_demoOtp != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.blueLight, borderRadius: BorderRadius.circular(6)),
          child: Text('Demo OTP: $_demoOtp',
            style: GoogleFonts.nunito(fontSize: 12,
              fontWeight: FontWeight.w700, color: AppColors.blue)),
        ),
      ],
    ])),
    const SizedBox(height: 20),
    ElevatedButton(
      onPressed: _otpCtrl.text.length == 6 ? _verifyOtp : null,
      child: const Text('Verify'),
    ),
    const SizedBox(height: 12),
    TextButton(
      onPressed: _sendOtp,
      child: Text('Resend OTP', style: GoogleFonts.nunito(
        fontSize: 13, color: AppColors.blue)),
    ),
  ]);

  // ── Step 2: Profile ────────────────────────────────────────────────────
  Widget _profileStep() => Column(children: [
    const SizedBox(height: 12),
    AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _fieldLabel('Full name'),
      TextField(controller: _nameCtrl,
        style: GoogleFonts.nunito(fontSize: 14, color: AppColors.dark),
        decoration: const InputDecoration(hintText: 'Shiva Kumar')),
      const SizedBox(height: 12),
      _fieldLabel('UPI ID'),
      TextField(controller: _upiCtrl,
        style: GoogleFonts.nunito(fontSize: 14, color: AppColors.dark),
        decoration: const InputDecoration(hintText: 'shiva@upi')),
      const SizedBox(height: 12),
      _fieldLabel('Delivery platform'),
      const SizedBox(height: 6),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 3,
        children: _platforms.map((p) => GestureDetector(
          onTap: () => setState(() => _platform = p),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _platform == p ? AppColors.blueLight : AppColors.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _platform == p ? AppColors.blue : AppColors.border,
                width: _platform == p ? 1.5 : 0.8),
            ),
            child: Text(p, style: GoogleFonts.nunito(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: _platform == p ? AppColors.blue : AppColors.mid)),
          ),
        )).toList(),
      ),
    ])),
    const SizedBox(height: 10),
    AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _fieldLabel('City'),
          const SizedBox(height: 4),
          _dropdown(_cities, _city, (v) => setState(() => _city = v!)),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _fieldLabel('Delivery zone'),
          const SizedBox(height: 4),
          _dropdown(_zones, _zone, (v) => setState(() => _zone = v!)),
        ])),
      ]),
    ])),
    const SizedBox(height: 20),
    ElevatedButton(
      onPressed: _nameCtrl.text.isNotEmpty && _upiCtrl.text.isNotEmpty ? _submitProfile : null,
      child: const Text('Continue'),
    ),
  ]);

  // ── Step 3: KYC ────────────────────────────────────────────────────────
  Widget _kycStep() => Column(children: [
    const SizedBox(height: 12),
    const InfoBanner(
      title: 'Why we need your Aadhaar',
      message: 'IRDAI regulations require identity verification before coverage can be activated. Your data is encrypted and never shared.',
      bg: AppColors.blueLight, borderColor: AppColors.blueMid,
      titleColor: AppColors.blue, messageColor: AppColors.blueMid,
      icon: Icons.info_outline,
    ),
    const SizedBox(height: 12),
    AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _fieldLabel('Aadhaar number'),
      const SizedBox(height: 6),
      TextField(
        controller: _aadhaarCtrl, keyboardType: TextInputType.number,
        maxLength: 12,
        style: GoogleFonts.nunito(fontSize: 16, letterSpacing: 3, color: AppColors.dark),
        decoration: const InputDecoration(hintText: 'XXXX XXXX XXXX', counterText: ''),
      ),
    ])),
    const SizedBox(height: 12),
    _buildKycSteps(),
    const SizedBox(height: 20),
    ElevatedButton(
      onPressed: _aadhaarCtrl.text.length == 12 ? _submitKyc : null,
      child: const Text('Verify & Continue'),
    ),
    const SizedBox(height: 8),
    Center(child: Text('Secured by DigiLocker',
      style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted))),
  ]);

  Widget _buildKycSteps() => AppCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _kycItem('Phone verified', 'OTP confirmed', PipelineStepState.done),
      _kycItem('Aadhaar e-KYC', 'Pending verification', PipelineStepState.active),
      _kycItem('Platform ID link', 'Linked via profile', PipelineStepState.pending),
      _kycItem('Data consent', 'Location & motion', PipelineStepState.pending, isLast: true),
    ],
  ));

  Widget _kycItem(String label, String sub, PipelineStepState state, {bool isLast = false}) {
    Color bg; Widget icon;
    switch (state) {
      case PipelineStepState.done:
        bg = AppColors.greenLight;
        icon = const Icon(Icons.check, size: 14, color: AppColors.green);
        break;
      case PipelineStepState.active:
        bg = AppColors.blueLight;
        icon = const SizedBox(width: 14, height: 14,
          child: CircularProgressIndicator(strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.blue)));
        break;
      case PipelineStepState.pending:
        bg = const Color(0xFFF1EFE8);
        icon = const Icon(Icons.circle, size: 8, color: Color(0xFFB4B2A9));
        break;
    }
    return Column(children: [
      Row(children: [
        Container(width: 30, height: 30,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Center(child: icon)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.nunito(fontSize: 13,
            fontWeight: FontWeight.w600,
            color: state == PipelineStepState.active ? AppColors.blue : AppColors.dark)),
          Text(sub, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted)),
        ]),
      ]),
      if (!isLast) Padding(
        padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
        child: Container(width: 1.5, height: 18, color: const Color(0xFFE8EAF0)),
      ),
    ]);
  }

  // ── Actions ────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    if (_phoneCtrl.text.length != 10) return;
    setState(() { _loading = true; });
    try {
      final otp = await context.read<AegisProvider>().requestOtp('+91${_phoneCtrl.text}');
      setState(() { _demoOtp = otp.isNotEmpty ? otp : null; _step = 1; });
    } catch (e) {
      ErrorSnack.show(context, e.toString());
    }
    setState(() { _loading = false; });
  }

  Future<void> _verifyOtp() async {
    setState(() { _loading = true; });
    try {
      await context.read<AegisProvider>().verifyOtp('+91${_phoneCtrl.text}', _otpCtrl.text);
      // Check if profile already exists
      final w = context.read<AegisProvider>().worker;
      if (w != null && w.kycComplete && w.subscribed) {
        _navToHome();
      } else if (w != null && w.kycComplete) {
        _navToPlan();
      } else {
        setState(() => _step = 2);
      }
    } catch (e) {
      ErrorSnack.show(context, e.toString());
    }
    setState(() { _loading = false; });
  }

  Future<void> _submitProfile() async {
    setState(() { _loading = true; });
    try {
      await context.read<AegisProvider>().register(
        name: _nameCtrl.text.trim(),
        phone: '+91${_phoneCtrl.text}',
        platform: _platform, city: _city, zone: _zone,
        upiId: _upiCtrl.text.trim(),
      );
      setState(() => _step = 3);
    } catch (e) {
      ErrorSnack.show(context, e.toString());
    }
    setState(() { _loading = false; });
  }

  Future<void> _submitKyc() async {
    setState(() { _loading = true; });
    try {
      await context.read<AegisProvider>().completeKyc(_aadhaarCtrl.text);
      _navToPlan();
    } catch (e) {
      ErrorSnack.show(context, e.toString());
    }
    setState(() { _loading = false; });
  }

  void _navToPlan() => Navigator.pushReplacement(
    context, MaterialPageRoute(builder: (_) => const PlanScreen()));

  void _navToHome() => Navigator.pushReplacement(
    context, MaterialPageRoute(builder: (_) => const HomeScreen()));

  Widget _fieldLabel(String t) => Text(t,
    style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted));

  Widget _dropdown(List<String> items, String value, ValueChanged<String?> onChanged) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.bg, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, isExpanded: true,
          style: GoogleFonts.nunito(fontSize: 12, color: AppColors.dark),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
}
