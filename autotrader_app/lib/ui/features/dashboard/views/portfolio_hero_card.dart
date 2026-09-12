import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/bot_state.dart';
import '../../../../data/services/bot_notification_service.dart';
import '../../../../data/services/live_bot_service.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import 'notifications_sheet.dart';

class PortfolioHeroCard extends StatelessWidget {
  final BotState state;

  const PortfolioHeroCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final isPositive = state.totalGainDollars > 0.001;
    final isNegative = state.totalGainDollars < -0.001;
    final gainColor = isPositive
        ? AppTheme.mint
        : (isNegative ? AppTheme.referenceRed : AppTheme.textMuted);
    final gainSign = isPositive ? '+' : (isNegative ? '-' : '');
    final dollarSign = isPositive ? '+\$' : (isNegative ? '-\$' : '\$');
    final notifService = context.watch<BotNotificationService>();
    final unreadCount = notifService.unreadCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.charcoalBorder, width: 1),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Header Row: Bot Live Indicator & Name + Notification Center
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.charcoalInnerPill,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.charcoalInnerBorder),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logos/trading_cockpit_mark.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.show_chart_rounded, size: 20, color: AppTheme.mint),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Trading Cockpit',
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textWhite,
                          ),
                        ),
                        const SizedBox(width: 6),
                        StreamBuilder<bool>(
                          stream: LiveBotService().connectionStatusStream,
                          initialData: LiveBotService().isConnected,
                          builder: (context, snapshot) {
                            final isOnline = snapshot.data ?? false;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? AppTheme.mint.withValues(alpha: 0.15)
                                    : AppTheme.charcoalInnerPill,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isOnline
                                      ? AppTheme.mint.withValues(alpha: 0.3)
                                      : AppTheme.charcoalInnerBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: isOnline ? AppTheme.mint : AppTheme.textMuted,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isOnline ? 'LIVE' : 'OFFLINE',
                                    style: GoogleFonts.spaceMono(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: isOnline ? AppTheme.mint : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Notification Center Bell Button
              GestureDetector(
                onTap: () {
                  AppHaptics.mediumImpact();
                  NotificationsSheet.show(context);
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.charcoalInnerPill,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: unreadCount > 0
                          ? AppTheme.textWhite.withValues(alpha: 0.6)
                          : AppTheme.charcoalInnerBorder,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        unreadCount > 0
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        color: unreadCount > 0 ? AppTheme.textWhite : AppTheme.textMuted,
                        size: 19,
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.textWhite,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 2. PORTFOLIO label
          Text(
            'PORTFOLIO',
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),

          // 3. Amount & Percentage Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormatter.format(state.portfolioValue),
                style: GoogleFonts.spaceMono(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                  letterSpacing: -0.5,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$gainSign${state.totalGainPercent.abs().toStringAsFixed(2)}%',
                    style: GoogleFonts.spaceMono(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: gainColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dollarSign${NumberFormat("#,##0.00").format(state.totalGainDollars.abs())}',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10.5,
                      color: isNegative ? AppTheme.referenceRed.withValues(alpha: 0.85) : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

