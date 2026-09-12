import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'data/services/bot_notification_service.dart';
import 'data/services/bot_telemetry_service.dart';
import 'data/services/gemini_ai_service.dart';
import 'data/services/live_bot_service.dart';
import 'data/services/zakah_service.dart';
import 'ui/core/haptics.dart';
import 'ui/core/theme.dart';
import 'ui/features/ai_brain/views/ai_brain_screen.dart';
import 'ui/features/analytics/views/analytics_screen.dart';
import 'ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'ui/features/dashboard/views/dashboard_screen.dart';
import 'ui/features/shariah/views/shariah_screen.dart';
import 'ui/features/trades/views/trade_history_screen.dart';
import 'ui/features/ai_brain/views/gemini_agentic_workspace_sheet.dart';
import 'ui/features/dashboard/views/ai_executive_briefing_card.dart' show GeminiLogoPainter;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.appBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize live server connection and auto-discovery
  await LiveBotService().init();

  final geminiService = GeminiAiService();
  await geminiService.init();

  runApp(AutoTraderApp(geminiService: geminiService));
}

class AutoTraderApp extends StatelessWidget {
  final GeminiAiService? geminiService;
  const AutoTraderApp({super.key, this.geminiService});

  @override
  Widget build(BuildContext context) {
    final activeGeminiService = geminiService ?? GeminiAiService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BotNotificationService>(
          create: (_) => BotNotificationService(),
        ),
        Provider<BotTelemetryService>(
          create: (_) => BotTelemetryService(),
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProvider<GeminiAiService>.value(
          value: activeGeminiService,
        ),
        ChangeNotifierProvider<ZakahService>(
          create: (_) => ZakahService(),
        ),
        ChangeNotifierProvider<DashboardViewModel>(
          create: (context) => DashboardViewModel(
            context.read<BotTelemetryService>(),
            geminiService: activeGeminiService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'AutoTrader AI Cockpit',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainCockpitScaffold(),
      ),
    );
  }
}

class MainCockpitScaffold extends StatelessWidget {
  const MainCockpitScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();

    final screens = const [
      DashboardScreen(),      // 0: Home / Cockpit
      TradeHistoryScreen(),   // 1: Wallet / Ledger
      ShariahScreen(),        // 2: Harvest / Wealth (center swap)
      AnalyticsScreen(),      // 3: Analytics
      AiBrainScreen(),        // 4: Settings / Brain
    ];

    return Scaffold(
      backgroundColor: AppTheme.appBackground,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: viewModel.selectedTabIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: _buildFloatingDock(context, viewModel),
    );
  }

  // Floating dock navigation with contained Gemini Partner button anchored right above it
  Widget _buildFloatingDock(BuildContext context, DashboardViewModel viewModel) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Contained static Gemini Partner button (docked right above nav bar)
        const Padding(
          padding: EdgeInsets.only(right: 24, bottom: 6),
          child: ContainedGeminiPartnerButton(),
        ),
        // Floating Nav Dock Capsule
        Container(
          color: Colors.transparent,
          padding: EdgeInsets.only(
            left: 14,
            right: 14,
            top: 0,
            bottom: bottomInset > 0 ? bottomInset : 12,
          ),
          child: Container(
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.charcoalCard,
              borderRadius: BorderRadius.circular(33),
              border: Border.all(color: AppTheme.charcoalBorder, width: 1),
              boxShadow: AppTheme.dockShadow,
            ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 1. Home
              Expanded(
                child: _buildDockIcon(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isActive: viewModel.selectedTabIndex == 0,
                  onTap: () {
                    AppHaptics.lightClick();
                    viewModel.selectTab(0);
                  },
                ),
              ),

              // 2. Wallet
              Expanded(
                child: _buildDockIcon(
                  icon: Icons.account_balance_wallet_outlined,
                  activeIcon: Icons.account_balance_wallet_rounded,
                  label: 'Wallet',
                  isActive: viewModel.selectedTabIndex == 1,
                  onTap: () {
                    AppHaptics.lightClick();
                    viewModel.selectTab(1);
                  },
                ),
              ),

              // 3. Center Glowing Orange Action Button (matching reference)
              GestureDetector(
                onTap: () {
                  AppHaptics.mediumImpact();
                  viewModel.selectTab(2);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.referenceOrange,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.referenceOrange.withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.sync_alt_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),

              // 4. Analytics
              Expanded(
                child: _buildDockIcon(
                  icon: Icons.insights_outlined,
                  activeIcon: Icons.insights_rounded,
                  label: 'Analytics',
                  isActive: viewModel.selectedTabIndex == 3,
                  onTap: () {
                    AppHaptics.lightClick();
                    viewModel.selectTab(3);
                  },
                ),
              ),

              // 5. Settings
              Expanded(
                child: _buildDockIcon(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Settings',
                  isActive: viewModel.selectedTabIndex == 4,
                  onTap: () {
                    AppHaptics.lightClick();
                    viewModel.selectTab(4);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

  Widget _buildDockIcon({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 66,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppTheme.textWhite : AppTheme.textMuted,
              size: 23,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppTheme.textWhite : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContainedGeminiPartnerButton extends StatelessWidget {
  const ContainedGeminiPartnerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.mediumImpact();
        GeminiAgenticWorkspaceSheet.show(context);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: CustomPaint(
          size: const Size(26, 26),
          painter: GeminiLogoPainter(
            rotationAngle: 0.0,
            shimmerAngle: 0.0,
            pulseScale: 1.0,
            splitFactor: 0.0,
            isThinking: false,
          ),
        ),
      ),
    );
  }
}
