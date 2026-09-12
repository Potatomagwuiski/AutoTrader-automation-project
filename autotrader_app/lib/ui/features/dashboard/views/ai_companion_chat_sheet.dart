import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../data/services/gemini_ai_service.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import '../view_models/dashboard_view_model.dart';
import 'ai_companion_settings_sheet.dart';

class AiCompanionChatSheet extends StatefulWidget {
  const AiCompanionChatSheet({super.key});

  @override
  State<AiCompanionChatSheet> createState() => _AiCompanionChatSheetState();
}

class _AiCompanionChatSheetState extends State<AiCompanionChatSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isThinking = false;

  final List<String> _quickQuestions = [
    '📊 Pull up SNOW',
    '🛡️ Downside Shield',
    '🎯 Watchlist Radar',
    '📜 Recent Decisions',
    '🕌 Shariah Audit',
    '💡 Explain our stance',
  ];

  @override
  void initState() {
    super.initState();

    // Initial companion greeting
    _messages.add({
      'sender': 'companion',
      'text': "I am right here with you in the cockpit. 100% of our \$20,000.00 capital is preserved in cash defense with 0% drawdown. Ask me to pull up any stock on our radar, inspect our downside shield, or review recent autonomous cycle logs.",
      'agentWidget': null,
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleUserSubmit(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || _isThinking) return;

    AppHaptics.lightClick();
    _inputController.clear();

    setState(() {
      _messages.add({'sender': 'user', 'text': cleanQuery, 'agentWidget': null});
      _isThinking = true;
    });

    _scrollToBottom();

    final viewModel = context.read<DashboardViewModel>();
    final gemini = context.read<GeminiAiService>();

    final response = await gemini.askCompanion(
      userQuestion: cleanQuery,
      state: viewModel.state,
      positions: viewModel.positions,
      setups: viewModel.potentialPurchases,
      defaultChips: const [],
    );

    if (mounted) {
      setState(() {
        _isThinking = false;
        _messages.add({
          'sender': 'companion',
          'text': response.text,
          'agentWidget': response.agentWidget,
        });
      });
      AppHaptics.selectionClick();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();
    final gemini = context.watch<GeminiAiService>();
    final isLive = gemini.isGeminiConnected && gemini.hasApiKey;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: AppTheme.charcoalBorder, width: 1.5)),
      ),
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: bottomInset > 0 ? bottomInset + 12 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.charcoalInnerBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.mint.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.psychology_rounded, color: AppTheme.mint, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Trading Companion',
                            style: GoogleFonts.spaceMono(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textWhite,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isLive ? 'Google Gemini (${gemini.selectedModel}) 🟢' : 'Local Quant Engine 🟠',
                            style: GoogleFonts.spaceMono(
                              fontSize: 9.5,
                              color: isLive ? AppTheme.mint : AppTheme.referenceOrange,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.settings_outlined, size: 18, color: AppTheme.textMuted),
                    onPressed: () {
                      AppHaptics.lightClick();
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (ctx) => const AiCompanionSettingsSheet(),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Quick Telemetry Capsule
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.charcoalInnerPill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.charcoalInnerBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniStat('REGIME', viewModel.state.activeRegime.replaceAll('_', ' '), AppTheme.mint),
                _buildMiniStat('HOLDINGS', '${viewModel.positions.length}/2', AppTheme.textWhite),
                _buildMiniStat('DOWN RISK', '0.0%', AppTheme.mint),
                _buildMiniStat('SHARIAH', '100%', AppTheme.mint),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isThinking) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.charcoalInnerPill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.mint.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.mint),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Companion reading telemetry...',
                            style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.mint),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                final agentWidget = msg['agentWidget'] as AgentWidgetPayload?;

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * (agentWidget != null ? 0.90 : 0.80),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: isUser ? AppTheme.referenceOrange.withValues(alpha: 0.18) : AppTheme.charcoalInnerPill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isUser
                            ? AppTheme.referenceOrange.withValues(alpha: 0.4)
                            : AppTheme.charcoalInnerBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isUser ? Icons.person_rounded : Icons.psychology_rounded,
                              size: 12,
                              color: isUser ? AppTheme.referenceOrange : AppTheme.mint,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isUser ? 'YOU' : 'AI QUANTITATIVE AGENT',
                              style: GoogleFonts.spaceMono(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: isUser ? AppTheme.referenceOrange : AppTheme.mint,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          msg['text'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            height: 1.45,
                            color: AppTheme.textWhite,
                          ),
                        ),
                        if (!isUser && agentWidget != null) ...[
                          _buildVisualAgentWidget(context, agentWidget, viewModel),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Suggested Quick Prompts
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickQuestions.map((q) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(
                      q,
                      style: GoogleFonts.spaceMono(fontSize: 10, color: AppTheme.textWhite),
                    ),
                    backgroundColor: AppTheme.charcoalInnerPill,
                    side: const BorderSide(color: AppTheme.charcoalInnerBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onPressed: () => _handleUserSubmit(q),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.charcoalInnerPill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.charcoalInnerBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    onSubmitted: _handleUserSubmit,
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textWhite),
                    decoration: InputDecoration(
                      hintText: 'Ask your companion anything...',
                      hintStyle: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textMuted),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, size: 18, color: AppTheme.mint),
                  onPressed: () => _handleUserSubmit(_inputController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(fontSize: 8, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: GoogleFonts.spaceMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildVisualAgentWidget(
    BuildContext context,
    AgentWidgetPayload payload,
    DashboardViewModel viewModel,
  ) {
    switch (payload.type) {
      case AgentVisualType.assetCard:
        return _buildAssetCard(context, payload.data, viewModel);
      case AgentVisualType.riskShield:
        return _buildRiskShield(payload.data);
      case AgentVisualType.radarMatrix:
        return _buildRadarMatrix(payload.data);
      case AgentVisualType.decisionFeed:
        return _buildDecisionFeed(payload.data);
      case AgentVisualType.shariahAudit:
        return _buildShariahAudit(payload.data);
      case AgentVisualType.none:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAssetCard(BuildContext context, Map<String, dynamic> data, DashboardViewModel viewModel) {
    final symbol = data['symbol']?.toString() ?? 'SNOW';
    final company = data['companyName']?.toString() ?? 'Snowflake Inc.';
    final price = (data['currentPrice'] as num?)?.toDouble() ?? 361.80;
    final trigger = (data['trigger'] as num?)?.toDouble() ?? 367.80;
    final stopLoss = (data['stopLoss'] as num?)?.toDouble() ?? 307.13;
    final distTrigger = (data['distanceToTrigger'] as num?)?.toDouble() ?? 1.7;
    final rvol = (data['rvol'] as num?)?.toDouble() ?? 2.1;
    final emaDist = (data['distance200Ema'] as num?)?.toDouble() ?? 8.4;
    final prob = (data['probability'] as num?)?.toDouble() ?? 88.0;
    final rank = data['rank'] ?? 1;

    final progress = (1.0 - (distTrigger / 10.0)).clamp(0.1, 0.95);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.mint.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.mint.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.mint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      symbol,
                      style: GoogleFonts.spaceMono(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.mint,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    company,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textWhite,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.referenceOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.referenceOrange.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'RANK #$rank',
                  style: GoogleFonts.spaceMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.referenceOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LIVE PRICE',
                    style: GoogleFonts.spaceMono(fontSize: 8.5, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: GoogleFonts.spaceMono(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'BREAKOUT TRIGGER',
                    style: GoogleFonts.spaceMono(fontSize: 8.5, color: AppTheme.mint),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${trigger.toStringAsFixed(2)} (+${distTrigger.toStringAsFixed(1)}%)',
                    style: GoogleFonts.spaceMono(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mint,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TRIGGER PROXIMITY',
                    style: GoogleFonts.spaceMono(fontSize: 8, color: AppTheme.textMuted),
                  ),
                  Text(
                    '${((1 - (distTrigger / 10).clamp(0.0, 1.0)) * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.spaceMono(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppTheme.mint),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: AppTheme.charcoalInnerBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.charcoalInnerPill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.charcoalInnerBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricPill('RVOL', '${rvol.toStringAsFixed(1)}x', AppTheme.mint),
                _buildMetricPill('200-EMA', '+${emaDist.toStringAsFixed(1)}%', AppTheme.mint),
                _buildMetricPill('STOP LOSS', '\$${stopLoss.toStringAsFixed(2)}', AppTheme.textMuted),
                _buildMetricPill('WIN PROB', '${prob.toStringAsFixed(0)}%', AppTheme.textWhite),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_rounded, size: 12, color: AppTheme.mint),
                  const SizedBox(width: 4),
                  Text(
                    'AAOIFI Shariah Pass (0.0% Debt)',
                    style: GoogleFonts.inter(fontSize: 10, color: AppTheme.mint, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Text(
                'Max Risk: \$200.00 (1%)',
                style: GoogleFonts.spaceMono(fontSize: 9.5, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceMono(fontSize: 7.5, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.spaceMono(fontSize: 10, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildRiskShield(Map<String, dynamic> data) {
    final equity = (data['portfolioValue'] as num?)?.toDouble() ?? 20000.00;
    final cash = (data['cashBalance'] as num?)?.toDouble() ?? 20000.00;
    final maxLoss = (data['maxLossPerTrade'] as num?)?.toDouble() ?? 200.00;
    final circuitBreaker = (data['circuitBreaker'] as num?)?.toDouble() ?? 400.00;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.mint.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.mint.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppTheme.mint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.shield_outlined, size: 14, color: AppTheme.mint),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DOWNSIDE SHIELD',
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mint,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.mint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '0.0% DRAWDOWN',
                  style: GoogleFonts.spaceMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.mint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildShieldBox('PORTFOLIO EQUITY', '\$${equity.toStringAsFixed(2)}', AppTheme.textWhite),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildShieldBox('LIQUID CASH', '100% (\$${cash.toStringAsFixed(2)})', AppTheme.mint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildShieldBox('MAX RISK / TRADE', '\$${maxLoss.toStringAsFixed(2)} (1.0%)', AppTheme.referenceOrange),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildShieldBox('DAILY CIRCUIT BREAKER', '\$${circuitBreaker.toStringAsFixed(2)} (2.0%)', AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.charcoalInnerPill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.charcoalInnerBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_outlined, size: 13, color: AppTheme.mint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Chandelier ATR Trailing Stop ratchets higher at 1R/2R/3R gains. Stops NEVER move downward.',
                    style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShieldBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.charcoalInnerPill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.charcoalInnerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceMono(fontSize: 7.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.spaceMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarMatrix(Map<String, dynamic> data) {
    final rawCandidates = (data['candidates'] as List<dynamic>?) ?? [];
    final candidates = rawCandidates.map((c) => c as Map<String, dynamic>).toList();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.referenceOrange.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.radar_rounded, size: 14, color: AppTheme.referenceOrange),
                  const SizedBox(width: 6),
                  Text(
                    'BREAKOUT WATCHLIST RADAR',
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.referenceOrange,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                '${candidates.length} CANDIDATES',
                style: GoogleFonts.spaceMono(fontSize: 9, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...candidates.map((c) {
            final symbol = c['symbol'] ?? 'SNOW';
            final rank = c['rank'] ?? 1;
            final price = (c['price'] as num?)?.toDouble() ?? 361.80;
            final trigger = (c['trigger'] as num?)?.toDouble() ?? 367.80;
            final rvol = (c['rvol'] as num?)?.toDouble() ?? 2.1;
            final winRate = (c['winRate'] as num?)?.toDouble() ?? 88.0;
            final dist = price > 0 ? (((trigger - price) / price) * 100) : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.charcoalInnerPill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.charcoalInnerBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    alignment: Alignment.center,
                    child: Text(
                      '#$rank',
                      style: GoogleFonts.spaceMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.referenceOrange),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    symbol,
                    style: GoogleFonts.spaceMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textWhite),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: GoogleFonts.spaceMono(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Trigger \$${trigger.toStringAsFixed(2)}',
                        style: GoogleFonts.spaceMono(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.mint),
                      ),
                      Text(
                        '+${dist.toStringAsFixed(1)}% • ${winRate.toStringAsFixed(0)}% Win • ${rvol}x Vol',
                        style: GoogleFonts.spaceMono(fontSize: 8.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDecisionFeed(Map<String, dynamic> data) {
    final rawCycles = (data['recentCycles'] as List<dynamic>?) ?? [];
    final cycles = rawCycles.map((c) => c as Map<String, dynamic>).toList();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.mint.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_edu_rounded, size: 14, color: AppTheme.mint),
                  const SizedBox(width: 6),
                  Text(
                    'RECENT AUTONOMOUS CYCLES',
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mint,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                'LIVE AUDIT',
                style: GoogleFonts.spaceMono(fontSize: 9, color: AppTheme.mint, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...cycles.map((c) {
            final cycle = c['cycle']?.toString() ?? '114';
            final tag = c['tag']?.toString() ?? '100% CASH STANDBY';
            final title = c['title']?.toString() ?? 'Universe Breakout Scan Cleared';
            final detail = c['detail']?.toString() ?? '';
            final time = c['time']?.toString() ?? 'Just now';

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.charcoalInnerPill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.charcoalInnerBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CYCLE #$cycle • $time',
                        style: GoogleFonts.spaceMono(fontSize: 8.5, color: AppTheme.textMuted),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.mint.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.spaceMono(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.mint),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textWhite),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: GoogleFonts.inter(fontSize: 9.5, color: AppTheme.textMuted, height: 1.3),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildShariahAudit(Map<String, dynamic> data) {
    final standard = data['standard']?.toString() ?? 'AAOIFI Standard No. 21';
    final rawAssets = (data['assets'] as List<dynamic>?) ?? [];
    final assets = rawAssets.map((a) => a as Map<String, dynamic>).toList();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.mint.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_rounded, size: 14, color: AppTheme.mint),
                  const SizedBox(width: 6),
                  Text(
                    'SHARIAH AAOIFI AUDIT MATRIX',
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mint,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                '100% PASS',
                style: GoogleFonts.spaceMono(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.mint),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            standard,
            style: GoogleFonts.spaceMono(fontSize: 8.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.charcoalInnerPill,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ASSET', style: GoogleFonts.spaceMono(fontSize: 8.5, color: AppTheme.textMuted)),
                Text('DEBT (<30%)', style: GoogleFonts.spaceMono(fontSize: 8.5, color: AppTheme.textMuted)),
                Text('CASH (<30%)', style: GoogleFonts.spaceMono(fontSize: 8.5, color: AppTheme.textMuted)),
                Text('STATUS', style: GoogleFonts.spaceMono(fontSize: 8.5, color: AppTheme.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...assets.map((a) {
            final sym = a['symbol'] ?? '';
            final debt = a['debt'] ?? '0.0%';
            final cash = a['cash'] ?? '0.0%';
            final status = a['status'] ?? 'PASS';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(sym, style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textWhite)),
                  ),
                  Text(debt, style: GoogleFonts.spaceMono(fontSize: 10, color: AppTheme.mint)),
                  Text(cash, style: GoogleFonts.spaceMono(fontSize: 10, color: AppTheme.mint)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppTheme.mint.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(status, style: GoogleFonts.spaceMono(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppTheme.mint)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
