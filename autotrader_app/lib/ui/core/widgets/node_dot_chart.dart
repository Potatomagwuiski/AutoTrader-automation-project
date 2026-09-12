import 'package:flutter/material.dart';
import '../haptics.dart';

class NodeDotChart extends StatefulWidget {
  final List<double> prices;
  final double protectedFloor;
  final double height;

  const NodeDotChart({
    super.key,
    required this.prices,
    required this.protectedFloor,
    this.height = 65,
  });

  @override
  State<NodeDotChart> createState() => _NodeDotChartState();
}

class _NodeDotChartState extends State<NodeDotChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.prices.isEmpty) return SizedBox(height: widget.height);

    return GestureDetector(
      onPanDown: (details) => _updateSelection(details.localPosition),
      onPanUpdate: (details) => _updateSelection(details.localPosition),
      onPanEnd: (_) => setState(() => _selectedIndex = null),
      onPanCancel: () => setState(() => _selectedIndex = null),
      child: SizedBox(
        height: widget.height,
        child: CustomPaint(
          size: Size.infinite,
          painter: _DottedLadderChartPainter(
            prices: widget.prices,
            selectedIndex: _selectedIndex,
          ),
        ),
      ),
    );
  }

  void _updateSelection(Offset localPosition) {
    final width = context.size?.width ?? 300;
    if (widget.prices.length < 2) return;

    final segmentWidth = width / (widget.prices.length - 1);
    final rawIndex = (localPosition.dx / segmentWidth).round();
    final clampedIndex = rawIndex.clamp(0, widget.prices.length - 1);

    if (_selectedIndex != clampedIndex) {
      AppHaptics.lightClick();
      setState(() {
        _selectedIndex = clampedIndex;
      });
    }
  }
}

class _DottedLadderChartPainter extends CustomPainter {
  final List<double> prices;
  final int? selectedIndex;

  _DottedLadderChartPainter({
    required this.prices,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;

    final minPrice =
        prices.reduce((a, b) => a < b ? a : b).clamp(0.0, double.infinity);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final priceRange = (maxPrice - minPrice) == 0
        ? 1.0
        : (maxPrice - minPrice);

    final double paddingY = 8.0;
    final double availableHeight = size.height - (paddingY * 2);
    final double stepX = size.width / (prices.length - 1);

    final List<Offset> points = [];
    for (int i = 0; i < prices.length; i++) {
      final double normalizedY = (prices[i] - minPrice) / priceRange;
      final double x = i * stepX;
      final double y = size.height - paddingY - (normalizedY * availableHeight);
      points.add(Offset(x, y));
    }

    // 1. Draw connecting mint line with subtle glow
    final linePaint = Paint()
      ..color = const Color(0xFF2DD4BF).withValues(alpha: 0.6)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final Path linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // 2. Draw Mint/Cyan Glowing Dots (matching reference image oneline_status_bento_ui)
    final dotFillPaint = Paint()
      ..color = const Color(0xFF5EEAD4)
      ..style = PaintingStyle.fill;

    final selectedDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final isSelected = (selectedIndex == i);
      final radius = isSelected ? 4.5 : 2.8;

      // Outer glow for each dot
      final glowPaint = Paint()
        ..color = const Color(0xFF2DD4BF).withValues(alpha: isSelected ? 0.8 : 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, radius + 2.5, glowPaint);

      // Core dot
      canvas.drawCircle(pt, radius, isSelected ? selectedDotPaint : dotFillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLadderChartPainter oldDelegate) {
    return oldDelegate.prices != prices ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
