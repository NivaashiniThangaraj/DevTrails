import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'plan_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _scale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final prov = context.read<AegisProvider>();

    // Give the animation 600ms to play, then init
    await Future.delayed(const Duration(milliseconds: 600));

    // init() now returns almost instantly when no token is saved.
    // When a token exists it hits the backend with a 5s timeout.
    // Either way we move on quickly.
    await prov.init();

    if (!mounted) return;

    final w = prov.worker;
    if (w == null) {
      _go(const OnboardingScreen());
    } else if (!w.kycComplete) {
      _go(const OnboardingScreen());
    } else if (!w.subscribed) {
      _go(const PlanScreen());
    } else {
      _go(const HomeScreen());
    }
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Shield icon
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.shield,
                    color: AppColors.white, size: 48),
              ),
              const SizedBox(height: 20),
              Text('AEGIS',
                  style: GoogleFonts.nunito(
                    fontSize: 32, fontWeight: FontWeight.w800,
                    color: AppColors.white, letterSpacing: 4,
                  )),
              const SizedBox(height: 8),
              Text('Parametric income protection',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: const Color(0xFF85B7EB),
                  )),
              const SizedBox(height: 48),
              // Small, unobtrusive loading indicator
              const SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation(Color(0xFF85B7EB)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
