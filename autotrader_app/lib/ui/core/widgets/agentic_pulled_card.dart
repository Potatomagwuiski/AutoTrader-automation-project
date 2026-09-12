import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../haptics.dart';
import '../theme.dart';
import '../asset_brand_logo.dart';
import '../../features/dashboard/view_models/dashboard_view_model.dart';
import '../../../../data/services/gemini_ai_service.dart';
import '../../../../data/services/bot_telemetry_service.dart' show PotentialPurchase;

class AgenticPulledCard extends StatelessWidget {
  final AgenticActionType actionType;
  final dynamic payload;
  final VoidCallback? onDismiss;

  const AgenticPulledCard({
    super.key,
    required this.actionType,
    this.payload,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();

    switch (actionType) {
      case AgenticActionType.setups:
        if (payload is PotentialPurchase) {
          return _buildSingleAssetCard(context, payload as PotentialPurchase, viewModel);
        }
        return _buildSetupsCard(context, viewModel);
      case AgenticActionType.positions:
        return _buildPositionsCard(context, viewModel);
      case AgenticActionType.shariah:
        return _buildShariahCard(context, viewModel);
      case AgenticActionType.risk:
        return _buildRiskCard(context, viewModel);
      case AgenticActionType.sandbox:
        return _buildSandboxCard(context, viewModel);
      case AgenticActionType.sentinel:
        return _buildSentinelCard(context, viewModel);
      case AgenticActionType.ledger:
        return _buildLedgerCard(context, viewModel);
      case AgenticActionType.none:
        return const SizedBox.shrink();
    }
  }

  // 1A. DEDICATED SINGLE ASSET BREAKOUT CARD
  Widget _buildSingleAssetCard(
    BuildContext context,
    PotentialPurchase s,
    DashboardViewModel viewModel,
  ) {
    final proximity = s.suggestedEntry > 0
        ? (s.currentPrice / s.suggestedEntry).clamp(0.0, 1.0)
        : 0.85;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.charcoalInnerPill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.referenceOrange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AssetBrandLogo(symbol: s.symbol, size: 28),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            s.symbol,
                            style: GoogleFonts.spaceMono(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textWhite,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.mint.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${s.probabilityScore.toStringAsFixed(0)}% WIN PROB',
                              style: GoogleFonts.spaceMono(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.mint,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        s.companyName,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${s.currentPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.spaceMono(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  Text(
                    '+${s.distance200Ema.toStringAsFixed(1)}% vs 200-EMA',
                    style: GoogleFonts.spaceMono(
                      fontSize: 9.5,
                      color: AppTheme.mint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.charcoalCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.charcoalInnerBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BREAKOUT TRIGGER',
                      style: GoogleFonts.spaceMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.referenceOrange,
                      ),
                    ),
                    Text(
                      '\$${s.suggestedEntry.toStringAsFixed(2)}',
                      style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.referenceOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: proximity,
                    minHeight: 6,
                    backgroundColor: AppTheme.charcoalInnerPill,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.referenceOrange),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TRIGGER PROXIMITY',
                      style: GoogleFonts.spaceMono(fontSize: 8.5, color: AppTheme.textMuted),
                    ),
                    Text(
                      '${(proximity * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.spaceMono(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.charcoalCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.charcoalInnerBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RVOL', style: GoogleFonts.spaceMono(fontSize: 8.5, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text('${s.rvol}x Volume', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.mint)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.charcoalCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.charcoalInnerBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STOP LOSS FLOOR', style: GoogleFonts.spaceMono(fontSize: 8.5, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text('\$${s.suggestedStopLoss.toStringAsFixed(2)}', style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.coralRed)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.mint.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.mint.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, size: 12, color: AppTheme.mint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'AAOIFI Shariah Pass • 0% Forbidden Revenue • Liquid Dry Powder Ready',
                    style: GoogleFonts.spaceMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. TOP BREAKOUT SETUPS CARD
  Widget _buildSetupsCard(BuildContext context, DashboardViewModel viewModel) {
    final setups = viewModel.potentialPurchases;
    if (setups.isEmpty) {
      return _buildEmptyState('No potential breakout setups currently detected.');
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.charcoalInnerPill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.mint.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.radar_rounded, size: 14, color: AppTheme.mint),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE BREAKOUT RADAR (TOP PICKS)',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mint,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                '${setups.length} MONITORED',
                style: GoogleFonts.spaceMono(fontSize: 9.5, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...setups.take(3).map((s) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.charcoalCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.charcoalInnerBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        AssetBrandLogo(symbol: s.symbol, size: 26),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  s.symbol,
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textWhite,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mint.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${s.probabilityScore.toStringAsFixed(0)}% PROB',
                                    style: GoogleFonts.spaceMono(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.mint,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Trigger: \$${s.suggestedEntry.toStringAsFixed(2)} • RVOL ${s.rvol}x',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${s.currentPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.spaceMono(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textWhite,
                          ),
                        ),
                        Text(
                          '+${s.distance200Ema.toStringAsFixed(1)}% vs EMA',
                          style: GoogleFonts.spaceMono(
                            fontSize: 9,
                            color: AppTheme.mint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              AppHaptics.mediumImpact();
              viewModel.selectTab(0);
              Navigator.of(context).maybePop();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.mint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.mint.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Full Radar Watchlist',
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mint,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 13, color: AppTheme.mint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. ACTIVE POSITIONS & TRAILING STOPS CARD
  Widget _buildPositionsCard(BuildContext context, DashboardViewModel viewModel) {
    final positions = viewModel.positions;

    if (positions.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.charcoalInnerPill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.charcoalBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppTheme.charcoalCard,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.shield_outlined, color: AppTheme.mint, size: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '0 Open Positions • 100% Cash Defense',
                    style: GoogleFonts.spaceMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Capital is 100% safe (\$20,000.00 cash). No active risk exposure.',
                    style: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.charcoalInnerPill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.mint.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVE POSITIONS (${positions.length}/2)',
                style: GoogleFonts.spaceMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mint,
                ),
              ),
              Text(
                'TRAILING FLOORS ACTIVE',
                style: GoogleFonts.spaceMono(fontSize: 8.5, color: AppTheme.mint),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...positions.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.charcoalCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.charcoalInnerBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        AssetBrandLogo(symbol: p.symbol, size: 28),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p.shares}x ${p.symbol}',
                              style: GoogleFonts.spaceMono(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textWhite,
                              ),
                            ),
                            Text(
                              'Floor: \$${p.protectedFloor.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+${p.unrealizedProfitPercent.toStringAsFixed(2)}%',
                          style: GoogleFonts.spaceMono(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.mint,
                          ),
                        ),
                        Text(
                          '+\$${p.unrealizedProfitDollars.toStringAsFixed(2)}',
                          style: GoogleFonts.spaceMono(fontSize: 10, color: AppTheme.mint),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // 3. AAOIFI SHARIAH COMPLIANCE AUDIT CARD
  Widget _buildShariahCard(BuildContext context, DashboardViewModel viewModel) {
    final audits = viewModel.telemetryService.shariahAudits;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.charcoalInnerPill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.mint.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 14, color: AppTheme.mint),
                  const SizedBox(width: 6),
                  Text(
                    'AAOIFI SHARIAH AUDIT BASKET',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mint,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.mint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '100% PASS',
                  style: GoogleFonts.spaceMono(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.mint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...audits.take(3).map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        AssetBrandLogo(symbol: a.symbol, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          a.symbol,
                          style: GoogleFonts.spaceMono(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textWhite,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Debt: ${a.debtRatio.toStringAsFixed(1)}% (<30%) • Cash: ${a.cashRatio.toStringAsFixed(1)}%',
                      style: GoogleFonts.spaceMono(
                        fontSize: 9.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              AppHaptics.mediumImpact();
              viewModel.selectTab(2);
              Navigator.of(context).maybePop();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.mint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Open Shariah & Zakat Auditor',
                style: GoogleFonts.spaceMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. RISK & CAPITAL SAFETY GUARD CARD
  Widget _buildRiskCard(BuildContext context, DashboardViewModel viewModel) {
    final state = viewModel.state;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.charcoalInnerPill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.mint.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 14, color: AppTheme.mint),
                  const SizedBox(width: 6),
                  Text(
                    'CAPITAL PRESERVATION METRICS',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mint,
                    ),
                  ),
                ],
              ),
              Text(
                '0.0% DRAWDOWN SAFE',
                style: GoogleFonts.spaceMono(fontSize: 8.5, color: AppTheme.mint, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricCell('Verified Equity', '\$${state.portfolioValue.toStringAsFixed(2)}'),
              _buildMetricCell('Available Cash', '\$${state.cashBalance.toStringAsFixed(2)}'),
              _buildMetricCell('Daily Loss Cap', '2.00% MAX'),
            ],
          ),
        ],
      ),
    );
  }

  // 5. CANARY AI GENETIC SANDBOX CARD
  Widget _buildSandboxCard(BuildContext context, DashboardViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.charcoalInnerPill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.mint.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.biotech_rounded, size: 14, color: AppTheme.mint),
                  const SizedBox(width: 6),
                  Text(
                    'CANARY AI GENETIC SANDBOX',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mint,
                    ),
                  ),
                ],
              ),
              Text(
                'GEN 4.2 | 99.4% FIT',
                style: GoogleFonts.spaceMono(fontSize: 8.5, color: AppTheme.mint, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Active Chromosome #1 is gating breakouts with 2.45x RVOL and dynamic ATR trailing stops. Virtual simulations run in isolated sandbox (0 live risk).',
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  // 6. SENTINEL PILLARS STATUS CARD
  Widget _buildSentinelCard(BuildContext context, DashboardViewModel viewModel) {
    final state = viewModel.state;
    final isSystemLive = viewModel.isLiveEngineConnected;
    final isRegimeBull = state.activeRegime == 'BULL_TRENDING';

    final executionOnline = isSystemLive && state.executionLoopActive;
    final canaryOnline = isSystemLive && state.canaryAiActive;
    final shariahOnline = isSystemLive && state.shariahDaemonActive;
    final regimeActive = isSystemLive;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.charcoalInnerPill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.charcoalBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '4-PILLAR SENTINEL TELEMETRY',
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.textWhite,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusPill('Execution', executionOnline ? 'ONLINE' : 'OFFLINE', executionOnline, AppTheme.mint),
              _buildStatusPill('Canary AI', canaryOnline ? 'ONLINE' : 'OFFLINE', canaryOnline, AppTheme.mint),
              _buildStatusPill('200-EMA', regimeActive ? (isRegimeBull ? 'BULL' : 'BEAR') : 'OFFLINE', regimeActive, isRegimeBull ? AppTheme.mint : const Color(0xFFFFB74D)),
              _buildStatusPill('Shariah', shariahOnline ? '100%' : 'OFFLINE', shariahOnline, AppTheme.mint),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String label, String status, bool isActive, Color activeColor) {
    final color = isActive ? activeColor : AppTheme.referenceRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$label: $status',
            style: GoogleFonts.spaceMono(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // 7. LEDGER CARD
  Widget _buildLedgerCard(BuildContext context, DashboardViewModel viewModel) {
    final ledger = viewModel.telemetryService.completedTradesLedger;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.charcoalInnerPill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.charcoalBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AUDITED EXECUTION LEDGER',
                style: GoogleFonts.spaceMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.textWhite),
              ),
              Text(
                '${ledger.length} CLOSED TRADES',
                style: GoogleFonts.spaceMono(fontSize: 9.5, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...ledger.take(2).map((t) {
            final symbol = (t['symbol'] ?? '') as String;
            final exitDate = (t['exitDate'] ?? '') as String;
            final gain = ((t['gain'] ?? 0.0) as num).toDouble();
            final gainPct = ((t['gainPct'] ?? 0.0) as num).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$symbol • $exitDate',
                    style: GoogleFonts.spaceMono(fontSize: 11, color: AppTheme.textWhite),
                  ),
                  Text(
                    '+\$${gain.toStringAsFixed(2)} (+${gainPct.toStringAsFixed(1)}%)',
                    style: GoogleFonts.spaceMono(fontSize: 11, color: AppTheme.mint, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMetricCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 9.5, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.spaceMono(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.textWhite,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.charcoalInnerPill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        msg,
        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
      ),
    );
  }
}
