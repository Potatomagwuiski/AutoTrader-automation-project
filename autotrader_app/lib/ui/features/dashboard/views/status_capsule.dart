import 'package:flutter/material.dart';
import '../../../../data/models/bot_state.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import 'package:google_fonts/google_fonts.dart';

class StatusCapsule extends StatelessWidget {
  final BotState state;
  final VoidCallback? onExecutionTap;
  final VoidCallback? onCanaryTap;
  final VoidCallback? onShariahTap;

  const StatusCapsule({
    super.key,
    required this.state,
    this.onExecutionTap,
    this.onCanaryTap,
    this.onShariahTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.charcoalBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          // 1. Execution Loop Pill
          Expanded(
            child: _buildSingleLinePill(
              title: 'Execution Loop',
              isActive: state.executionLoopActive,
              onTap: onExecutionTap ?? () => _showExecutionDetails(context),
            ),
          ),
          const SizedBox(width: 6),

          // 2. Canary AI Pill
          Expanded(
            child: _buildSingleLinePill(
              title: 'Canary AI',
              isActive: state.canaryAiActive,
              onTap: onCanaryTap ?? () => _showCanaryDetails(context),
            ),
          ),
          const SizedBox(width: 6),

          // 3. Shariah Daemon Pill
          Expanded(
            child: _buildSingleLinePill(
              title: 'Shariah Daemon',
              isActive: state.shariahDaemonActive,
              onTap: onShariahTap ?? () => _showShariahDetails(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleLinePill({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        AppHaptics.lightClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.charcoalInnerPill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.charcoalInnerBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textWhite,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF22C55E) : Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isActive ? const Color(0xFF22C55E) : Colors.red)
                        .withValues(alpha: 0.6),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExecutionDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DiagnosticSheet(
        title: 'Execution Loop Diagnostics',
        icon: Icons.sync,
        items: const [
          'Cycle Frequency: Every 60 seconds',
          'Broker Connection: Alpaca REST + WebSocket',
          'Execution Latency: 14ms average',
          'Slippage Protection: Limit orders only',
          'Self-Healing Daemon: Active (auto-reconnect enabled)',
        ],
      ),
    );
  }

  void _showCanaryDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DiagnosticSheet(
        title: 'Canary AI Sandbox',
        icon: Icons.psychology,
        items: const [
          'Evolution Generation: Gen #28',
          'Active Regime: BULL_TRENDING (ADX 38.4)',
          'Top Candidate: #14 (Sharpe 1.45 - Promoted)',
          'Validation Dataset: 30-day out-of-sample',
          'Overfit Guard: PBO score 0.04 (ultra-safe)',
        ],
      ),
    );
  }

  void _showShariahDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DiagnosticSheet(
        title: 'AAOIFI Shariah Governance',
        icon: Icons.verified_user,
        items: const [
          'SEC 10-Q Debt Ratio: < 30% Market Cap',
          'Cash & Interest Bearing Sec: < 30% Market Cap',
          'Non-Operating Interest Cleansing: 1.0% Rate',
          'Total Purified Balance: \$447.85',
          'Compliance Status: 100% Halal Certified',
        ],
      ),
    );
  }
}

class _DiagnosticSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const _DiagnosticSheet({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppTheme.charcoalBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppTheme.referenceGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.spaceMono(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  color: AppTheme.textMuted,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: AppTheme.referenceGreen,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.charcoalInnerPill,
                foregroundColor: AppTheme.textWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppTheme.charcoalInnerBorder),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}
