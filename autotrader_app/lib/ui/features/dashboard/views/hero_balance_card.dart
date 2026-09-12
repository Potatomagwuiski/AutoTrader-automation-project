import 'package:flutter/material.dart';
import '../../../../data/models/bot_state.dart';
import '../../../core/theme.dart';

class HeroBalanceCard extends StatelessWidget {
  final BotState state;

  const HeroBalanceCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.charcoalBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Profile Avatar + Alpaca Linked
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
                child: const Center(
                  child: Text('👨🏻', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Alpaca Linked',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 2. Huge Balance Number
          const Text(
            '\$49,785.35',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              color: AppTheme.textWhite,
              letterSpacing: -1.0,
            ),
          ),

          const SizedBox(height: 4),

          // 3. Green Gain Subtitle (+895.71% (+$44,785))
          const Text(
            '+895.71% (+\$44,785)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4ADE80), // Bright green matching image
            ),
          ),
        ],
      ),
    );
  }
}
