import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/aegis_provider.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'dashboard_tab.dart';
import 'alerts_tab.dart';
import 'coverage_tab.dart';
import 'payouts_tab.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;
  const HomeScreen({super.key, this.initialTab = 0});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _idx;
  @override void initState() { super.initState(); _idx = widget.initialTab; }

  final _tabs = const [DashboardTab(), AlertsTab(), CoverageTab(), PayoutsTab()];
  final _labels = ['Home', 'Alerts', 'Coverage', 'Payouts'];
  final _icons = [Icons.home_rounded, Icons.notifications_rounded,
                  Icons.shield_rounded, Icons.account_balance_wallet_rounded];

@override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: _tabs[_idx],
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.8))),
      child: SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(4, (i) => GestureDetector(
            onTap: () => setState(() => _idx = i),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(_icons[i], size: 22,
                  color: _idx == i ? AppColors.blue : AppColors.muted),
                const SizedBox(height: 3),
                Text(_labels[i], style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: _idx == i ? FontWeight.w700 : FontWeight.w500,
                  color: _idx == i ? AppColors.blue : AppColors.muted)),
              ]),
            ),
          )),
        ),
      )),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    floatingActionButton: Consumer<AegisProvider>(
      builder: (context, provider, child) => provider.isLoggedIn 
        ? FloatingActionButton.extended(
            heroTag: 'chatbot',
            backgroundColor: AppColors.blue,
            elevation: 8,
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.white),
            label: Text(
              'Ask Aegis',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w600,
                color: AppColors.white,
                fontSize: 14,
              ),
            ),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const ChatScreen(),
            ),
          )
        : const SizedBox(),
    ),
  );
}
