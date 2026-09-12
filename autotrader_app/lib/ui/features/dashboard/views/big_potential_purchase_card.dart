import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../data/services/bot_telemetry_service.dart';
import '../../../core/asset_brand_logo.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import 'setup_detail_sheet.dart';

class BigPotentialPurchaseCard extends StatelessWidget {
  final PotentialPurchase setup;

  const BigPotentialPurchaseCard({super.key, required this.setup});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.mediumImpact();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => SetupDetailSheet(setup: setup),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.charcoalCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.charcoalBorder),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Brand Logo, Symbol & Rank # (Left) | Price & Likelihood % (Right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      AssetBrandLogo(symbol: setup.symbol, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  setup.symbol,
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 17.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textWhite,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '#${setup.rank}',
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              setup.companyName,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
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
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${setup.currentPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.spaceMono(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${setup.probabilityScore.toStringAsFixed(0)}% Likelihood',
                      style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),
            Container(height: 1, color: AppTheme.charcoalBorder),
            const SizedBox(height: 12),

            // Row 2: Four Clean Telemetry Columns: [ TRIGGER ] [ STOP LOSS ] [ RVOL ] [ 200-EMA ]
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTelemetryColumn(
                  label: 'TRIGGER',
                  value: '\$${setup.suggestedEntry.toStringAsFixed(2)}',
                  valueColor: AppTheme.mint,
                ),
                _buildTelemetryColumn(
                  label: 'STOP LOSS',
                  value: '\$${setup.suggestedStopLoss.toStringAsFixed(2)}',
                  valueColor: AppTheme.referenceRed,
                ),
                _buildTelemetryColumn(
                  label: 'RVOL',
                  value: '${setup.rvol.toStringAsFixed(1)}x',
                  valueColor: AppTheme.textWhite,
                ),
                _buildTelemetryColumn(
                  label: '200-EMA',
                  value: '+${setup.distance200Ema.toStringAsFixed(1)}%',
                  valueColor: AppTheme.mint,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryColumn({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.spaceMono(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
