import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../data/services/gemini_ai_service.dart';
import '../view_models/dashboard_view_model.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';

class AiExecutiveBriefingCard extends StatefulWidget {
  const AiExecutiveBriefingCard({super.key});

  @override
  State<AiExecutiveBriefingCard> createState() => _AiExecutiveBriefingCardState();
}

class _AiExecutiveBriefingCardState extends State<AiExecutiveBriefingCard>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _waveController;
  late AnimationController _rotationController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late AnimationController _splitController;
  late Animation<double> _splitAnimation;

  Timer? _typewriterTimer;
  String _displayedText = '';
  bool _isTyping = false;
  int? _lastTypedPresetIndex;
  bool _hasInitialTyped = false;
  bool _wasThinking = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _splitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      value: 0.0,
    );

    _splitAnimation = CurvedAnimation(
      parent: _splitController,
      curve: Curves.easeInOutCubic,
    );
  }

  void _handleThinkingLifecycle(bool isThinking, String activeText, int currentPresetIndex) {
    if (isThinking && !_wasThinking) {
      // 1. Thinking Started: Immediately clear previous text and smoothly split apart
      _wasThinking = true;
      _typewriterTimer?.cancel();
      _isTyping = false;
      setState(() {
        _displayedText = '';
      });
      _splitController.animateTo(1.0, duration: const Duration(milliseconds: 650), curve: Curves.easeOutCubic);
    } else if (!isThinking && _wasThinking) {
      // 2. Thinking Finished: Smoothly join and fuse back together!
      _wasThinking = false;
      _splitController.animateTo(0.0, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic).then((_) {
        if (mounted) {
          _startTypewriter(activeText, currentPresetIndex);
        }
      });
    } else if (!isThinking && !_wasThinking) {
      // 3. Normal idle / initial state
      if (!_hasInitialTyped || _lastTypedPresetIndex != currentPresetIndex) {
        _startTypewriter(activeText, currentPresetIndex);
      } else if (!_isTyping && _displayedText.isNotEmpty && _displayedText != activeText) {
        _displayedText = activeText;
      }
    }
  }

  void _startTypewriter(String fullText, int presetIndex) {
    _lastTypedPresetIndex = presetIndex;
    _hasInitialTyped = true;
    _typewriterTimer?.cancel();

    int charIndex = 0;
    _displayedText = '';
    _isTyping = true;

    void step() {
      if (!mounted) return;
      if (charIndex >= fullText.length) {
        setState(() {
          _displayedText = fullText;
          _isTyping = false;
        });
        return;
      }

      int charsToTake = 1;
      if (fullText.length > 200 && (charIndex + 2) <= fullText.length) {
        final probe = fullText[charIndex];
        if (probe != '.' && probe != '!' && probe != '?' && probe != ',' && probe != '\n') {
          charsToTake = 2;
        }
      }

      charIndex = (charIndex + charsToTake).clamp(0, fullText.length);
      final currentText = fullText.substring(0, charIndex);
      setState(() {
        _displayedText = currentText;
      });

      if (charIndex >= fullText.length) {
        setState(() {
          _isTyping = false;
        });
        return;
      }

      final lastChar = currentText[charIndex - 1];
      int delayMs = 20;
      if (lastChar == '.' || lastChar == '!' || lastChar == '?') {
        delayMs = 85;
      } else if (lastChar == ',' || lastChar == ':' || lastChar == ';' || lastChar == '—' || lastChar == '-') {
        delayMs = 45;
      }

      _typewriterTimer = Timer(Duration(milliseconds: delayMs), step);
    }

    _typewriterTimer = Timer(const Duration(milliseconds: 50), step);
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _waveController.dispose();
    _rotationController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    _splitController.dispose();
    super.dispose();
  }

  IconData _getPresetIcon(String? iconKey) {
    switch (iconKey) {
      case 'dashboard':
        return Icons.space_dashboard_outlined;
      case 'shield':
        return Icons.shield_outlined;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'verified':
        return Icons.verified_user_outlined;
      case 'radar':
        return Icons.radar_rounded;
      case 'bolt':
      case 'flash_on':
        return Icons.bolt_rounded;
      case 'show_chart':
        return Icons.show_chart_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();
    final greeting = viewModel.greetingTitle;
    final isPlaying = viewModel.isBriefingPlaying;
    final isThinking = viewModel.isCompanionThinking;
    GeminiAiService? gemini;
    try {
      gemini = context.watch<GeminiAiService>();
    } catch (_) {
      gemini = viewModel.geminiService;
    }
    final isOnline = gemini?.hasApiKey == true && gemini?.isGeminiConnected == true;
    final activeText = viewModel.activeBriefingText;
    final currentPresetIndex = viewModel.selectedBriefingPresetIndex;

    // Manage smooth split -> smooth join -> typewriter lifecycle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleThinkingLifecycle(isThinking, activeText, currentPresetIndex);
      }
    });

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isPlaying
              ? AppTheme.mint.withValues(alpha: 0.5)
              : AppTheme.charcoalBorder,
          width: isPlaying ? 1.4 : 1.0,
        ),
        boxShadow: [
          ...AppTheme.cardShadow,
          if (isPlaying)
            BoxShadow(
              color: AppTheme.mint.withValues(alpha: 0.12),
              blurRadius: 16,
              spreadRadius: 2,
            ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // 1. Header: Greeting & Voice Readout Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Uncontained Free-Floating Gemini Star Logo
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        AppHaptics.mediumImpact();
                        viewModel.selectBriefingPreset(viewModel.selectedBriefingPresetIndex);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _rotationController,
                            _shimmerController,
                            _pulseController,
                            _splitAnimation,
                          ]),
                          builder: (context, child) {
                            return CustomPaint(
                              size: const Size(28, 28),
                              painter: GeminiLogoPainter(
                                rotationAngle: _rotationController.value * 2 * math.pi,
                                shimmerAngle: _shimmerController.value * 2 * math.pi,
                                pulseScale: 0.94 + (_pulseController.value * 0.12),
                                splitFactor: _splitAnimation.value,
                                isThinking: isThinking || _splitAnimation.value > 0.05,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.0, 0.12),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              greeting,
                              key: ValueKey(greeting),
                              style: GoogleFonts.spaceMono(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textWhite,
                              ),
                              maxLines: 1,
                            ),
                          ),
                            AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Row(
                              key: ValueKey(isThinking ? 'header_thinking' : 'header_companion_$isOnline'),
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isThinking
                                        ? const Color(0xFF00E5FF)
                                        : (isOnline ? AppTheme.mint : AppTheme.referenceOrange),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isThinking
                                      ? 'Gemini Thinking...'
                                      : (isOnline ? 'Gemini AI Companion' : 'Gemini Offline (Local Engine)'),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isThinking
                                        ? const Color(0xFF00E5FF)
                                        : (isOnline ? AppTheme.textMuted : AppTheme.referenceOrange.withValues(alpha: 0.9)),
                                    fontWeight: isThinking ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Voice Readout Button with Equalizer
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  AppHaptics.mediumImpact();
                  viewModel.toggleBriefingAudio();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPlaying
                        ? AppTheme.referenceOrange.withValues(alpha: 0.18)
                        : AppTheme.charcoalInnerPill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPlaying
                          ? AppTheme.referenceOrange.withValues(alpha: 0.5)
                          : AppTheme.charcoalInnerBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPlaying) ...[
                        _buildAnimatedEqualizerBar(0.0),
                        const SizedBox(width: 2.5),
                        _buildAnimatedEqualizerBar(0.2),
                        const SizedBox(width: 2.5),
                        _buildAnimatedEqualizerBar(0.4),
                        const SizedBox(width: 2.5),
                        _buildAnimatedEqualizerBar(0.6),
                        const SizedBox(width: 5),
                      ] else ...[
                        const Icon(
                          Icons.volume_up_outlined,
                          size: 13,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        'VOICE',
                        style: GoogleFonts.spaceMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPlaying ? AppTheme.referenceOrange : AppTheme.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Preset Questions Horizontal Carousel (Clean Vector Icons, Zero Emojis)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(viewModel.briefingPresets.length, (idx) {
                final isSelected = viewModel.selectedBriefingPresetIndex == idx;
                final preset = viewModel.briefingPresets[idx];
                final iconData = _getPresetIcon(preset['icon']);

                return Padding(
                  padding: EdgeInsets.only(
                    right: idx == viewModel.briefingPresets.length - 1 ? 0 : 6,
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      AppHaptics.selectionClick();
                      if (viewModel.selectedBriefingPresetIndex != idx) {
                        setState(() {
                          _displayedText = '';
                        });
                        viewModel.selectBriefingPreset(idx);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.charcoalInnerPill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.textWhite.withValues(alpha: 0.8)
                              : AppTheme.charcoalInnerBorder,
                          width: isSelected ? 1.2 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            iconData,
                            size: 12.5,
                            color: isSelected ? AppTheme.textWhite : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            preset['label']!,
                            style: GoogleFonts.spaceMono(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppTheme.textWhite : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 14),

          // 3. Body: AI Briefing Floating Text (Smooth Animated Transition)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: (isThinking || _splitAnimation.value > 0.05)
                ? Container(
                    key: const ValueKey('body_thinking'),
                    alignment: Alignment.topLeft,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00E5FF),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Synthesizing live intelligence...',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.55,
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.85),
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    key: const ValueKey('body_streaming'),
                    alignment: Alignment.topLeft,
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.55,
                          color: isPlaying
                              ? AppTheme.mint
                              : AppTheme.textWhite.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w400,
                        ),
                        children: [
                          TextSpan(
                            text: _displayedText.isEmpty ? activeText : _displayedText,
                          ),
                          if (_isTyping)
                            TextSpan(
                              text: ' ▍',
                              style: GoogleFonts.spaceMono(
                                color: const Color(0xFF00E5FF),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: AppTheme.charcoalBorder.withValues(alpha: 0.6)),
          const SizedBox(height: 10),

          // 4. Footer: View Breakdown & Status Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  AppHaptics.lightClick();
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Row(
                  children: [
                    Text(
                      _isExpanded ? 'Hide breakdown' : 'View breakdown',
                      style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mint,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppTheme.mint,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.mint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '0% Downside Risk',
                    style: GoogleFonts.spaceMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mint,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 5. Expandable Key Bot Actions Checklist (Smooth Animated Transition)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 320),
            firstCurve: Curves.easeInOutCubic,
            secondCurve: Curves.easeInOutCubic,
            sizeCurve: Curves.easeInOutCubic,
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 14),
                Container(height: 1, color: AppTheme.charcoalBorder),
                const SizedBox(height: 14),
                _buildActionBullet(
                  'Market Check',
                  'S&P 200-EMA slope positive (+0.42%). Alpha hunting enabled.',
                ),
                const SizedBox(height: 8),
                _buildActionBullet(
                  'Zero-Risk Locks',
                  'AMD floor locked at \$365.20 (+73.6% min gain). ARM floor at \$138.50.',
                ),
                const SizedBox(height: 8),
                _buildActionBullet(
                  'Canary AI',
                  'Tested mutant #4 in sandbox. Discarded sub-optimal parameters.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildAnimatedEqualizerBar(double delayOffset) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final val = ((_waveController.value + delayOffset) % 1.0);
        final height = (4.0 + val * 10.0).clamp(3.0, 14.0);
        return Container(
          width: 2.4,
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.mint,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      },
    );
  }

  Widget _buildActionBullet(String label, String detail) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(Icons.circle, size: 5, color: AppTheme.mint),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: AppTheme.textMuted,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: GoogleFonts.spaceMono(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                    fontSize: 11.5,
                  ),
                ),
                TextSpan(text: detail),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class GeminiLogoPainter extends CustomPainter {
  final double rotationAngle;
  final double shimmerAngle;
  final double pulseScale;
  final double splitFactor; // 0.0 to 1.0 (smoothly splits and joins back)
  final bool isThinking;

  GeminiLogoPainter({
    required this.rotationAngle,
    required this.shimmerAngle,
    required this.pulseScale,
    this.splitFactor = 0.0,
    this.isThinking = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final mainRadius = (size.width * 0.38) * pulseScale;

    // Google Gemini Authentic Dynamic Gradient
    final gradient = SweepGradient(
      center: Alignment.center,
      startAngle: 0.0,
      endAngle: math.pi * 2,
      colors: const [
        Color(0xFF1A73E8), // Google Blue
        Color(0xFF00E5FF), // Electric Cyan
        Color(0xFF00E676), // Radiant Mint
        Color(0xFF9334E8), // Gemini Purple
        Color(0xFFFF5252), // Coral Spark
        Color(0xFF1A73E8), // Google Blue loop
      ],
      transform: GradientRotation(shimmerAngle),
    );

    final shaderRect = Rect.fromCircle(center: center, radius: mainRadius * 1.6);
    final shader = gradient.createShader(shaderRect);

    final fillPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill;

    if (splitFactor <= 0.001) {
      // 1. Normal State: Unified Single Rotating Star
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotationAngle);
      canvas.translate(-center.dx, -center.dy);

      final starPath = _buildGeminiStarPath(center, mainRadius);

      if (isThinking) {
        final auraPaint = Paint()
          ..shader = shader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawPath(starPath, auraPaint);
      }

      canvas.drawPath(starPath, fillPaint);

      // Satellite sparkle (orbiting top-right)
      final satCenter = Offset(center.dx + mainRadius * 0.70, center.dy - mainRadius * 0.65);
      final satRadius = mainRadius * 0.28;
      final satPath = _buildGeminiStarPath(satCenter, satRadius);
      final satPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;
      canvas.drawPath(satPath, satPaint);

      canvas.restore();
    } else {
      // 2. Thinking State: Star smoothly splits into 2 dancing stars and joins back!
      final maxSplit = size.width * 0.24;
      final currentSplit = maxSplit * splitFactor;
      final childRadius = mainRadius * (1.0 - 0.25 * splitFactor);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotationAngle);
      canvas.translate(-center.dx, -center.dy);

      // Glowing plasma bridge between splitting stars
      final bridgePaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35 * splitFactor)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(center, currentSplit * 0.7, bridgePaint);

      // Star A (Diverging along axis)
      final star1Center = Offset(center.dx + currentSplit, center.dy - currentSplit * 0.35);
      final star1Path = _buildGeminiStarPath(star1Center, childRadius);
      canvas.drawPath(star1Path, fillPaint);

      // Star B (Diverging opposite)
      final star2Center = Offset(center.dx - currentSplit, center.dy + currentSplit * 0.35);
      final star2Path = _buildGeminiStarPath(star2Center, childRadius * 0.90);
      canvas.drawPath(star2Path, fillPaint);

      // Satellite sparkle orbiting actively
      final satCenter = Offset(center.dx + currentSplit * 1.3, center.dy + currentSplit * 1.1);
      final satRadius = mainRadius * 0.25;
      final satPath = _buildGeminiStarPath(satCenter, satRadius);
      final satPaint = Paint()
        ..color = const Color(0xFF00E676).withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;
      canvas.drawPath(satPath, satPaint);

      canvas.restore();
    }
  }

  Path _buildGeminiStarPath(Offset center, double radius) {
    final path = Path();
    final top = Offset(center.dx, center.dy - radius);
    final right = Offset(center.dx + radius, center.dy);
    final bottom = Offset(center.dx, center.dy + radius);
    final left = Offset(center.dx - radius, center.dy);

    final pinch = radius * 0.20;

    path.moveTo(top.dx, top.dy);
    path.quadraticBezierTo(center.dx + pinch, center.dy - pinch, right.dx, right.dy);
    path.quadraticBezierTo(center.dx + pinch, center.dy + pinch, bottom.dx, bottom.dy);
    path.quadraticBezierTo(center.dx - pinch, center.dy + pinch, left.dx, left.dy);
    path.quadraticBezierTo(center.dx - pinch, center.dy - pinch, top.dx, top.dy);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant GeminiLogoPainter oldDelegate) => true;
}
