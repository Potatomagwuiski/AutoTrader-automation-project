import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/bot_state.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';

class ReferenceHeroCard extends StatelessWidget {
  final BotState state;

  const ReferenceHeroCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '\$');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar, Name/Subtitle, Bell Icon
          Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.charcoalInnerPill,
                  image: DecorationImage(
                    image: NetworkImage('https://i.pravatar.cc/150?img=11'), // Placeholder matching ref
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Name & Subtitle
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AutoTrader AI',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'alpaca_linked_live',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bell Icon
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.charcoalInnerPill,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: AppTheme.textWhite,
                      size: 20,
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.referenceRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Middle Row: Portfolio Label, Balance, Returns
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PORTFOLIO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormatter.format(state.portfolioValue),
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textWhite,
                      letterSpacing: -1.5,
                    ),
                  ),
                ],
              ),
              Builder(
                builder: (context) {
                  final isPositive = state.totalGainDollars > 0.001;
                  final isNegative = state.totalGainDollars < -0.001;
                  final gainColor = isPositive
                      ? AppTheme.mint
                      : (isNegative ? AppTheme.referenceRed : AppTheme.textMuted);
                  final gainSign = isPositive ? '+' : (isNegative ? '-' : '');
                  final dollarSign = isPositive ? '+\$' : (isNegative ? '-\$' : '\$');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$gainSign${state.totalGainPercent.abs().toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: gainColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dollarSign${NumberFormat("#,##0.00").format(state.totalGainDollars.abs())}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isNegative ? AppTheme.referenceRed.withValues(alpha: 0.85) : AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Bottom Row: Action Pills
          Row(
            children: [
              Expanded(
                child: _buildActionPill(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Withdraw',
                  onTap: () => AppHaptics.lightClick(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionPill(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Deposit',
                  onTap: () => AppHaptics.lightClick(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.charcoalInnerPill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppTheme.textWhite),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
