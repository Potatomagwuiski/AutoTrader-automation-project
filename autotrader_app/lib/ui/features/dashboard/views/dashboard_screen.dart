import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_models/dashboard_view_model.dart';
import '../../../core/widgets/gemini_companion_card.dart';
import 'big_trade_card.dart';
import 'big_potential_purchase_card.dart';
import 'portfolio_hero_card.dart';
import '../../../../data/models/bot_state.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();
    final state = viewModel.state;
    final positions = viewModel.positions;
    final potentialPurchases = viewModel.potentialPurchases;

    final hasActiveTrades = positions.isNotEmpty;

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return RefreshIndicator(
      color: AppTheme.referenceOrange,
      backgroundColor: AppTheme.charcoalCard,
      strokeWidth: 2.5,
      onRefresh: () async {
        AppHaptics.mediumImpact();
        await viewModel.refreshAllData();
        AppHaptics.successNotification();
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: bottomInset + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ================= CARD 1: PORTFOLIO HERO & MILESTONES =================
            PortfolioHeroCard(state: state),

            const SizedBox(height: 14),

            // ================= CARD 2: "TELL ME FIRST" AI EXECUTIVE BRIEFING =================
            const GeminiCompanionCard(
              title: 'Executive Cockpit Briefing',
              contextTag: 'Executive Briefing',
              presets: [],
            ),

            const SizedBox(height: 14),

            // ================= CARD 3: 4-PILLAR SENTINEL STATUS CARD =================
            _buildSentinelStatusCard(context, state),

            const SizedBox(height: 14),

            // ================= SECTION: ACTIVE TRADES =================
            if (hasActiveTrades) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Trades (${positions.length}/2)',
                      style: GoogleFonts.spaceMono(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppTheme.mint.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '100% PROTECTED',
                        style: GoogleFonts.spaceMono(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.mint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              ...positions.map((pos) => BigTradeCard(
                position: pos,
                onClosePosition: () => viewModel.closePosition(pos.symbol),
              )),

              const SizedBox(height: 16),
            ] else ...[
              // Standby / Dry Powder Status Card when 0 trades are active
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.charcoalCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.charcoalBorder),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '0 Positions',
                      style: GoogleFonts.spaceMono(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All capital in dry powder standby. Screener is actively scanning breakout radar below.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ================= SECTION: POTENTIAL BREAKOUT SETUPS =================
            if (potentialPurchases.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Potential Setups (${potentialPurchases.length})',
                      style: GoogleFonts.spaceMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.referenceOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'RADAR',
                        style: GoogleFonts.spaceMono(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.referenceOrange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              ...potentialPurchases.map(
                (setup) => BigPotentialPurchaseCard(setup: setup),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSentinelStatusCard(BuildContext context, BotState state) {
    final viewModel = context.watch<DashboardViewModel>();
    final isSystemLive = viewModel.isLiveEngineConnected;
    final isRegimeBull = state.activeRegime == 'BULL_TRENDING';

    final executionOnline = isSystemLive && state.executionLoopActive;
    final canaryOnline = isSystemLive && state.canaryAiActive;
    final shariahOnline = isSystemLive && state.shariahDaemonActive;
    final regimeActive = isSystemLive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.charcoalBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildSubsystemCell(
            title: 'Execution',
            metric: executionOnline ? 'ONLINE' : 'OFFLINE',
            isActive: executionOnline,
            activeColor: AppTheme.mint,
          ),
          _buildSubsystemCell(
            title: 'Canary AI',
            metric: canaryOnline ? 'ONLINE' : 'OFFLINE',
            isActive: canaryOnline,
            activeColor: AppTheme.mint,
          ),
          _buildSubsystemCell(
            title: '200-EMA',
            metric: regimeActive ? (isRegimeBull ? 'BULL' : 'BEAR') : 'OFFLINE',
            isActive: regimeActive,
            activeColor: isRegimeBull ? AppTheme.mint : const Color(0xFFFFB74D), // Amber for active bear defense
          ),
          _buildSubsystemCell(
            title: 'Shariah',
            metric: shariahOnline ? '100%' : 'OFFLINE',
            isActive: shariahOnline,
            activeColor: AppTheme.mint,
          ),
        ],
      ),
    );
  }

  Widget _buildSubsystemCell({
    required String title,
    required String metric,
    required bool isActive,
    Color? activeColor,
  }) {
    final dotColor = isActive ? (activeColor ?? AppTheme.mint) : AppTheme.referenceRed;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceMono(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textWhite,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            metric,
            style: GoogleFonts.spaceMono(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: dotColor,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
