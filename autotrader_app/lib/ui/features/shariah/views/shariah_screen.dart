import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/asset_brand_logo.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import '../../../../data/services/zakah_service.dart';
import '../../dashboard/view_models/dashboard_view_model.dart';

class ShariahScreen extends StatelessWidget {
  const ShariahScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();
    final state = viewModel.state;

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
        padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: bottomInset + 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // ================= CARD 1: PROFIT HARVEST HERO =================
          _buildSafeHarvestCard(context, state),

          const SizedBox(height: 14),

          // ================= CARD 2: PURIFICATION & ASSETS AUDIT =================
          _buildPurificationCard(context, viewModel),

          const SizedBox(height: 14),

          // ================= CARD 3: AUTOMATIC ZAKAH CALCULATOR =================
          _buildZakahCalculatorCard(context, state, viewModel),
        ],
      ),
    ),
  );
}

  // CARD 1: Harvest Advisor (Minimalist, Large Hero Design)
  Widget _buildSafeHarvestCard(BuildContext context, dynamic state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.charcoalBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Icon, Title & Verified Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.charcoalInnerPill,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.charcoalInnerBorder),
                    ),
                    child: const Center(
                      child: Icon(Icons.account_balance_outlined, color: AppTheme.textWhite, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Harvest Advisor',
                        style: GoogleFonts.inter(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textWhite,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.currentTierName,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Label
          Text(
            'RECOMMENDED SAFE HARVEST',
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),

          // Big Bold Hero Number & Minimal Monthly Target
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatCurrency(state.recommendedHarvestAmount),
                style: GoogleFonts.spaceMono(
                  fontSize: 33,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                  letterSpacing: -0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.charcoalInnerPill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.charcoalInnerBorder),
                ),
                child: Text(
                  '\$${(state.annualSalaryTarget / 12).toStringAsFixed(0)}/MO',
                  style: GoogleFonts.spaceMono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // CARD 2: Shariah Purification (Ongoing vs Ready to Pay)
  Widget _buildPurificationCard(BuildContext context, DashboardViewModel viewModel) {
    // 1. Ongoing Value (Floating on running positions)
    final openPositions = viewModel.positions;
    final double ongoingValue = openPositions.fold(
      0.0,
      (sum, p) => sum + p.charityPurificationDollars,
    );

    // 2. Done Value (Finalized on closed trades)
    final ledger = viewModel.telemetryService.completedTradesLedger;
    final List<_ClosedTradePurificationItem> closedTradeItems = [];

    for (final trade in ledger) {
      final sym = (trade['symbol'] ?? '') as String;
      final comp = (trade['company'] ?? '') as String;
      final date = (trade['date'] ?? '') as String;
      final fee = ((trade['purifyFee'] ?? 0.0) as num).toDouble();
      final gain = ((trade['gain'] ?? 0.0) as num).toDouble();
      if (sym.isNotEmpty && fee > 0) {
        final key = '${sym}_$date';
        closedTradeItems.add(
          _ClosedTradePurificationItem(
            key: key,
            symbol: sym,
            company: comp,
            date: date,
            amount: fee,
            gain: gain,
          ),
        );
      }
    }

    double donePayable = 0.0;
    for (final item in closedTradeItems) {
      if (!viewModel.isTradePaid(item.key)) {
        donePayable += item.amount;
      }
    }

    final dueTrades = closedTradeItems.where((t) => !viewModel.isTradePaid(t.key)).toList();
    final paidTrades = closedTradeItems.where((t) => viewModel.isTradePaid(t.key)).toList();

    List<_ClosedTradePurificationItem> displayTrades;
    if (viewModel.purificationFilterIndex == 1) {
      displayTrades = dueTrades;
    } else if (viewModel.purificationFilterIndex == 2) {
      displayTrades = paidTrades;
    } else {
      displayTrades = closedTradeItems;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.charcoalBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.charcoalInnerPill,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.charcoalInnerBorder),
                    ),
                    child: const Center(
                      child: Icon(Icons.volunteer_activism_outlined, size: 16, color: AppTheme.textWhite),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Purification Manager',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textWhite,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.charcoalInnerPill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.charcoalInnerBorder),
                ),
                child: Text(
                  '1% AUTO',
                  style: GoogleFonts.spaceMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // TWO ORGANIZED FLOATING METRICS (No nested boxes)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Ready to Pay (Done & Actionable)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.referenceOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'READY TO PAY',
                        style: GoogleFonts.spaceMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.referenceOrange,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(donePayable),
                    style: GoogleFonts.spaceMono(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Closed trades done',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),

              // 2. Ongoing Value (Floating Live in Market)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 10.5, color: AppTheme.textMuted),
                      const SizedBox(width: 5),
                      Text(
                        'ONGOING',
                        style: GoogleFonts.spaceMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(ongoingValue),
                    style: GoogleFonts.spaceMono(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Running in market',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Simple Tabs: Ready to Pay (Due) | Already Paid | All
          Row(
            children: [
              _buildFilterPill(
                title: 'READY TO PAY (${dueTrades.length})',
                isSelected: viewModel.purificationFilterIndex == 1,
                onTap: () => viewModel.setPurificationFilter(1),
                activeColor: AppTheme.referenceOrange,
              ),
              const SizedBox(width: 6),
              _buildFilterPill(
                title: 'PAID (${paidTrades.length})',
                isSelected: viewModel.purificationFilterIndex == 2,
                onTap: () => viewModel.setPurificationFilter(2),
                activeColor: AppTheme.referenceOrange,
              ),
              const SizedBox(width: 6),
              _buildFilterPill(
                title: 'ALL (${closedTradeItems.length})',
                isSelected: viewModel.purificationFilterIndex == 0,
                onTap: () => viewModel.setPurificationFilter(0),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Container(height: 1, color: AppTheme.charcoalBorder),
          const SizedBox(height: 6),

          // List of Closed Trades or Empty State
          if (displayTrades.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 30,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No trades in this category',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Purification records will appear as trades settle',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...displayTrades.map((item) {
              final isPaid = viewModel.isTradePaid(item.key);
              return _buildClosedTradePurificationRow(
                context: context,
                item: item,
                isPaid: isPaid,
                onTap: () => _showClosedTradeSettlementDialog(context, item, isPaid, viewModel),
              );
            }),
        ],
      ),
    );
  }

  // Row for Closed Trades (Payable & Settled) - Large & High Visibility
  Widget _buildClosedTradePurificationRow({
    required BuildContext context,
    required _ClosedTradePurificationItem item,
    required bool isPaid,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          AssetBrandLogo(symbol: item.symbol, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.symbol,
                      style: GoogleFonts.spaceMono(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${item.date}',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.company,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(item.amount),
                  style: GoogleFonts.spaceMono(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? AppTheme.mint.withValues(alpha: 0.15)
                        : AppTheme.referenceOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPaid
                          ? AppTheme.mint.withValues(alpha: 0.4)
                          : AppTheme.referenceOrange.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                        size: 11.5,
                        color: isPaid ? AppTheme.mint : AppTheme.referenceOrange,
                      ),
                      const SizedBox(width: 4.5),
                      Text(
                        isPaid ? 'PAID' : 'PAY NOW',
                        style: GoogleFonts.spaceMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPaid ? AppTheme.mint : AppTheme.referenceOrange,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    Color activeColor = AppTheme.textWhite,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.charcoalInnerPill : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.textWhite.withValues(alpha: 0.8) : Colors.transparent,
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          title,
          style: GoogleFonts.spaceMono(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTheme.textWhite : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  // Dialog when tapping a closed trade settlement
  void _showClosedTradeSettlementDialog(
    BuildContext context,
    _ClosedTradePurificationItem item,
    bool isCurrentlyPaid,
    DashboardViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.charcoalCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.charcoalBorder),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    AssetBrandLogo(symbol: item.symbol, size: 40),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.symbol} Settlement',
                          style: GoogleFonts.spaceMono(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textWhite,
                          ),
                        ),
                        Text(
                          'Closed ${item.date} • +${_formatCurrency(item.gain)} Realized Profit',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.charcoalInnerPill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.charcoalInnerBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1% Cleansing Fee',
                        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                      ),
                      Text(
                        _formatCurrency(item.amount),
                        style: GoogleFonts.spaceMono(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textWhite,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isCurrentlyPaid
                      ? 'This closed trade obligation is marked as Paid / Cleansed. Reverting will move \$${item.amount.toStringAsFixed(2)} back to your Due balance.'
                      : 'Confirm that you have disbursed or donated this 1.0% statutory purification amount to charity.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textMuted, height: 1.4),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.charcoalInnerPill,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.charcoalInnerBorder),
                          ),
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.spaceMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textWhite,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          viewModel.toggleTradePurification(item.key);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isCurrentlyPaid
                                ? AppTheme.referenceOrange.withValues(alpha: 0.15)
                                : AppTheme.mint.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isCurrentlyPaid
                                  ? AppTheme.referenceOrange.withValues(alpha: 0.4)
                                  : AppTheme.mint.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              isCurrentlyPaid ? 'Revert to Due' : 'Confirm Paid',
                              style: GoogleFonts.spaceMono(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isCurrentlyPaid ? AppTheme.referenceOrange : AppTheme.mint,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================= CARD 3: AUTOMATIC ZAKAH CALCULATOR =================
  Widget _buildZakahCalculatorCard(BuildContext context, dynamic state, DashboardViewModel viewModel) {
    final zakahService = context.watch<ZakahService>();
    final double portfolioVal = (state.portfolioValue as num?)?.toDouble() ?? 20000.0;
    final double cashBal = (state.cashBalance as num?)?.toDouble() ?? 20000.0;
    final double positionsMktVal = (viewModel.positions).fold<double>(
      0.0,
      (sum, p) => sum + p.currentMarketValue,
    );

    final result = zakahService.calculate(
      portfolioValue: portfolioVal,
      cashBalance: cashBal,
      positionsMarketValue: positionsMktVal,
    );

    final totalPaidHistorical = zakahService.payments.fold<double>(
      0.0,
      (sum, p) => sum + p.amount,
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.charcoalBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Icon, Title & Status Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.charcoalInnerPill,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.charcoalInnerBorder),
                      ),
                      child: const Center(
                        child: Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppTheme.textWhite),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zakah Calculator',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textWhite,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'AAOIFI Standard No. 35',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: AppTheme.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.charcoalInnerPill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.charcoalInnerBorder),
                ),
                child: Text(
                  result.calendar == ZakahCalendar.lunar ? '2.5% AUTO' : '2.577% SOLAR',
                  style: GoogleFonts.spaceMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Floating Hero Metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Estimated Zakah Due
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.referenceOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ESTIMATED ZAKAH DUE',
                        style: GoogleFonts.spaceMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.referenceOrange,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(result.estimatedZakahDue),
                    style: GoogleFonts.spaceMono(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    result.methodology == ZakahMethodology.activeTrading
                        ? 'Urud al-Tijarah (100% Equity)'
                        : '25% Working Capital Proxy',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),

              // 2. Hawl Days Countdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_repeat_rounded, size: 10.5, color: AppTheme.textMuted),
                      const SizedBox(width: 5),
                      Text(
                        'HAWL CYCLE',
                        style: GoogleFonts.spaceMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${result.daysRemaining}d left',
                    style: GoogleFonts.spaceMono(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${result.calendar == ZakahCalendar.lunar ? 'Lunar (354d)' : 'Solar (365d)'} cycle',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Hawl Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: result.hawlProgress,
              minHeight: 4,
              backgroundColor: AppTheme.charcoalInnerPill,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.referenceOrange),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Day ${result.daysElapsed} of ${result.hawlCycleDays} elapsed',
                style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
              ),
              Text(
                'Anniversary in ${result.daysRemaining} days',
                style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Container(height: 1, color: AppTheme.charcoalBorder),
          const SizedBox(height: 16),

          // Detailed Breakdown Metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildZakahStatTile(
                label: 'Zakatable Wealth',
                value: _formatCurrency(result.zakatableEquity),
                detail: 'Liquid Capital',
              ),
              _buildZakahStatTile(
                label: 'Gold Nisab (85g)',
                value: _formatCurrency(result.nisabThreshold),
                detail: result.isNisabMet ? 'Passed ✓' : 'Below',
                highlightText: result.isNisabMet,
              ),
              _buildZakahStatTile(
                label: 'Total Paid Log',
                value: _formatCurrency(totalPaidHistorical),
                detail: '${zakahService.payments.length} records',
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Action Buttons: AAOIFI Standards | History | Record Payment
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppTheme.charcoalInnerPill,
                    foregroundColor: AppTheme.textWhite,
                    side: const BorderSide(color: AppTheme.charcoalInnerBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    AppHaptics.lightClick();
                    _showAaoifiStandardSheet(context);
                  },
                  child: Text(
                    'AAOIFI Rule',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textWhite),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppTheme.charcoalInnerPill,
                    foregroundColor: AppTheme.textWhite,
                    side: const BorderSide(color: AppTheme.charcoalInnerBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    AppHaptics.lightClick();
                    _showZakahHistorySheet(context, zakahService);
                  },
                  child: Text(
                    'History (${zakahService.payments.length})',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textWhite),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppTheme.charcoalInnerPill,
                    foregroundColor: AppTheme.textWhite,
                    side: const BorderSide(color: AppTheme.charcoalInnerBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    AppHaptics.mediumImpact();
                    _showRecordZakahPaymentDialog(context, zakahService, result);
                  },
                  child: Text(
                    'Record Pay',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textWhite,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZakahStatTile({
    required String label,
    required String value,
    required String detail,
    bool highlightText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 2),
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
          detail,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            fontWeight: highlightText ? FontWeight.w600 : FontWeight.normal,
            color: highlightText ? AppTheme.textWhite : AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  // MODAL 1: AAOIFI Standard No. 35 Educational Sheet
  void _showAaoifiStandardSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: const BoxDecoration(
            color: AppTheme.charcoalCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppTheme.charcoalBorder)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.charcoalBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.charcoalInnerPill,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.charcoalInnerBorder),
                          ),
                          child: const Icon(Icons.account_balance_rounded, color: AppTheme.textWhite, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AAOIFI Standard No. 35',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textWhite,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Zakah on Stocks & Trading Portfolios',
                                style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.charcoalInnerPill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.charcoalInnerBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Active Swing Trading (Urud al-Tijarah):',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.referenceOrange),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Because AutoTrader actively buys and sells stocks with the intention of short-to-medium term resale capital gains, shares are classified as "Trade Merchandise". Zakah is due on the full market value of shares plus liquid cash at 2.50% (Lunar Hawl) or 2.577% (Solar Year).',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textWhite, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '2. Nisab Threshold (85g Gold):',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.referenceOrange),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Zakah only becomes obligatory if total zakatable wealth equals or exceeds the Nisab value (~85 grams of Gold, approx \$7,000 USD benchmark) throughout the Hawl period.',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textWhite, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '3. Purification vs. Zakah:',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.referenceOrange),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Purification (1% on non-operating income) cleanses non-compliant interest from companies and must be given to general charity WITHOUT reward intention. Zakah is an obligatory pillar of Islam (2.5%) payable strictly to designated Quranic beneficiaries (Surah At-Tawbah 9:60).',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textWhite, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.charcoalInnerPill,
                  foregroundColor: AppTheme.textWhite,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: const BorderSide(color: AppTheme.charcoalInnerBorder),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text('Understood', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }

  // MODAL 2: Record Zakah Payment Dialog
  void _showRecordZakahPaymentDialog(
    BuildContext context,
    ZakahService zakahService,
    ZakahCalculationResult result,
  ) {
    final amountCtrl = TextEditingController(text: result.estimatedZakahDue.toStringAsFixed(2));
    final noteCtrl = TextEditingController(text: 'Annual Zakah Hawl Disbursal');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: AppTheme.charcoalCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppTheme.charcoalBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.referenceOrange.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.referenceOrange.withValues(alpha: 0.35)),
                      ),
                      child: const Icon(Icons.volunteer_activism_rounded, color: AppTheme.referenceOrange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Record Zakah Payment',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textWhite,
                            ),
                          ),
                          Text(
                            'Disburse and reset annual Hawl',
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'PAYMENT AMOUNT (USD)',
                  style: GoogleFonts.spaceMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.spaceMono(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textWhite),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.attach_money_rounded, color: AppTheme.referenceOrange),
                    filled: true,
                    fillColor: AppTheme.charcoalInnerPill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.charcoalInnerBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.charcoalInnerBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'RECIPIENT / ORGANIZATION / NOTES',
                  style: GoogleFonts.spaceMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: noteCtrl,
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textWhite),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.charcoalInnerPill,
                    hintText: 'e.g. Local Zakah Foundation, Direct Aid',
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.charcoalInnerBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.charcoalInnerBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Recording this payment will archive the transaction and reset your Hawl cycle counter to Day 0.',
                  style: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textMuted, height: 1.3),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.charcoalInnerPill,
                          foregroundColor: AppTheme.textWhite,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: AppTheme.charcoalInnerBorder),
                        ),
                        onPressed: () async {
                          final parsedAmount = double.tryParse(amountCtrl.text) ?? result.estimatedZakahDue;
                          await zakahService.recordPayment(
                            amount: parsedAmount,
                            recipientNote: noteCtrl.text,
                          );
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                            AppHaptics.successNotification();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppTheme.charcoalCard,
                                content: Text(
                                  'Zakah payment of \$${parsedAmount.toStringAsFixed(2)} recorded and Hawl reset!',
                                  style: GoogleFonts.inter(color: AppTheme.referenceOrange),
                                ),
                              ),
                            );
                          }
                        },
                        child: Text(
                          'Confirm & Reset Hawl',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textWhite),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // MODAL 3: Zakah Historical Payments Ledger Sheet
  void _showZakahHistorySheet(BuildContext context, ZakahService zakahService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final payments = zakahService.payments;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: const BoxDecoration(
            color: AppTheme.charcoalCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppTheme.charcoalBorder)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.charcoalBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.charcoalInnerPill,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.charcoalInnerBorder),
                          ),
                          child: const Icon(Icons.history_edu_rounded, color: AppTheme.textWhite, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Zakah Payment Ledger',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textWhite,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${payments.length} verified disbursals recorded',
                                style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No past Zakah payments recorded yet.',
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12.5),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: payments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final item = payments[idx];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.charcoalInnerPill,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.charcoalInnerBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.recipientNote,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textWhite,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.timestamp.year}-${item.timestamp.month.toString().padLeft(2, '0')}-${item.timestamp.day.toString().padLeft(2, '0')} • ${item.calendar.toUpperCase()}',
                                    style: GoogleFonts.spaceMono(
                                      fontSize: 10,
                                      color: AppTheme.textMuted,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _formatCurrency(item.amount),
                              style: GoogleFonts.spaceMono(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textWhite,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.charcoalInnerPill,
                  foregroundColor: AppTheme.textWhite,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: const BorderSide(color: AppTheme.charcoalInnerBorder),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close Ledger', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
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

class _ClosedTradePurificationItem {
  final String key;
  final String symbol;
  final String company;
  final String date;
  final double amount;
  final double gain;

  _ClosedTradePurificationItem({
    required this.key,
    required this.symbol,
    required this.company,
    required this.date,
    required this.amount,
    required this.gain,
  });
}


