import 'package:flutter/material.dart';
import '../../../../data/models/bot_state.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';

class ReferenceStatusBanner extends StatelessWidget {
  final BotState state;

  const ReferenceStatusBanner({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => AppHaptics.lightClick(),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
        decoration: BoxDecoration(
          color: AppTheme.charcoalCard,
          borderRadius: BorderRadius.circular(32),
          boxShadow: AppTheme.cardShadow,
          // Simulate the abstract background from the reference
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 2.0,
            colors: [
              const Color(0xFF3A3B40),
              AppTheme.charcoalCard,
            ],
          ),
        ),
        child: const Text(
          'Autonomous mode active,\nExecution & Canary\nOnline',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppTheme.textWhite,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
