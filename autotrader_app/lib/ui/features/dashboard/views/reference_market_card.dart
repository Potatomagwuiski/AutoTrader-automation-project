import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/position.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import 'trade_detail_sheet.dart';

class ReferenceMarketCard extends StatelessWidget {
  final List<Position> positions;
  final VoidCallback? onClosePosition;

  const ReferenceMarketCard({
    super.key,
    required this.positions,
    this.onClosePosition,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Positions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textWhite,
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.charcoalInnerPill,
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppTheme.textWhite,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          
          // List of positions
          ...positions.map((pos) => _buildPositionRow(context, pos)),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPositionRow(BuildContext context, Position pos) {
    final currencyFormatter = NumberFormat.currency(symbol: '\$');
    final isPositive = pos.livePrice >= pos.entryPrice;
    final color = isPositive ? AppTheme.referenceGreen : AppTheme.referenceRed;

    return InkWell(
      onTap: () {
        AppHaptics.mediumImpact();
        if (onClosePosition != null) {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (ctx) => TradeDetailSheet(
              position: pos,
              onClosePosition: onClosePosition!,
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.charcoalInnerPill,
              ),
              child: Center(
                child: Text(
                  pos.symbol.substring(0, 1),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Name and Symbol
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pos.symbol, // We don't have full name in model, use symbol
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pos.symbol,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            
            // Sparkline (simplified representation)
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 24,
                child: CustomPaint(
                  painter: _MiniSparklinePainter(
                    prices: pos.priceNodes,
                    color: color,
                  ),
                ),
              ),
            ),
            
            // Price and Change
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormatter.format(pos.livePrice),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${isPositive ? '+' : '-'}${currencyFormatter.format((pos.livePrice - pos.entryPrice).abs())}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${isPositive ? '+' : ''}${((pos.livePrice - pos.entryPrice) / pos.entryPrice * 100).toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  final List<double> prices;
  final Color color;

  _MiniSparklinePainter({required this.prices, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;

    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final priceRange = (maxPrice - minPrice) == 0 ? 1.0 : (maxPrice - minPrice);

    final double stepX = size.width / (prices.length - 1);
    final Path path = Path();

    for (int i = 0; i < prices.length; i++) {
      final double normalizedY = (prices[i] - minPrice) / priceRange;
      final double x = i * stepX;
      final double y = size.height - (normalizedY * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) {
    return oldDelegate.prices != prices || oldDelegate.color != color;
  }
}
