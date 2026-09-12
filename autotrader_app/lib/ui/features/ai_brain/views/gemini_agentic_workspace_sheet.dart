import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/agentic_pulled_card.dart';
import '../../dashboard/view_models/dashboard_view_model.dart';
import '../../dashboard/views/ai_executive_briefing_card.dart' show GeminiLogoPainter;
import '../../dashboard/views/ai_companion_settings_sheet.dart';
import './saved_conversations_sheet.dart';
import '../../../../data/services/gemini_ai_service.dart';

class GeminiAgenticWorkspaceSheet extends StatefulWidget {
  const GeminiAgenticWorkspaceSheet({super.key});

  static Future<void> show(BuildContext context) {
    AppHaptics.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GeminiAgenticWorkspaceSheet(),
    );
  }

  @override
  State<GeminiAgenticWorkspaceSheet> createState() => _GeminiAgenticWorkspaceSheetState();
}

class _GeminiAgenticWorkspaceSheetState extends State<GeminiAgenticWorkspaceSheet>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AgenticChatMessage> _messages = [];

  String _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
  bool _isThinking = false;
  bool _isTyping = false;
  AgenticChatMessage? _lastFullResponse;
  late AnimationController _rotationController;
  Timer? _typewriterTimer;

  final List<String> _quickPrompts = [
    '📊 Pull up SNOW',
    '🎯 Top 4 Radar Picks',
    '🛡️ Capital & Risk Shield',
    '🕋 AAOIFI Debt Audit',
    '🧬 Canary AI Sandbox',
    '⚡ Sentinel Controls',
    '💰 Audited Ledger',
  ];

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initDefaultGreeting();
      }
    });
  }

  void _initDefaultGreeting() {
    setState(() {
      _messages.clear();
    });
  }

  void _autoSaveCurrentSession() {
    if (!mounted || _messages.isEmpty) return;
    final userMsgs = _messages.where((m) => m.isUser).toList();
    String title = 'Quant Market Analysis';
    if (userMsgs.isNotEmpty) {
      title = userMsgs.first.text.trim();
      if (title.length > 34) {
        title = '${title.substring(0, 32)}...';
      }
    }

    final session = GeminiConversationSession(
      id: _currentSessionId,
      title: title,
      updatedAt: DateTime.now(),
      messages: List<AgenticChatMessage>.from(_messages),
    );
    context.read<GeminiAiService>().saveConversation(session);
  }

  void _startNewChat() {
    AppHaptics.mediumImpact();
    _typewriterTimer?.cancel();
    setState(() {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _isThinking = false;
    });
    _initDefaultGreeting();
    _scrollToBottom();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.charcoalCard,
        content: Row(
          children: [
            const Icon(Icons.add_comment_rounded, color: AppTheme.referenceOrange, size: 16),
            const SizedBox(width: 8),
            Text(
              'New conversation started',
              style: GoogleFonts.spaceMono(color: AppTheme.textWhite, fontSize: 12),
            ),
          ],
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _loadPastSession(GeminiConversationSession session) {
    AppHaptics.mediumImpact();
    _typewriterTimer?.cancel();
    setState(() {
      _currentSessionId = session.id;
      _messages.clear();
      _messages.addAll(session.messages);
      _isThinking = false;
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _rotationController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  Future<void> _handleSendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    AppHaptics.selectionClick();
    _textController.clear();

    final userMsg = AgenticChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: query,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isThinking = true;
    });
    _scrollToBottom();
    _autoSaveCurrentSession();

    final viewModel = context.read<DashboardViewModel>();
    final geminiService = context.read<GeminiAiService>();

    final response = await geminiService.askAgenticPartner(
      userQuery: query,
      state: viewModel.state,
      positions: viewModel.positions,
      setups: viewModel.potentialPurchases,
      shariahAudits: viewModel.telemetryService.shariahAudits,
      decisions: viewModel.telemetryService.botDecisions,
      history: List<AgenticChatMessage>.from(_messages),
    );

    if (!mounted) return;

    // Stream the Gemini response with a high-framerate fluid typewriter
    _streamGeminiResponse(response);
  }

  void _completeTypewriterImmediately() {
    if (_isTyping && _lastFullResponse != null) {
      _typewriterTimer?.cancel();
      _isTyping = false;
      if (mounted && _messages.isNotEmpty) {
        setState(() {
          _messages[_messages.length - 1] = _lastFullResponse!;
        });
        AppHaptics.lightClick();
        _autoSaveCurrentSession();
        _scrollToBottom();
      }
    }
  }

  void _streamGeminiResponse(AgenticChatMessage fullResponse) {
    setState(() {
      _isThinking = false;
    });

    final fullText = fullResponse.text;
    _lastFullResponse = fullResponse;
    _isTyping = true;

    final streamingMsg = AgenticChatMessage(
      id: fullResponse.id,
      text: '',
      isUser: false,
      timestamp: fullResponse.timestamp,
      actionType: AgenticActionType.none, // Reveal card after typing completes
      payload: fullResponse.payload,
    );

    setState(() {
      _messages.add(streamingMsg);
    });

    _typewriterTimer?.cancel();
    int charIndex = 0;
    int tickCount = 0;

    void step() {
      if (!mounted) return;

      if (charIndex < fullText.length) {
        // Fluid streaming cadence: 1 char default, adaptive 2-char pacing for long paragraphs
        int charsToTake = 1;
        if (fullText.length > 220 && (charIndex + 2) <= fullText.length) {
          final probe = fullText[charIndex];
          if (probe != '.' && probe != '!' && probe != '?' && probe != ',' && probe != '\n') {
            charsToTake = 2;
          }
        }

        charIndex = (charIndex + charsToTake).clamp(0, fullText.length);
        final currentSub = fullText.substring(0, charIndex);
        final nextChar = fullText[charIndex - 1];

        setState(() {
          _messages[_messages.length - 1] = AgenticChatMessage(
            id: fullResponse.id,
            text: currentSub,
            isUser: false,
            timestamp: fullResponse.timestamp,
            actionType: charIndex >= fullText.length ? fullResponse.actionType : AgenticActionType.none,
            payload: fullResponse.payload,
          );
        });

        // Smooth continuous gliding scroll (no jerky jumps)
        tickCount++;
        if (tickCount % 6 == 0 || charIndex >= fullText.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              final max = _scrollController.position.maxScrollExtent;
              final current = _scrollController.position.pixels;
              if ((max - current) < 220) {
                _scrollController.animateTo(
                  max,
                  duration: const Duration(milliseconds: 90),
                  curve: Curves.easeOutCubic,
                );
              }
            }
          });
        }

        // Natural, buttery smooth cadence:
        // - Steady 20ms character stream (~50 chars/sec)
        // - Micro-breath on punctuation without jarring halts
        int delayMs = 20;
        if (nextChar == '.' || nextChar == '!' || nextChar == '?') {
          delayMs = 85;
        } else if (nextChar == ',' || nextChar == ';' || nextChar == ':' || nextChar == '—' || nextChar == '-') {
          delayMs = 45;
        } else if (nextChar == '\n') {
          delayMs = 60;
        }

        _typewriterTimer = Timer(Duration(milliseconds: delayMs), step);
      } else {
        _isTyping = false;
        AppHaptics.lightClick();
        _autoSaveCurrentSession();
        _scrollToBottom();
      }
    }

    _typewriterTimer = Timer(const Duration(milliseconds: 50), step);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Transform.translate(
          offset: Offset(0, 24 * (1.0 - animValue)),
          child: Opacity(
            opacity: animValue,
            child: child,
          ),
        );
      },
      child: Container(
        height: screenHeight * 0.88,
        decoration: BoxDecoration(
          color: AppTheme.appBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppTheme.charcoalBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 30,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // 1. Sheet Grabber & Header
            _buildHeader(context),

            // 2. Quick Action Prompt Chips
            _buildPromptChips(),

            // 3. Message Feed
            Expanded(
              child: _messages.isEmpty && !_isThinking
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: const SizedBox.expand(),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length + (_isThinking ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isThinking) {
                          return const _ThinkingWaveBubble();
                        }
                        final msg = _messages[index];
                        return _SmoothAnimatedBubble(
                          key: ValueKey(msg.id),
                          child: _buildMessageBubble(msg),
                        );
                      },
                    ),
            ),

            // 4. Input Bar
            Container(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                top: 10,
                bottom: bottomInset > 0 ? bottomInset + 10 : 20,
              ),
              decoration: BoxDecoration(
                color: AppTheme.charcoalCard,
                border: Border(
                  top: BorderSide(color: AppTheme.charcoalBorder),
                ),
              ),
              child: Row(
                children: [
                  // Text Input Field
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.charcoalInnerPill,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.charcoalInnerBorder),
                      ),
                      child: TextField(
                        controller: _textController,
                        onSubmitted: _handleSendMessage,
                        style: GoogleFonts.inter(color: AppTheme.textWhite, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Ask Gemini anything or give a command...',
                          hintStyle: GoogleFonts.inter(color: AppTheme.textMuted.withValues(alpha: 0.7), fontSize: 12.5),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send Button
                  GestureDetector(
                    onTap: () => _handleSendMessage(_textController.text),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.referenceOrange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.referenceOrange.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 18, right: 14, top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        border: Border(
          bottom: BorderSide(color: AppTheme.charcoalBorder),
        ),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.charcoalInnerBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      child: AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(24, 24),
                            painter: GeminiLogoPainter(
                              rotationAngle: _rotationController.value * 2 * 3.14159,
                              shimmerAngle: _rotationController.value * 2 * 3.14159,
                              pulseScale: 1.0,
                              splitFactor: 0.0,
                              isThinking: _isThinking,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Text(
                                  'Gemini Agentic Partner',
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textWhite,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mint.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '3.1 FLASH',
                                    style: GoogleFonts.spaceMono(
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.mint,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Full-System Quantitative Co-Pilot',
                            style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      AppHaptics.lightClick();
                      SavedConversationsSheet.show(
                        context,
                        onSelectSession: _loadPastSession,
                        onNewChat: _startNewChat,
                      );
                    },
                    icon: const Icon(Icons.history_rounded, color: AppTheme.textMuted, size: 20),
                    tooltip: 'Saved Conversations',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    onPressed: _startNewChat,
                    icon: const Icon(Icons.add_comment_outlined, color: AppTheme.textWhite, size: 19),
                    tooltip: 'New Chat Session',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    onPressed: () {
                      AppHaptics.lightClick();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const AiCompanionSettingsSheet(),
                      );
                    },
                    icon: const Icon(Icons.tune_rounded, color: AppTheme.textMuted, size: 19),
                    tooltip: 'AI Model & Key Settings',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 21),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromptChips() {
    return Container(
      height: 42,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _quickPrompts.length,
        itemBuilder: (context, index) {
          final prompt = _quickPrompts[index];
          return _SmoothPromptChip(
            prompt: prompt,
            onTap: () => _handleSendMessage(prompt),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(AgenticChatMessage msg) {
    if (msg.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 40),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.referenceOrange.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
              border: Border.all(color: AppTheme.referenceOrange.withValues(alpha: 0.4)),
            ),
            child: Text(
              msg.text,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                color: AppTheme.textWhite,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _completeTypewriterImmediately,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.charcoalCard,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(color: AppTheme.charcoalBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.mint,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'GEMINI INTEL',
                          style: GoogleFonts.spaceMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.geminiBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      msg.text,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.5,
                        color: AppTheme.textWhite.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Embedded Live Pulled Card with Animated Expansion
            AnimatedSize(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: msg.actionType != AgenticActionType.none
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: AgenticPulledCard(actionType: msg.actionType, payload: msg.payload),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Smooth Staggered Message Entrance Bubble
class _SmoothAnimatedBubble extends StatefulWidget {
  final Widget child;
  const _SmoothAnimatedBubble({super.key, required this.child});

  @override
  State<_SmoothAnimatedBubble> createState() => _SmoothAnimatedBubbleState();
}

class _SmoothAnimatedBubbleState extends State<_SmoothAnimatedBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: widget.child,
    );
  }
}

/// Smooth 3-Dot Wave Thinking Indicator
class _ThinkingWaveBubble extends StatefulWidget {
  const _ThinkingWaveBubble();

  @override
  State<_ThinkingWaveBubble> createState() => _ThinkingWaveBubbleState();
}

class _ThinkingWaveBubbleState extends State<_ThinkingWaveBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.charcoalCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final phase = (_waveController.value * 2 * math.pi) - (i * 0.7);
                      final offset = (1.0 + math.sin(phase)) * 2.5;
                      return Container(
                        margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                        width: 5.5,
                        height: 5.5,
                        transform: Matrix4.translationValues(0, -offset, 0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(
                'Gemini is analyzing & executing...',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF00E5FF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Springy Bouncy Prompt Chip
class _SmoothPromptChip extends StatefulWidget {
  final String prompt;
  final VoidCallback onTap;

  const _SmoothPromptChip({required this.prompt, required this.onTap});

  @override
  State<_SmoothPromptChip> createState() => _SmoothPromptChipState();
}

class _SmoothPromptChipState extends State<_SmoothPromptChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.charcoalCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.charcoalInnerBorder),
            ),
            child: Text(
              widget.prompt,
              style: GoogleFonts.spaceMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textWhite,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
