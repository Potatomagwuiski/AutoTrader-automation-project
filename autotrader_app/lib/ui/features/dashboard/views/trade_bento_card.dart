import 'package:flutter/material.dart';
import '../../../../data/models/position.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import 'trade_detail_sheet.dart';
import 'package:google_fonts/google_fonts.dart';

class TradeBentoCard extends StatefulWidget {
  final Position position;
  final VoidCallback? onClosePosition;

  const TradeBentoCard({
    super.key,
    required this.position,
    this.onClosePosition,
  });

  @override
  State<TradeBentoCard> createState() => _TradeBentoCardState();
}

class _TradeBentoCardState extends State<TradeBentoCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final pos = widget.position;
    final isProfit = pos.currentGainDollars >= 0;
    final gainColor = isProfit ? AppTheme.mint : AppTheme.referenceRed;

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.charcoalCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.charcoalBorder, width: 1),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: () {
              AppHaptics.mediumImpact();
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (ctx) => TradeDetailSheet(
                  position: pos,
                  onClosePosition: widget.onClosePosition ?? () {},
                ),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Top Header Row: Symbol + Company on left, Live Price + P&L on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                pos.symbol,
                                style: GoogleFonts.spaceMono(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textWhite,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.mintDarkBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.mintDarkBorder),
                                ),
                                child: Text(
                                  'LONG 48.5%',
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.mint,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            pos.companyName,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${pos.livePrice.toStringAsFixed(2)}',
                            style: GoogleFonts.spaceMono(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textWhite,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isProfit ? AppTheme.mintDarkBg : AppTheme.charcoalInnerPill,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${isProfit ? '+' : ''}${pos.unrealizedGainPercent.toStringAsFixed(1)}% (+\$${pos.currentGainDollars.toStringAsFixed(0)})',
                              style: GoogleFonts.spaceMono(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: gainColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 2. Clean Mini Sparkline Area Chart
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: CustomPaint(
                        size: const Size(double.infinity, 54),
                        painter: _CleanSparklinePainter(
                          prices: pos.priceNodes,
                          lineColor: gainColor,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. Bottom Metrics Bento Grid: Entry | Stop Floor | Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.charcoalInnerPill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.charcoalBorder.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricCol('ENTRY', '\$${pos.entryPrice.toStringAsFixed(2)}', AppTheme.textWhite),
                        Container(width: 1, height: 24, color: AppTheme.charcoalBorder),
                        _buildMetricCol('STOP FLOOR', '\$${pos.protectedFloor.toStringAsFixed(2)}', const Color(0xFF5EEAD4)),
                        Container(width: 1, height: 24, color: AppTheme.charcoalBorder),
                        _buildMetricCol('LOCKED GAIN', '+${pos.lockedGainPercent.toStringAsFixed(0)}% 🔒', AppTheme.mint),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.spaceMono(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _CleanSparklinePainter extends CustomPainter {
  final List<double> prices;
  final Color lineColor;

  _CleanSparklinePainter({
    required this.prices,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;

    final min = prices.reduce((a, b) => a < b ? a : b);
    final max = prices.reduce((a, b) => a > b ? a : b);
    final range = (max - min) == 0 ? 1.0 : (max - min);

    final double padY = 4.0;
    final double h = size.height - (padY * 2);
    final double stepX = size.width / (prices.length - 1);

    final List<Offset> points = [];
    for (int i = 0; i < prices.length; i++) {
      final normY = (prices[i] - min) / range;
      final x = i * stepX;
      final y = size.height - padY - (normY * h);
      points.add(Offset(x, y));
    }

    // 1. Draw smooth gradient fill below line
    final Path fillPath = Path();
    fillPath.moveTo(points.first.dx, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      fillPath.lineTo(points[i].dx, points[i].dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.25),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // 2. Draw smooth stroke line
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path strokePath = Path();
    strokePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      strokePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(strokePath, strokePaint);

    // 3. Draw pulsating endpoint dot
    final lastPt = points.last;
    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lastPt, 6.0, glowPaint);

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lastPt, 3.5, dotPaint);

    final corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lastPt, 1.5, corePaint);
  }

  @override
  bool shouldRepaint(covariant _CleanSparklinePainter oldDelegate) =>
      oldDelegate.prices != prices || oldDelegate.lineColor != lineColor;
}
