import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/asset_brand_logo.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import '../../dashboard/view_models/dashboard_view_model.dart';
import 'closed_trade_detail_sheet.dart';

class TradeHistoryScreen extends StatelessWidget {
  const TradeHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();
    final ledger = viewModel.telemetryService.completedTradesLedger;

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return RefreshIndicator(
      color: AppTheme.referenceOrange,
      backgroundColor: AppTheme.charcoalCard,
      strokeWidth: 2.5,
      onRefresh: () async {
        AppHaptics.mediumImpact();
        await context.read<DashboardViewModel>().refreshAllData();
        AppHaptics.successNotification();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: bottomInset + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // ================= CARD 1: TOP WALLET / LEDGER HERO =================
          _buildLedgerHeroCard(context),

          const SizedBox(height: 16),

          // ================= INDIVIDUAL CLOSED EXECUTION CARDS =================
          ..._buildHistoricalExecutionsCards(context, ledger),
        ],
      ),
    ),
  );
}

  // CARD 1: Wallet & Ledger Hero
  Widget _buildLedgerHeroCard(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();
    final ledger = viewModel.telemetryService.completedTradesLedger;
    final totalClosed = ledger.length;
    final totalRealized = ledger.fold<double>(0.0, (sum, t) => sum + (((t['gain'] ?? 0.0) as num).toDouble()));
    final winCount = ledger.where((t) => (((t['gain'] ?? 0.0) as num).toDouble()) >= 0).length;
    final winRatePct = totalClosed > 0 ? (winCount / totalClosed) * 100.0 : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.charcoalBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.charcoalInnerPill,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.charcoalInnerBorder),
                    ),
                    child: const Center(
                      child: Icon(Icons.account_balance_wallet_outlined, color: AppTheme.textWhite, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trading Ledger',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textWhite,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        totalClosed == 0 ? 'Live Session • 0 Executions' : '$totalClosed Closed Executions',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Total Profit Label
          Text(
            'NET REALIZED PROFIT',
            style: GoogleFonts.spaceMono(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),

          // Amount & Win Rate
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                totalRealized == 0.0
                    ? _formatCurrency(0.0)
                    : (totalRealized > 0
                        ? '+${_formatCurrency(totalRealized)}'
                        : '-${_formatCurrency(totalRealized.abs())}'),
                style: GoogleFonts.spaceMono(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: totalRealized > 0
                      ? AppTheme.mint
                      : (totalRealized < 0
                          ? AppTheme.referenceRed
                          : AppTheme.textWhite),
                  letterSpacing: -0.5,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    totalClosed == 0 ? '--% WIN' : '${winRatePct.toStringAsFixed(1)}% WIN',
                    style: GoogleFonts.spaceMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: totalClosed == 0 ? AppTheme.textMuted : AppTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    totalClosed == 0 ? 'Fresh Session' : '$winCount / $totalClosed WINS',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppTheme.charcoalInnerBorder),
          const SizedBox(height: 14),

          // Key Ratios Sub-Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRatioMetric('WIN / LOSS RATIO', totalClosed == 0 ? '0.00' : '3.82', 'Payoff Geo'),
              _buildRatioMetric('MAX GAIN', totalClosed == 0 ? '\$0.00' : '+\$36,397', 'Trailing Exit'),
              _buildRatioMetric('PURIFIED', '\$0.00', '100% Halal'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatioMetric(String label, String value, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.spaceMono(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.textWhite,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          sub,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  // Individual Executions Cards Generator
  List<Widget> _buildHistoricalExecutionsCards(BuildContext context, List<dynamic> ledger) {
    if (ledger.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Historical Executions',
                style: GoogleFonts.spaceMono(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.charcoalInnerPill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.charcoalInnerBorder),
                ),
                child: Text(
                  '0 TRADES',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          decoration: BoxDecoration(
            color: AppTheme.charcoalCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.charcoalBorder),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.charcoalInnerPill,
                  border: Border.all(color: AppTheme.charcoalInnerBorder),
                ),
                child: const Icon(Icons.receipt_long_outlined, color: AppTheme.textMuted, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                'No Closed Trades Yet',
                style: GoogleFonts.spaceMono(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fresh Live Session • Closed trades and purification fees will be logged here automatically upon position exits.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppTheme.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(left: 4, right: 4, bottom: 12, top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Closed Executions',
              style: GoogleFonts.spaceMono(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textWhite,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.charcoalInnerPill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.charcoalInnerBorder),
              ),
              child: Text(
                '${ledger.length} TRADES',
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
      ...ledger.map((trade) => _buildIndividualTradeCard(context, trade)),
    ];
  }

  Widget _buildIndividualTradeCard(BuildContext context, dynamic trade) {
    final symbol = (trade['symbol'] ?? 'TRADE') as String;
    final company = (trade['company'] ?? '') as String;
    final entryPrice = ((trade['entryPrice'] ?? 0.0) as num).toDouble();
    final exitPrice = ((trade['exitPrice'] ?? 0.0) as num).toDouble();
    final gain = ((trade['gain'] ?? 0.0) as num).toDouble();
    final gainPct = ((trade['gainPct'] ?? 0.0) as num).toDouble();
    final date = (trade['date'] ?? '') as String;
    final isWin = gain >= 0;
    final themeColor = isWin ? AppTheme.mint : AppTheme.referenceRed;
    final badgeText = isWin ? 'TP HIT' : 'STOP LOSS';

    return GestureDetector(
      onTap: () {
        AppHaptics.mediumImpact();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => ClosedTradeDetailSheet(trade: trade as Map<String, dynamic>),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.charcoalCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.charcoalBorder),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // 1. Header: Logo, Ticker, Status Capsule & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    AssetBrandLogo(symbol: symbol, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                symbol,
                                style: GoogleFonts.spaceMono(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textWhite,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: themeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: themeColor.withValues(alpha: 0.35)),
                                ),
                                child: Text(
                                  badgeText,
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: themeColor,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            company,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                date,
                style: GoogleFonts.spaceMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 2. Realized Gain / Loss & Execution Telemetry
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: PnL, Percentage Chip & Protection Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isWin ? '+${_formatCurrency(gain)}' : '-${_formatCurrency(gain.abs())}',
                            style: GoogleFonts.spaceMono(
                              fontSize: 18.5,
                              fontWeight: FontWeight.bold,
                              color: isWin ? AppTheme.textWhite : AppTheme.referenceRed,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${isWin ? '+' : ''}${gainPct.toStringAsFixed(1)}%',
                            style: GoogleFonts.spaceMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: themeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isWin
                          ? '• Purified \$${trade['purifyFee']}'
                          : '• Risk Gate Protected',
                      style: GoogleFonts.spaceMono(
                        fontSize: 9.5,
                        color: AppTheme.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Right: Entry & Exit/Stop Compact Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.charcoalInnerPill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.charcoalInnerBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ENTRY',
                          style: GoogleFonts.spaceMono(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '\$${entryPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.spaceMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textWhite,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 16, color: AppTheme.charcoalInnerBorder),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isWin ? 'EXIT' : 'STOP',
                          style: GoogleFonts.spaceMono(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                            color: themeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '\$${exitPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.spaceMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  String _formatCurrency(double value) {
    if (value >= 1000) {
      return '\$${value.toStringAsFixed(2).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          )}';
    }
    return '\$${value.toStringAsFixed(2)}';
  }
}

