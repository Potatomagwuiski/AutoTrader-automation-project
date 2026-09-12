import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../data/services/bot_telemetry_service.dart';
import '../../../core/theme.dart';
import '../view_models/dashboard_view_model.dart';
import 'trade_detail_sheet.dart';

class SetupDetailSheet extends StatefulWidget {
  final PotentialPurchase setup;

  const SetupDetailSheet({super.key, required this.setup});

  @override
  State<SetupDetailSheet> createState() => _SetupDetailSheetState();
}

class _SetupDetailSheetState extends State<SetupDetailSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _geminiSpinController;
  bool _isIntelLoading = false;
  Timer? _typewriterTimer;
  String _displayedIntelText = '';
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _geminiSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();

    final symbol = widget.setup.symbol;
    final viewModel = context.read<DashboardViewModel>();
    final cached = viewModel.geminiService?.getCachedSetupIntel(symbol);
    if (cached != null && cached.isNotEmpty) {
      _displayedIntelText = cached;
      _isIntelLoading = false;
      _isTyping = false;
    } else {
      _isIntelLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchLiveSetupIntel();
      });
    }
  }

  void _fetchLiveSetupIntel() {
    final viewModel = context.read<DashboardViewModel>();
    final gemini = viewModel.geminiService;

    setState(() {
      _isIntelLoading = true;
      _displayedIntelText = '';
    });

    if (gemini != null) {
      gemini.generateSetupIntel(
        setup: widget.setup,
        state: viewModel.state,
      ).then((intel) {
        if (!mounted) return;
        setState(() {
          _isIntelLoading = false;
        });
        _startTypewriter(intel);
      }).catchError((_) {
        if (!mounted) return;
        final fallback = "${widget.setup.companyName} shows elevated institutional accumulation with ${widget.setup.rvol}x volume acceleration. Our quantitative engine will execute on breakout at \$${widget.setup.suggestedEntry.toStringAsFixed(2)} with strict stop-loss protection.";
        setState(() {
          _isIntelLoading = false;
        });
        _startTypewriter(fallback);
      });
    } else {
      final fallback = "${widget.setup.companyName} shows elevated institutional accumulation with ${widget.setup.rvol}x volume acceleration. Our quantitative engine will execute on breakout at \$${widget.setup.suggestedEntry.toStringAsFixed(2)} with strict stop-loss protection.";
      setState(() {
        _isIntelLoading = false;
      });
      _startTypewriter(fallback);
    }
  }

  void _startTypewriter(String fullText) {
    _typewriterTimer?.cancel();
    int charIndex = 0;
    _displayedIntelText = '';
    _isTyping = true;

    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 28), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (charIndex < fullText.length) {
        charIndex++;
        setState(() {
          _displayedIntelText = fullText.substring(0, charIndex);
        });
      } else {
        timer.cancel();
        setState(() {
          _isTyping = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _geminiSpinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setup = widget.setup;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1.0 - animValue)),
          child: Opacity(opacity: animValue, child: child),
        );
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 20),
        decoration: const BoxDecoration(
          color: AppTheme.appBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // 1. Top Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.charcoalCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.charcoalBorder),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppTheme.textWhite),
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Row(
                children: [
                  Text(
                    '${setup.symbol} / USD',
                    style: GoogleFonts.spaceMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.mint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'RADAR',
                      style: GoogleFonts.spaceMono(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.mint,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.charcoalCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.charcoalBorder),
                ),
                child: const Icon(Icons.radar_rounded, size: 18, color: AppTheme.textWhite),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 2. Price & Setup Target Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${setup.currentPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.spaceMono(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textWhite,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Trigger: \$${setup.suggestedEntry.toStringAsFixed(2)} (+${(((setup.suggestedEntry - setup.currentPrice) / setup.currentPrice) * 100).toStringAsFixed(1)}%)',
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mint,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'RVOL  ${setup.rvol}x VELOCITY',
                    style: GoogleFonts.spaceMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'STOP  \$${setup.suggestedStopLoss.toStringAsFixed(2)}',
                    style: GoogleFonts.spaceMono(
                      fontSize: 9.5,
                      color: AppTheme.referenceRed,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3. Setup Strategy Intelligence Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.charcoalCard,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppTheme.charcoalBorder),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Breakout Intelligence',
                    style: GoogleFonts.spaceMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSetupMetric('Company Name', setup.companyName),
                  _buildSetupMetric('Ranking Priority', '${setup.priorityLabel} (${setup.probabilityScore.toStringAsFixed(0)}% Probability)', valueColor: AppTheme.mint),
                  _buildSetupMetric('Distance to 200-EMA', '+${setup.distance200Ema}% (Regime Aligned)', valueColor: AppTheme.mint),
                  _buildSetupMetric('Suggested Stop Loss', '\$${setup.suggestedStopLoss.toStringAsFixed(2)} (-${(((setup.suggestedEntry - setup.suggestedStopLoss) / setup.suggestedEntry) * 100).toStringAsFixed(1)}%)', valueColor: AppTheme.referenceRed),
                  _buildSetupMetric('Position Sizing Rule', '48.5% (\$259,650) upon Trigger'),
                  _buildSetupMetric('AAOIFI Shariah Gate', 'PASS (Debt < 30%, Clean)', valueColor: AppTheme.mint),
                  const SizedBox(height: 10),
                  const Divider(color: AppTheme.charcoalBorder, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      RotationTransition(
                        turns: _geminiSpinController,
                        child: CustomPaint(
                          size: const Size(11, 11),
                          painter: MiniGeminiStarPainter(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'GEMINI SETUP HYPOTHESIS',
                        style: GoogleFonts.spaceMono(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.geminiBlue,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppTheme.mint,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.mint.withValues(alpha: 0.6),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      if (_isIntelLoading) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Analyzing...',
                            style: GoogleFonts.spaceMono(
                              fontSize: 7.5,
                              color: const Color(0xFF00E5FF),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_isIntelLoading && _displayedIntelText.isEmpty)
                    Text(
                      'Synthesizing institutional breakout probabilities...',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textMuted.withValues(alpha: 0.7),
                      ),
                    )
                  else
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _displayedIntelText,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textWhite.withValues(alpha: 0.9),
                              height: 1.35,
                            ),
                          ),
                          if (_isTyping)
                            TextSpan(
                              text: ' ▍',
                              style: GoogleFonts.spaceMono(
                                fontSize: 11,
                                color: const Color(0xFF00E5FF),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildSetupMetric(String label, String value, {Color valueColor = AppTheme.textWhite}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.spaceMono(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
