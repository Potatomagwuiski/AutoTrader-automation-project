import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import '../../dashboard/view_models/dashboard_view_model.dart';

/// Structured telemetry model for audited yearly performance.
/// Adding any year (2026, 2027, etc.) automatically scales all calculations,
/// charts, and card lists dynamically.
class YearlyAuditData {
  final String year;
  final String desc;
  final double gainPct;
  final double netProfit;
  final int tradesCount;
  final double winRatePct;
  final double profitFactor;
  final double maxDrawdownPct;
  final String mvp;
  final double benchmarkGainPct;

  const YearlyAuditData({
    required this.year,
    required this.desc,
    required this.gainPct,
    required this.netProfit,
    required this.tradesCount,
    required this.winRatePct,
    required this.profitFactor,
    required this.maxDrawdownPct,
    required this.mvp,
    this.benchmarkGainPct = 12.0,
  });
}

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  static const List<YearlyAuditData> _allAuditedCycles = [
    YearlyAuditData(
      year: '2026',
      desc: 'Live Alpaca Paper Session',
      gainPct: 0.0,
      netProfit: 0,
      tradesCount: 0,
      winRatePct: 0.0,
      profitFactor: 0.0,
      maxDrawdownPct: 0.0,
      mvp: '100% Cash Ready',
      benchmarkGainPct: 0.0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return RefreshIndicator(
      color: AppTheme.referenceOrange,
      backgroundColor: AppTheme.charcoalCard,
      strokeWidth: 2.5,
      onRefresh: () async {
        AppHaptics.mediumImpact();
        await context.read<DashboardViewModel>().refreshAllData();
        AppHaptics.successNotification();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: bottomInset + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // ================= CARD 1: MASTER CAGR HERO CARD =================
          _buildCagrHeroCard(context),

          const SizedBox(height: 18),

          // ================= SECTION HEADER: CYCLE AUDITS =================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cycle Audits',
                  style: GoogleFonts.spaceMono(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.charcoalInnerPill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.charcoalInnerBorder),
                  ),
                  child: Text(
                    '1 ACTIVE CYCLE',
                    style: GoogleFonts.spaceMono(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ================= INDIVIDUAL AUDIT CARDS =================
          ..._allAuditedCycles.map((cycle) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildIndividualCycleCard(
                  context: context,
                  data: cycle,
                ),
              )),
        ],
      ),
    ),
  );
}

  // CARD 1: Master CAGR Hero (Fully Scalable & Dynamically Calculated)
  Widget _buildCagrHeroCard(BuildContext context) {
    // Chronological order (oldest to newest) for compound curve math
    final chronological = _allAuditedCycles.reversed.toList();
    final totalYears = chronological.length;

    // Mathematical Compounding Calculations
    const startCapital = 100000.0;
    double currentBot = startCapital;
    double currentBenchmark = startCapital;

    for (final cycle in chronological) {
      currentBot *= (1.0 + cycle.gainPct / 100.0);
      currentBenchmark *= (1.0 + cycle.benchmarkGainPct / 100.0);
    }

    final totalBotReturnPct = ((currentBot - startCapital) / startCapital) * 100.0;
    final totalBenchmarkReturnPct = ((currentBenchmark - startCapital) / startCapital) * 100.0;
    final cagr = (math.pow(currentBot / startCapital, 1.0 / totalYears) - 1.0) * 100.0;
    final worstDrawdown = _allAuditedCycles.map((c) => c.maxDrawdownPct).reduce(math.min);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.charcoalBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.charcoalInnerPill,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.charcoalInnerBorder),
                ),
                child: const Center(
                  child: Icon(Icons.insights_rounded, color: AppTheme.textWhite, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quantitative Alpha',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'All-Time Audited Backtest ($totalYears Years)',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          // CAGR Label
          Text(
            'ANNUAL COMPOUND RATE (CAGR)',
            style: GoogleFonts.spaceMono(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),

          // Amount & Horizon (Dynamically Calculated)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${cagr.toStringAsFixed(2)}%',
                style: GoogleFonts.spaceMono(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mint,
                  letterSpacing: -0.5,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+${totalBotReturnPct.toStringAsFixed(1)}% ALL-TIME',
                    style: GoogleFonts.spaceMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Max DD: ${worstDrawdown.toStringAsFixed(1)}%',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Legend Row (Dynamically formatted - Neutral labels, Green only for gains)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.mint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.spaceMono(fontSize: 9.5),
                      children: [
                        const TextSpan(
                          text: 'Alpha Engine ',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: '(+${totalBotReturnPct.toStringAsFixed(1)}%)',
                          style: const TextStyle(
                            color: AppTheme.mint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.spaceMono(fontSize: 9.5),
                  children: [
                    const TextSpan(
                      text: '--- S&P 500 ',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: '(+${totalBenchmarkReturnPct.toStringAsFixed(1)}%)',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Dynamic Equity Growth Performance Chart
          SizedBox(
            height: 110,
            child: CustomPaint(
              painter: _PerformanceEquityCurvePainter(cycles: chronological),
              child: const SizedBox.expand(),
            ),
          ),

          const SizedBox(height: 8),

          // Scalable Dynamic Year Milestone Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: chronological
                .map((c) => _buildYearMilestoneLabel(
                      c.year,
                      '+${c.gainPct.toStringAsFixed(1)}%',
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildYearMilestoneLabel(String year, String gain) {
    return Column(
      children: [
        Text(
          year,
          style: GoogleFonts.spaceMono(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppTheme.textWhite,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          gain,
          style: GoogleFonts.spaceMono(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppTheme.mint,
          ),
        ),
      ],
    );
  }

  // Individual Clean Cycle Audit Card (Dynamically bound)
  Widget _buildIndividualCycleCard({
    required BuildContext context,
    required YearlyAuditData data,
  }) {
    final isUp = data.gainPct >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.charcoalBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header: Year + Theme on Left, Gain + Net Profit on Right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.year,
                      style: GoogleFonts.spaceMono(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.desc,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isUp ? '+' : ''}${data.gainPct.toStringAsFixed(1)}%',
                    style: GoogleFonts.spaceMono(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isUp ? AppTheme.mint : AppTheme.referenceRed,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '+\$${data.netProfit.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
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

          const SizedBox(height: 16),

          // 2. Organized Floating Metrics (Clean 4-column typography without nested boxes)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFloatingMetricColumn(
                label: 'WIN RATE',
                value: '${data.winRatePct.toStringAsFixed(1)}%',
              ),
              _buildFloatingMetricColumn(
                label: 'PROFIT FACTOR',
                value: '${data.profitFactor.toStringAsFixed(2)} PF',
              ),
              _buildFloatingMetricColumn(
                label: 'MAX DD',
                value: '${data.maxDrawdownPct.toStringAsFixed(1)}%',
              ),
              _buildFloatingMetricColumn(
                label: 'TRADES',
                value: '${data.tradesCount} Exec',
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3. Floating MVP Subtext
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 14, color: AppTheme.referenceOrange),
              const SizedBox(width: 5),
              Text(
                'MVP Stock: ',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
              Text(
                data.mvp,
                style: GoogleFonts.spaceMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textWhite,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingMetricColumn({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMuted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.spaceMono(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.textWhite,
          ),
        ),
      ],
    );
  }
}

/// Fully Scalable Equity Growth Curve Painter.
/// Calculates dynamic Bézier interpolation, gradients, benchmarks,
/// and milestone node positions for any arbitrary list of audit years.
class _PerformanceEquityCurvePainter extends CustomPainter {
  final List<YearlyAuditData> cycles;

  _PerformanceEquityCurvePainter({required this.cycles});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || cycles.isEmpty) return;

    final width = size.width;
    final height = size.height - 8;

    // 1. Horizontal Grid Guides
    final gridPaint = Paint()
      ..color = AppTheme.charcoalBorder.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      final y = height * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // 2. Compute dynamic cumulative equity curves
    final List<double> botEquities = [];
    final List<double> benchmarkEquities = [];
    double currentBot = 100.0;
    double currentBench = 100.0;

    for (final c in cycles) {
      currentBot *= (1.0 + c.gainPct / 100.0);
      currentBench *= (1.0 + c.benchmarkGainPct / 100.0);
      botEquities.add(currentBot);
      benchmarkEquities.add(currentBench);
    }

    final double maxVal = botEquities.reduce(math.max) * 1.08;
    const double minVal = 80.0;

    // 3. Map to Canvas Coordinates
    final List<Offset> botPoints = [];
    final List<Offset> benchPoints = [];

    for (int i = 0; i < cycles.length; i++) {
      final x = cycles.length == 1 ? width / 2 : width * (i / (cycles.length - 1));

      final normBot = (botEquities[i] - minVal) / (maxVal - minVal);
      final yBot = height - (normBot.clamp(0.0, 1.0) * height);
      botPoints.add(Offset(x, yBot));

      final normBench = (benchmarkEquities[i] - minVal) / (maxVal - minVal);
      final yBench = height - (normBench.clamp(0.0, 1.0) * height);
      benchPoints.add(Offset(x, yBench));
    }

    // 4. Draw S&P 500 Benchmark Curve (Dashed line)
    final benchmarkPaint = Paint()
      ..color = AppTheme.textMuted.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final benchPath = Path()..moveTo(benchPoints[0].dx, benchPoints[0].dy);
    for (int i = 0; i < benchPoints.length - 1; i++) {
      final p0 = benchPoints[i];
      final p1 = benchPoints[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      benchPath.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }
    canvas.drawPath(benchPath, benchmarkPaint);

    // 5. Draw Bot Performance Curve (Smooth Cubic Bézier)
    final botPath = Path()..moveTo(botPoints[0].dx, botPoints[0].dy);
    for (int i = 0; i < botPoints.length - 1; i++) {
      final p0 = botPoints[i];
      final p1 = botPoints[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      botPath.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    // 6. Draw Glowing Gradient Fill
    final fillPath = Path.from(botPath)
      ..lineTo(width, height)
      ..lineTo(0, height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.mint.withValues(alpha: 0.28),
          AppTheme.mint.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(fillPath, fillPaint);

    // 7. Glow Layer and Crisp Main Stroke
    final glowPaint = Paint()
      ..color = AppTheme.mint.withValues(alpha: 0.25)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(botPath, glowPaint);

    final linePaint = Paint()
      ..color = AppTheme.mint
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(botPath, linePaint);

    // 8. Milestone Node Dots & Pulsing Terminal Halo
    final dotPaint = Paint()..color = AppTheme.mint;
    final haloPaint = Paint()..color = AppTheme.charcoalCard;

    for (int i = 0; i < botPoints.length; i++) {
      final pt = botPoints[i];
      canvas.drawCircle(pt, 5.0, haloPaint);
      canvas.drawCircle(pt, 3.5, dotPaint);

      if (i == botPoints.length - 1) {
        final pulsePaint = Paint()
          ..color = AppTheme.mint.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawCircle(pt, 7.5, pulsePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PerformanceEquityCurvePainter oldDelegate) =>
      oldDelegate.cycles != cycles;
}



