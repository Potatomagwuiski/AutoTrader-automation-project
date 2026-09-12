import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/position.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import 'trade_detail_sheet.dart';

class BigPositionCard extends StatelessWidget {
  final Position position;
  final VoidCallback onClosePosition;

  const BigPositionCard({
    super.key,
    required this.position,
    required this.onClosePosition,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = position.unrealizedGainPercent >= 0;
    final gainColor = isProfit ? AppTheme.mint : AppTheme.referenceRed;
    final dollarFormatter = NumberFormat('#,##0', 'en_US');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.charcoalBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Header: Symbol Badge, Name, Live Price & Gain %
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular Asset Badge (48x48)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.charcoalInnerPill,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.charcoalInnerBorder),
                ),
                child: Center(
                  child: Text(
                    position.symbol.substring(0, position.symbol.length > 2 ? 2 : position.symbol.length),
                    style: GoogleFonts.spaceMono(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Symbol & Company
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          position.symbol,
                          style: GoogleFonts.spaceMono(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textWhite,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppTheme.mint.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: GoogleFonts.spaceMono(
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.mint,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      position.companyName,
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

              // Live Price & P&L
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${position.livePrice.toStringAsFixed(2)}',
                    style: GoogleFonts.spaceMono(
                      fontSize: 19.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+${dollarFormatter.format(position.unrealizedProfitDollars)}',
                        style: GoogleFonts.spaceMono(
                          fontSize: 11.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${isProfit ? '+' : ''}${position.unrealizedGainPercent.toStringAsFixed(2)}%',
                        style: GoogleFonts.spaceMono(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: gainColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 2. Dedicated Generous Vector Chart with Node Rings & Trailing Floor Line (96px height)
          GestureDetector(
            onTap: () {
              AppHaptics.mediumImpact();
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (ctx) => TradeDetailSheet(
                  position: position,
                  onClosePosition: onClosePosition,
                ),
              );
            },
            child: Container(
              height: 96,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF131418),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.charcoalInnerBorder.withValues(alpha: 0.6)),
              ),
              child: Stack(
                children: [
                  // Polyline vector chart
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BigCardChartPainter(
                        prices: position.priceNodes,
                        color: gainColor,
                      ),
                    ),
                  ),
                  // Entry and Peak tags
                  Positioned(
                    left: 6,
                    bottom: 4,
                    child: Text(
                      'Entry \$${position.entryPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.spaceMono(
                        fontSize: 9.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 4,
                    child: Text(
                      'Peak \$${(position.livePrice * 1.05).toStringAsFixed(2)}',
                      style: GoogleFonts.spaceMono(
                        fontSize: 9.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. Key Bot Details Grid (4 Key Telemetry Points)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.charcoalInnerPill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.charcoalInnerBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricCell('ENTRY', '\$${position.entryPrice.toStringAsFixed(2)}'),
                _buildMetricCell('FLOOR', '\$${position.protectedFloor.toStringAsFixed(2)}', valueColor: AppTheme.cyanFloor),
                _buildMetricCell('SHARES', '${position.shares} shs'),
                _buildMetricCell('RATCHET', position.ratchetTier.contains('Tier') ? 'Tier 2' : 'Tier 1', valueColor: AppTheme.mint),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 4. Quick Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildActionPill(
                  icon: Icons.lock_outline_rounded,
                  label: 'Ratchet Stop',
                  onTap: () {
                    AppHaptics.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${position.symbol}: Trailing stop ratcheted to \$${(position.livePrice * 0.96).toStringAsFixed(2)}.'),
                        backgroundColor: AppTheme.charcoalCard,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionPill(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Take Profit',
                  onTap: () {
                    AppHaptics.mediumImpact();
                    onClosePosition();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCell(String label, String value, {Color valueColor = AppTheme.textWhite}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
            color: AppTheme.textMuted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.spaceMono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.charcoalInnerPill,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.charcoalInnerBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: AppTheme.textWhite),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.spaceMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textWhite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Crisp Vector Polyline Chart for Big Position Card
class _BigCardChartPainter extends CustomPainter {
  final List<double> prices;
  final Color color;

  _BigCardChartPainter({required this.prices, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;

    final min = prices.reduce((a, b) => a < b ? a : b);
    final max = prices.reduce((a, b) => a > b ? a : b);
    final range = (max - min) == 0 ? 1.0 : (max - min);

    final double stepX = size.width / (prices.length - 1);
    final List<Offset> points = [];

    for (int i = 0; i < prices.length; i++) {
      final normY = (prices[i] - min) / range;
      final x = i * stepX;
      final y = size.height - (normY * (size.height - 24)) - 12;
      points.add(Offset(x, y));
    }

    // Subtle horizontal guidelines
    final gridPaint = Paint()
      ..color = AppTheme.charcoalBorder.withValues(alpha: 0.5)
      ..strokeWidth = 0.8;

    for (double y = 14; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Soft gradient area fill under curve
    final fillPath = Path();
    fillPath.moveTo(points.first.dx, size.height);
    for (final pt in points) {
      fillPath.lineTo(pt.dx, pt.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.25),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Vector line stroke
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    // Hollow node circles
    final nodeFillPaint = Paint()
      ..color = const Color(0xFF131418)
      ..style = PaintingStyle.fill;

    final nodeBorderPaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (final pt in points) {
      canvas.drawCircle(pt, 3.5, nodeFillPaint);
      canvas.drawCircle(pt, 3.5, nodeBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BigCardChartPainter oldDelegate) =>
      oldDelegate.prices != prices || oldDelegate.color != color;
}
