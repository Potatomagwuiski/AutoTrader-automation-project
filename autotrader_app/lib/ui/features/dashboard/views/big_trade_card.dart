import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/position.dart';
import '../../../core/asset_brand_logo.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import '../view_models/dashboard_view_model.dart';
import 'trade_detail_sheet.dart';

class BigTradeCard extends StatefulWidget {
  final Position position;
  final VoidCallback onClosePosition;

  const BigTradeCard({
    super.key,
    required this.position,
    required this.onClosePosition,
  });

  @override
  State<BigTradeCard> createState() => _BigTradeCardState();
}

class _BigTradeCardState extends State<BigTradeCard> {
  String _selectedTimeframe = 'M';
  final List<String> _timeframes = ['D', 'W', 'M', '6M', 'Y', 'All'];
  int? _scrubbedIndex;

  List<double> _getPricesForTimeframe(String tf, Position pos) {
    final basePrice = pos.livePrice;
    final entry = pos.entryPrice;

    switch (tf) {
      case 'D':
        return [
          basePrice * 0.988,
          basePrice * 0.992,
          basePrice * 0.985,
          basePrice * 0.995,
          basePrice * 0.991,
          basePrice * 1.002,
          basePrice * 0.998,
          basePrice,
        ];
      case 'W':
        return [
          basePrice * 0.94,
          basePrice * 0.96,
          basePrice * 0.93,
          basePrice * 0.97,
          basePrice * 0.985,
          basePrice * 0.98,
          basePrice * 1.01,
          basePrice,
        ];
      case '6M':
        return [
          entry * 0.90,
          entry * 1.05,
          entry * 1.15,
          entry * 1.30,
          entry * 1.45,
          entry * 1.60,
          basePrice * 0.92,
          basePrice,
        ];
      case 'Y':
        return [
          entry * 0.75,
          entry * 0.85,
          entry * 1.10,
          entry * 1.25,
          entry * 1.50,
          entry * 1.70,
          basePrice * 0.90,
          basePrice,
        ];
      case 'All':
        return [
          entry * 0.50,
          entry * 0.65,
          entry * 0.90,
          entry * 1.20,
          entry * 1.55,
          entry * 1.80,
          basePrice,
        ];
      case 'M':
      default:
        return [
          entry * 0.95,
          entry * 0.98,
          entry * 1.08,
          entry * 1.14,
          entry * 1.22,
          entry * 1.35,
          basePrice * 0.94,
          basePrice,
        ];
    }
  }

  void _openDetailModal(BuildContext context, Position pos) {
    AppHaptics.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => TradeDetailSheet(
        position: pos,
        onClosePosition: widget.onClosePosition,
      ),
    );
  }

  List<CandleData> _getCandles(List<double> prices) {
    final List<CandleData> candles = [];
    for (int i = 0; i < prices.length; i++) {
      final current = prices[i];
      final prev = (i > 0) ? prices[i - 1] : current * 0.985;
      final open = prev;
      final close = current;
      final high = (open > close ? open : close) * 1.012;
      final low = (open < close ? open : close) * 0.988;
      candles.add(CandleData(open: open, high: high, low: low, close: close));
    }
    return candles;
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.position;
    final viewModel = context.watch<DashboardViewModel>();
    final isProfit = pos.unrealizedProfitDollars >= 0;
    final gainColor = isProfit ? AppTheme.mint : AppTheme.referenceRed;
    final isCandlestickMode = viewModel.isCandlestickModeFor(pos.symbol);

    final prices = _getPricesForTimeframe(_selectedTimeframe, pos);
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);

    final displayPrice = _scrubbedIndex != null && _scrubbedIndex! < prices.length
        ? prices[_scrubbedIndex!]
        : pos.livePrice;

    final dollarFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return GestureDetector(
      onTap: () => _openDetailModal(context, pos),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
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
            // 1. Top Header Row: Symbol & Candlestick/Line Toggle Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      AssetBrandLogo(symbol: pos.symbol, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  pos.symbol,
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 17.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textWhite,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mint.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'ACTIVE',
                                    style: GoogleFonts.spaceMono(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.mint,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pos.companyName,
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
                const SizedBox(width: 8),

                // Chart Type Switcher (Candles / Line)
                GestureDetector(
                  onTap: () {
                    AppHaptics.mediumImpact();
                    viewModel.toggleChartModeFor(pos.symbol);
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.charcoalInnerPill,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCandlestickMode
                            ? AppTheme.mint.withValues(alpha: 0.5)
                            : AppTheme.charcoalInnerBorder,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isCandlestickMode
                            ? Icons.show_chart_rounded
                            : Icons.candlestick_chart_rounded,
                        size: 19,
                        color: isCandlestickMode ? AppTheme.mint : AppTheme.textWhite,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 2. Price & Key Telemetry Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${displayPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.spaceMono(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${pos.unrealizedProfitDollars >= 0 ? '+' : '-'}${dollarFormatter.format(pos.unrealizedProfitDollars.abs())}',
                          style: GoogleFonts.spaceMono(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${isProfit ? '+' : ''}${pos.unrealizedGainPercent.toStringAsFixed(2)}%',
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
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'PEAK',
                          style: GoogleFonts.spaceMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${maxPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.spaceMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textWhite,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'FLOOR',
                          style: GoogleFonts.spaceMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${pos.protectedFloor.toStringAsFixed(2)}',
                          style: GoogleFonts.spaceMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.cyanFloor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 3. Dynamic Vector Chart (Line or Candlestick mode)
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final localX = details.localPosition.dx;
                final fraction = (localX / box.size.width).clamp(0.0, 1.0);
                final index = (fraction * (prices.length - 1)).round();
                if (index != _scrubbedIndex) {
                  AppHaptics.selectionClick();
                  setState(() {
                    _scrubbedIndex = index;
                  });
                }
              },
              onHorizontalDragEnd: (_) {
                setState(() {
                  _scrubbedIndex = null;
                });
              },
                child: Column(
                  children: [
                    // 1. Top Chart Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCandlestickMode
                                  ? Icons.candlestick_chart_rounded
                                  : Icons.show_chart_rounded,
                              size: 13,
                              color: _scrubbedIndex != null ? AppTheme.mint : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _scrubbedIndex != null
                                  ? 'Scrubbing: \$${displayPrice.toStringAsFixed(2)}'
                                  : (isCandlestickMode ? 'Candles' : 'Trailing Curve'),
                              style: GoogleFonts.spaceMono(
                                fontSize: 10.5,
                                color: _scrubbedIndex != null ? AppTheme.mint : AppTheme.textMuted,
                                fontWeight: _scrubbedIndex != null ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'High \$${maxPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.spaceMono(
                            fontSize: 10.5,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // 2. Interactive Dynamic Chart Canvas
                    SizedBox(
                      height: 105,
                      child: isCandlestickMode
                          ? CustomPaint(
                              painter: _ReferenceCandleChartPainter(
                                candles: _getCandles(prices),
                                scrubbedIndex: _scrubbedIndex,
                              ),
                              child: const SizedBox.expand(),
                            )
                          : CustomPaint(
                              painter: _ReferenceBigChartPainter(
                                prices: prices,
                                color: Colors.white,
                                scrubbedIndex: _scrubbedIndex,
                              ),
                              child: const SizedBox.expand(),
                            ),
                    ),

                    const SizedBox(height: 6),

                    // 3. Bottom Axis Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Low \$${minPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.spaceMono(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        Text(
                          'Floor \$${pos.protectedFloor.toStringAsFixed(2)}',
                          style: GoogleFonts.spaceMono(
                            fontSize: 10,
                            color: AppTheme.cyanFloor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ),

            const SizedBox(height: 16),

            // 4. Timeframe Selector (D  W  [M]  6M  Y  All)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _timeframes.map((tf) {
                final isSelected = tf == _selectedTimeframe;
                return GestureDetector(
                  onTap: () {
                    AppHaptics.lightClick();
                    setState(() {
                      _selectedTimeframe = tf;
                      _scrubbedIndex = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.charcoalInnerPill : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: AppTheme.charcoalInnerBorder)
                          : null,
                    ),
                    child: Text(
                      tf,
                      style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppTheme.textWhite : AppTheme.textMuted,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class CandleData {
  final double open;
  final double high;
  final double low;
  final double close;
  bool get isBullish => close >= open;

  CandleData({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
}

class _ReferenceCandleChartPainter extends CustomPainter {
  final List<CandleData> candles;
  final int? scrubbedIndex;

  _ReferenceCandleChartPainter({
    required this.candles,
    this.scrubbedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    double min = candles.first.low;
    double max = candles.first.high;

    for (final c in candles) {
      if (c.low < min) min = c.low;
      if (c.high > max) max = c.high;
    }

    final range = (max - min) == 0 ? 1.0 : (max - min);

    final gridPaint = Paint()
      ..color = AppTheme.charcoalBorder.withValues(alpha: 0.6)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 4.0;

    for (double y = 24; y < size.height - 10; y += 38) {
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, y),
          Offset(startX + dashWidth, y),
          gridPaint,
        );
        startX += dashWidth + dashSpace;
      }
    }

    final count = candles.length;
    final slotWidth = size.width / count;
    final candleWidth = (slotWidth * 0.55).clamp(4.0, 16.0);

    for (int i = 0; i < count; i++) {
      final c = candles[i];
      final color = c.isBullish ? AppTheme.mint : AppTheme.referenceRed;

      final normHigh = (c.high - min) / range;
      final normLow = (c.low - min) / range;
      final normOpen = (c.open - min) / range;
      final normClose = (c.close - min) / range;

      final double centerX = (i * slotWidth) + (slotWidth / 2);
      final double yHigh = size.height - (normHigh * (size.height - 44)) - 22;
      final double yLow = size.height - (normLow * (size.height - 44)) - 22;
      final double yOpen = size.height - (normOpen * (size.height - 44)) - 22;
      final double yClose = size.height - (normClose * (size.height - 44)) - 22;

      final wickPaint = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(centerX, yHigh), Offset(centerX, yLow), wickPaint);

      final topY = yOpen < yClose ? yOpen : yClose;
      final botY = yOpen > yClose ? yOpen : yClose;
      final height = (botY - topY).clamp(2.5, size.height);

      final bodyRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, topY + (height / 2)),
          width: candleWidth,
          height: height,
        ),
        const Radius.circular(2.0),
      );

      final bodyPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawRRect(bodyRect, bodyPaint);
    }

    if (scrubbedIndex != null && scrubbedIndex! < count) {
      final centerX = (scrubbedIndex! * slotWidth) + (slotWidth / 2);

      final cursorLinePaint = Paint()
        ..color = AppTheme.mint.withValues(alpha: 0.5)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), cursorLinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ReferenceCandleChartPainter oldDelegate) =>
      oldDelegate.candles != candles || oldDelegate.scrubbedIndex != scrubbedIndex;
}

class _ReferenceBigChartPainter extends CustomPainter {
  final List<double> prices;
  final Color color;
  final int? scrubbedIndex;

  _ReferenceBigChartPainter({
    required this.prices,
    required this.color,
    this.scrubbedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;

    final min = prices.reduce((a, b) => a < b ? a : b);
    final max = prices.reduce((a, b) => a > b ? a : b);
    final range = (max - min) == 0 ? 1.0 : (max - min);

    final gridPaint = Paint()
      ..color = AppTheme.charcoalBorder.withValues(alpha: 0.6)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 4.0;

    for (double y = 24; y < size.height - 10; y += 38) {
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, y),
          Offset(startX + dashWidth, y),
          gridPaint,
        );
        startX += dashWidth + dashSpace;
      }
    }

    final double stepX = size.width / (prices.length - 1);
    final List<Offset> points = [];

    for (int i = 0; i < prices.length; i++) {
      final normY = (prices[i] - min) / range;
      final x = i * stepX;
      final y = size.height - (normY * (size.height - 44)) - 22;
      points.add(Offset(x, y));
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    final nodeFillPaint = Paint()
      ..color = AppTheme.charcoalCard
      ..style = PaintingStyle.fill;

    final nodeBorderPaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length; i++) {
      if (i == 0 || i == points.length ~/ 2 || i == points.length - 1 || prices[i] == min || prices[i] == max) {
        canvas.drawCircle(points[i], 3.8, nodeFillPaint);
        canvas.drawCircle(points[i], 3.8, nodeBorderPaint);
      }
    }

    if (scrubbedIndex != null && scrubbedIndex! < points.length) {
      final scrubPt = points[scrubbedIndex!];

      final cursorLinePaint = Paint()
        ..color = AppTheme.mint.withValues(alpha: 0.5)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(scrubPt.dx, 0), Offset(scrubPt.dx, size.height), cursorLinePaint);

      final scrubActiveFill = Paint()..color = AppTheme.mint;
      canvas.drawCircle(scrubPt, 5.0, scrubActiveFill);
      canvas.drawCircle(scrubPt, 7.0, Paint()..color = AppTheme.mint.withValues(alpha: 0.3));
    }
  }

  @override
  bool shouldRepaint(covariant _ReferenceBigChartPainter oldDelegate) =>
      oldDelegate.prices != prices ||
      oldDelegate.color != color ||
      oldDelegate.scrubbedIndex != scrubbedIndex;
}
