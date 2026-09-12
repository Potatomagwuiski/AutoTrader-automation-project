import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../haptics.dart';
import '../theme.dart';
import '../../../data/services/gemini_ai_service.dart';
import '../../features/dashboard/view_models/dashboard_view_model.dart';
import '../../features/dashboard/views/ai_executive_briefing_card.dart' show GeminiLogoPainter;
export '../../../data/services/gemini_ai_service.dart' show CompanionPresetChip, GeminiBriefingResult;

class GeminiCompanionCard extends StatefulWidget {
  final String title;
  final String contextTag;
  final List<CompanionPresetChip> presets;
  final String? initialAnswer;
  final List<Widget>? expandableActions;

  const GeminiCompanionCard({
    super.key,
    required this.title,
    required this.contextTag,
    required this.presets,
    this.initialAnswer,
    this.expandableActions,
  });

  @override
  State<GeminiCompanionCard> createState() => _GeminiCompanionCardState();
}

class _GeminiCompanionCardState extends State<GeminiCompanionCard>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late AnimationController _splitController;
  late Animation<double> _splitAnimation;

  int _selectedPresetIndex = 0;
  bool _isThinking = true;
  Timer? _typewriterTimer;
  String _displayedText = '';
  String? _lastKnownBriefingSummary;
  bool _isTyping = false;
  bool _isExpanded = false;
  bool _isTextExpanded = false;
  final Map<int, String> _cachedAnswers = {};
  late List<CompanionPresetChip> _activeChips;

  @override
  void initState() {
    super.initState();
    _activeChips = List.from(widget.presets);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3505),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _splitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      value: 1.0,
    );

    _splitAnimation = CurvedAnimation(
      parent: _splitController,
      curve: Curves.easeInOutCubic,
    );

    // Initial load: Play thinking animation, then smoothly type out briefing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final viewModel = context.read<DashboardViewModel>();
      final cached = viewModel.geminiService?.getCachedCardResult(widget.contextTag);
      final briefingText = (cached != null && cached.text.isNotEmpty)
          ? cached.text
          : (widget.contextTag == 'Executive Briefing' && viewModel.executiveBriefingSummary.isNotEmpty)
              ? viewModel.executiveBriefingSummary
              : null;

      if (cached != null && cached.dynamicChips.isNotEmpty) {
        _activeChips = cached.dynamicChips;
      }

      if (briefingText != null && briefingText.isNotEmpty) {
        setState(() {
          _displayedText = '';
          _isThinking = true;
          _isTyping = false;
        });
        _splitController.value = 1.0;

        // Play thinking animation for a crisp 650ms beat, then fuse stars and type out
        Future.delayed(const Duration(milliseconds: 650), () {
          if (!mounted) return;
          _splitController.animateTo(0.0, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic).then((_) {
            if (!mounted) return;
            setState(() {
              _isThinking = false;
              _lastKnownBriefingSummary = briefingText;
            });
            _startTypewriter(briefingText, 0);
          });
        });
      } else if (_activeChips.isNotEmpty) {
        _onSelectPreset(0, force: true);
      } else {
        _loadLiveBriefing(viewModel);
      }
    });
  }

  void _loadLiveBriefing(DashboardViewModel viewModel, {bool isSilent = false}) {
    if (!isSilent) {
      setState(() {
        _displayedText = '';
        _isThinking = true;
        _isTextExpanded = false;
      });
      _typewriterTimer?.cancel();
      _isTyping = false;
      _splitController.animateTo(1.0, duration: const Duration(milliseconds: 650), curve: Curves.easeOutCubic);
    }

    final gemini = viewModel.geminiService;
    final isOnline = gemini != null && gemini.hasApiKey && gemini.isGeminiConnected;

    Future<GeminiBriefingResult> briefingFuture;
    if (isOnline) {
      briefingFuture = gemini.generateExecutiveBriefing(
        state: viewModel.state,
        positions: viewModel.positions,
        setups: viewModel.potentialPurchases,
        defaultChips: const [],
      );
    } else if (gemini != null) {
      final fallback = gemini.askCompanionLocally(
        'Executive Briefing',
        viewModel.state,
        viewModel.positions,
        viewModel.potentialPurchases,
      );
      briefingFuture = Future.value(GeminiBriefingResult(
        text: fallback,
        dynamicChips: const [],
        isCloud: false,
      ));
    } else {
      briefingFuture = Future.value(GeminiBriefingResult(
        text: viewModel.executiveBriefingSummary,
        dynamicChips: const [],
        isCloud: false,
      ));
    }

    briefingFuture.then((result) {
      if (!mounted) return;
      viewModel.geminiService?.setCachedCardResult(widget.contextTag, result);
      _splitController.animateTo(0.0, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic).then((_) {
        if (!mounted) return;
        setState(() {
          _isThinking = false;
          _displayedText = result.text;
          _lastKnownBriefingSummary = result.text;
        });
        if (!isSilent) {
          _startTypewriter(result.text, 0);
        }
      });
    }).catchError((_) {
      if (!mounted) return;
      final fallback = viewModel.executiveBriefingSummary;
      _splitController.animateTo(0.0, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic).then((_) {
        if (!mounted) return;
        setState(() {
          _isThinking = false;
          _displayedText = fallback;
          _lastKnownBriefingSummary = fallback;
        });
        if (!isSilent) {
          _startTypewriter(fallback, 0);
        }
      });
    });
  }

  void _onSelectPreset(int index, {bool force = false}) {
    if (index >= _activeChips.length) return;
    if (!force && _isThinking) return;
    AppHaptics.selectionClick();

    setState(() {
      _selectedPresetIndex = index;
      _displayedText = '';
      _isThinking = true;
      _isTextExpanded = false;
    });

    _typewriterTimer?.cancel();
    _isTyping = false;

    // Smoothly split stars apart
    _splitController.animateTo(1.0, duration: const Duration(milliseconds: 650), curve: Curves.easeOutCubic);

    final viewModel = context.read<DashboardViewModel>();
    final preset = _activeChips[index];

    final isOnline = viewModel.geminiService != null &&
        viewModel.geminiService!.hasApiKey &&
        viewModel.geminiService!.isGeminiConnected;

    // Priority 1: Call real live Gemini Cloud API if online, else instant on-device engine
    Future<GeminiBriefingResult> answerFuture;
    if (isOnline) {
      answerFuture = viewModel.geminiService!.askCompanion(
        userQuestion: preset.query,
        state: viewModel.state,
        positions: viewModel.positions,
        setups: viewModel.potentialPurchases,
        defaultChips: widget.presets,
      );
    } else if (preset.localAnswer != null && preset.localAnswer!.isNotEmpty) {
      answerFuture = Future.delayed(
        const Duration(milliseconds: 300),
        () => GeminiBriefingResult(
          text: preset.localAnswer!,
          dynamicChips: widget.presets,
          isCloud: false,
        ),
      );
    } else if (viewModel.geminiService != null) {
      final localText = viewModel.geminiService!.askCompanionLocally(
        preset.query,
        viewModel.state,
        viewModel.positions,
        viewModel.potentialPurchases,
      );
      answerFuture = Future.delayed(
        const Duration(milliseconds: 250),
        () => GeminiBriefingResult(
          text: localText,
          dynamicChips: widget.presets,
          isCloud: false,
        ),
      );
    } else {
      answerFuture = Future.value(GeminiBriefingResult(
        text: 'Telemetry monitored. 100% of capital safe in cash.',
        dynamicChips: widget.presets,
        isCloud: false,
      ));
    }

    answerFuture.then((result) {
      if (!mounted) return;
      _cachedAnswers[index] = result.text;
      viewModel.geminiService?.setCachedCardResult(widget.contextTag, result);

      // Update active chips with newly generated dynamic questions from Gemini
      if (result.dynamicChips.isNotEmpty) {
        setState(() {
          _activeChips = result.dynamicChips;
        });
      }

      // Smoothly merge stars back
      _splitController.animateTo(0.0, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic).then((_) {
        if (!mounted) return;
        setState(() {
          _isThinking = false;
        });
        _startTypewriter(result.text, index);
      });
    }).catchError((err) {
      if (!mounted) return;
      final fallback = preset.localAnswer ?? 'Intelligence updated for ${preset.label}.';
      _cachedAnswers[index] = fallback;

      _splitController.animateTo(0.0, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic).then((_) {
        if (!mounted) return;
        setState(() {
          _isThinking = false;
        });
        _startTypewriter(fallback, index);
      });
    });
  }

  void _startTypewriter(String fullText, int presetIndex) {
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
    _rotationController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    _splitController.dispose();
    super.dispose();
  }

  Widget _buildSubtitle(BuildContext context, DashboardViewModel viewModel) {
    GeminiAiService? gemini;
    try {
      gemini = context.watch<GeminiAiService>();
    } catch (_) {
      gemini = viewModel.geminiService;
    }
    final isOnline = gemini?.hasApiKey == true && gemini?.isGeminiConnected == true;

    final dotColor = _isThinking
        ? const Color(0xFF00E5FF)
        : (isOnline ? AppTheme.mint : AppTheme.referenceOrange);

    final textColor = _isThinking
        ? const Color(0xFF00E5FF)
        : (isOnline ? AppTheme.textMuted : AppTheme.referenceOrange.withValues(alpha: 0.9));

    final statusLabel = _isThinking
        ? 'Gemini Thinking...'
        : (isOnline ? 'Gemini ${widget.contextTag}' : 'Gemini Offline (Local Engine)');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          width: 5.5,
          height: 5.5,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: dotColor.withValues(alpha: 0.6),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.25),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            statusLabel,
            key: ValueKey(_isThinking ? 'thinking' : 'idle_${widget.contextTag}_$isOnline'),
            style: GoogleFonts.inter(
              fontSize: 11,
              color: textColor,
              fontWeight: _isThinking ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();
    final currentBriefing = viewModel.executiveBriefingSummary;

    // Reactively update displayed text whenever the ViewModel produces a fresh briefing
    if (!_isTyping &&
        !_isThinking &&
        _selectedPresetIndex == 0 &&
        currentBriefing.isNotEmpty &&
        currentBriefing != _lastKnownBriefingSummary) {
      _lastKnownBriefingSummary = currentBriefing;
      _splitController.animateTo(0.0, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic).then((_) {
        if (!mounted) return;
        _startTypewriter(currentBriefing, 0);
      });
    }

    final activeAnswer = _cachedAnswers[_selectedPresetIndex] ??
        (widget.presets.isNotEmpty ? widget.presets[_selectedPresetIndex].localAnswer : null) ??
        widget.initialAnswer ??
        currentBriefing;
    final fullText = (_isTyping || _displayedText.isNotEmpty)
        ? _displayedText
        : (_isThinking ? '' : activeAnswer);
    final isLongText = fullText.length > 175 || fullText.split('\n').length > 3;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.charcoalBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header: Gemini Star + Context Title + Settings/Chat Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          AppHaptics.mediumImpact();
                          if (widget.contextTag == 'Executive Briefing') {
                            setState(() {
                              _displayedText = '';
                              _isThinking = true;
                              _isTextExpanded = false;
                            });
                            _typewriterTimer?.cancel();
                            _isTyping = false;
                            _splitController.animateTo(1.0, duration: const Duration(milliseconds: 650), curve: Curves.easeOutCubic);

                            viewModel.refreshAllData().then((_) {
                              if (!mounted) return;
                              final newText = viewModel.executiveBriefingSummary;
                              _splitController.animateTo(0.0, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic).then((_) {
                                if (!mounted) return;
                                setState(() {
                                  _isThinking = false;
                                  _lastKnownBriefingSummary = newText;
                                });
                                _startTypewriter(newText, 0);
                              });
                            });
                          } else if (_activeChips.isNotEmpty) {
                            _onSelectPreset(_selectedPresetIndex);
                          }
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
                                  isThinking: _isThinking || _splitAnimation.value > 0.05,
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
                                widget.title,
                                key: ValueKey(widget.title),
                                style: GoogleFonts.spaceMono(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textWhite,
                                ),
                                maxLines: 1,
                              ),
                            ),
                            _buildSubtitle(context, viewModel),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 3. Body: AI Intelligence Text (Smooth Animated Transition)
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
              child: (_isThinking || _splitAnimation.value > 0.05)
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
                            'Synthesizing intelligence...',
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
                  : Column(
                      key: const ValueKey('body_streaming'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (_isTyping) {
                              AppHaptics.lightClick();
                              _typewriterTimer?.cancel();
                              setState(() {
                                _displayedText = fullText;
                                _isTyping = false;
                              });
                            }
                          },
                          child: RichText(
                            maxLines: (isLongText && !_isTextExpanded) ? 3 : null,
                            overflow: (isLongText && !_isTextExpanded)
                                ? TextOverflow.ellipsis
                                : TextOverflow.clip,
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.55,
                                color: AppTheme.textWhite.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w400,
                              ),
                              children: [
                                TextSpan(
                                  text: _displayedText.isEmpty ? activeAnswer : _displayedText,
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
                        if (isLongText) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              AppHaptics.selectionClick();
                              final willCollapse = _isTextExpanded;
                              setState(() {
                                _isTextExpanded = !_isTextExpanded;
                              });
                              if (willCollapse) {
                                final scrollable = Scrollable.maybeOf(context);
                                if (scrollable != null && scrollable.position.hasPixels && scrollable.position.pixels > 0) {
                                  scrollable.position.animateTo(
                                    0.0,
                                    duration: const Duration(milliseconds: 380),
                                    curve: Curves.easeOutCubic,
                                  );
                                }
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isTextExpanded ? 'Show less' : 'Show more',
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.referenceOrange,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  _isTextExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 15,
                                  color: AppTheme.referenceOrange,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),

            if (widget.expandableActions != null) ...[
              const SizedBox(height: 14),
              Container(height: 1, color: AppTheme.charcoalBorder.withValues(alpha: 0.6)),
              const SizedBox(height: 10),

              // 4. Footer: Expand Breakdown
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  AppHaptics.lightClick();
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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

              // 5. Expandable Actions Checklist
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
                    ...widget.expandableActions!,
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
