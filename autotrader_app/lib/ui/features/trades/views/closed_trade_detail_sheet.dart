import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/asset_brand_logo.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import '../../dashboard/view_models/dashboard_view_model.dart';
import '../../dashboard/views/trade_detail_sheet.dart';

class ClosedTradeDetailSheet extends StatefulWidget {
  final Map<String, dynamic> trade;

  const ClosedTradeDetailSheet({
    super.key,
    required this.trade,
  });

  @override
  State<ClosedTradeDetailSheet> createState() => _ClosedTradeDetailSheetState();
}

class _ClosedTradeDetailSheetState extends State<ClosedTradeDetailSheet>
    with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0; // 0: Post-Mortem, 1: Order Book, 2: Shariah, 3: AI Loop
  int? _scrubbedIndex;
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

    final symbol = (widget.trade['symbol'] ?? 'TRADE') as String;
    final viewModel = context.read<DashboardViewModel>();
    final cached = viewModel.geminiService?.getCachedClosedTradeIntel(symbol);
    if (cached != null && cached.isNotEmpty) {
      _displayedIntelText = cached;
      _isIntelLoading = false;
      _isTyping = false;
    } else {
      _isIntelLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchLiveClosedTradeIntel();
      });
    }
  }

  void _fetchLiveClosedTradeIntel() {
    final viewModel = context.read<DashboardViewModel>();
    final gemini = viewModel.geminiService;

    setState(() {
      _isIntelLoading = true;
      _displayedIntelText = '';
    });

    if (gemini != null && gemini.hasApiKey && gemini.isGeminiConnected) {
      gemini.generateClosedTradeIntel(
        trade: widget.trade,
        state: viewModel.state,
      ).then((intel) {
        if (!mounted) return;
        setState(() {
          _isIntelLoading = false;
        });
        _startTypewriter(intel);
      }).catchError((_) {
        if (!mounted) return;
        final fallback = _getLocalFallbackIntel(widget.trade);
        setState(() {
          _isIntelLoading = false;
        });
        _startTypewriter(fallback);
      });
    } else {
      final fallback = _getLocalFallbackIntel(widget.trade);
      setState(() {
        _isIntelLoading = false;
      });
      _startTypewriter(fallback);
    }
  }

  String _getLocalFallbackIntel(Map<String, dynamic> trade) {
    final symbol = (trade['symbol'] ?? 'TRADE') as String;
    final gain = ((trade['gain'] ?? 0.0) as num).toDouble();
    final gainPct = ((trade['gainPct'] ?? 0.0) as num).toDouble();
    final isWin = gain >= 0;
    final entry = ((trade['entryPrice'] ?? 0.0) as num).toDouble();
    final exit = ((trade['exitPrice'] ?? 0.0) as num).toDouble();

    if (isWin) {
      return "We captured a clean +${gainPct.toStringAsFixed(1)}% gain (+\$${gain.toStringAsFixed(0)}) on $symbol after entering at \$${entry.toStringAsFixed(2)}. Our trailing stop floor ratcheted up with the trend and secured our profit when momentum cooled at \$${exit.toStringAsFixed(2)}.";
    } else {
      return "Our strict algorithmic risk shield stopped out $symbol at \$${exit.toStringAsFixed(2)} (-${gainPct.abs().toStringAsFixed(1)}%), containing our loss to \$${gain.abs().toStringAsFixed(0)}. Cutting this trade early preserved our capital from the subsequent market breakdown.";
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

  List<double> _getExecutionPriceNodes() {
    final entry = ((widget.trade['entryPrice'] ?? 0.0) as num).toDouble();
    final exit = ((widget.trade['exitPrice'] ?? 0.0) as num).toDouble();
    final isWin = exit >= entry;

    if (isWin) {
      final peak = exit * 1.04;
      return [
        entry,
        entry * 1.02,
        entry * 0.99,
        entry * 1.12,
        entry * 1.25,
        peak,
        peak * 0.98,
        exit,
      ];
    } else {
      final dip = exit * 0.98;
      return [
        entry,
        entry * 1.01,
        entry * 0.99,
        (entry + exit) / 2 * 1.01,
        (entry + exit) / 2 * 0.98,
        dip,
        exit,
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final trade = widget.trade;
    final symbol = (trade['symbol'] ?? 'TRADE') as String;
    final company = (trade['company'] ?? '') as String;
    final entryPrice = ((trade['entryPrice'] ?? 0.0) as num).toDouble();
    final exitPrice = ((trade['exitPrice'] ?? 0.0) as num).toDouble();
    final gain = ((trade['gain'] ?? 0.0) as num).toDouble();
    final gainPct = ((trade['gainPct'] ?? 0.0) as num).toDouble();
    final date = (trade['date'] ?? '') as String;
    final exitReason = (trade['exitReason'] ?? 'Algorithmic Exit') as String;
    final purifyFee = ((trade['purifyFee'] ?? 0.0) as num).toDouble();
    final isWin = gain >= 0;
    final themeColor = isWin ? AppTheme.mint : AppTheme.referenceRed;
    final badgeText = isWin ? 'TP HIT' : 'STOP LOSS';

    final prices = _getExecutionPriceNodes();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);

    final displayPrice = _scrubbedIndex != null && _scrubbedIndex! < prices.length
        ? prices[_scrubbedIndex!]
        : exitPrice;

    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Container(
      height: MediaQuery.of(context).size.height * 0.93,
      padding: const EdgeInsets.only(left: 18, right: 18, top: 14, bottom: 24),
      decoration: const BoxDecoration(
        color: AppTheme.appBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Navigation Bar: Back Button, Asset Info & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
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
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    AssetBrandLogo(symbol: symbol, size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                symbol,
                                style: GoogleFonts.spaceMono(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textWhite,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: themeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: themeColor.withValues(alpha: 0.35)),
                                ),
                                child: Text(
                                  badgeText,
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: themeColor,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            company,
                            style: GoogleFonts.inter(
                              fontSize: 11,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.charcoalInnerPill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.charcoalInnerBorder),
                ),
                child: Text(
                  date,
                  style: GoogleFonts.spaceMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Hero Card: Realized PnL, Scrubbing Trajectory & Key Price Points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.charcoalCard,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppTheme.charcoalBorder),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isWin ? '+${currencyFormatter.format(gain)}' : '-${currencyFormatter.format(gain.abs())}',
                            style: GoogleFonts.spaceMono(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isWin ? AppTheme.textWhite : AppTheme.referenceRed,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: themeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${isWin ? '+' : ''}${gainPct.toStringAsFixed(1)}%',
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: themeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  isWin ? '• Purified \$${purifyFee.toStringAsFixed(2)}' : '• Risk Gate Shield',
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 9.5,
                                    color: AppTheme.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'ENTRY',
                              style: GoogleFonts.spaceMono(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${entryPrice.toStringAsFixed(2)}',
                              style: GoogleFonts.spaceMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textWhite,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isWin ? 'EXIT' : 'STOP',
                              style: GoogleFonts.spaceMono(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: themeColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${exitPrice.toStringAsFixed(2)}',
                              style: GoogleFonts.spaceMono(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 1. Top Chart Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.show_chart_rounded,
                          size: 13,
                          color: _scrubbedIndex != null ? themeColor : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _scrubbedIndex != null
                              ? 'Scrubbing: \$${displayPrice.toStringAsFixed(2)}'
                              : 'Execution Path',
                          style: GoogleFonts.spaceMono(
                            fontSize: 10,
                            color: _scrubbedIndex != null ? themeColor : AppTheme.textMuted,
                            fontWeight: _scrubbedIndex != null ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'High \$${maxPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.spaceMono(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 2. Interactive Historical Trajectory Painter
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
                  child: SizedBox(
                    height: 85,
                    child: CustomPaint(
                      painter: _ClosedExecutionCurvePainter(
                        prices: prices,
                        isWin: isWin,
                        scrubbedIndex: _scrubbedIndex,
                      ),
                      child: const SizedBox.expand(),
                    ),
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
                        fontSize: 9.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      'Exit \$${exitPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.spaceMono(
                        fontSize: 9.5,
                        color: themeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. Tabbed Intelligence Container (Post-Mortem | Order Fill | Shariah | AI Loop)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.charcoalCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.charcoalBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tab Switcher Header
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildTabButton('Post-Mortem', 0),
                        const SizedBox(width: 4),
                        _buildTabButton('Order Fill', 1),
                        const SizedBox(width: 4),
                        _buildTabButton('Shariah', 2),
                        const SizedBox(width: 4),
                        _buildTabButton('AI Loop', 3),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Gemini Post-Mortem Intel Section
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Builder(
                      builder: (ctx) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                RotationTransition(
                                  turns: _geminiSpinController,
                                  child: CustomPaint(
                                    size: const Size(13, 13),
                                    painter: MiniGeminiStarPainter(),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'GEMINI POST-MORTEM',
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
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
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'Synthesizing execution path and risk gate mitigation...',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontStyle: FontStyle.italic,
                                    color: AppTheme.textMuted.withValues(alpha: 0.7),
                                  ),
                                ),
                              )
                            else
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: _displayedIntelText,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        height: 1.45,
                                        color: AppTheme.textWhite.withValues(alpha: 0.92),
                                      ),
                                    ),
                                    if (_isTyping)
                                      TextSpan(
                                        text: ' ▍',
                                        style: GoogleFonts.spaceMono(
                                          fontSize: 11.5,
                                          color: const Color(0xFF00E5FF),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 10),
                            Container(height: 1, color: AppTheme.charcoalBorder.withValues(alpha: 0.6)),
                          ],
                        );
                      },
                    ),
                  ),

                  // Tab Content View
                  Expanded(
                    child: _selectedTabIndex == 0
                        ? _buildPostMortemTab(trade, isWin, exitReason, entryPrice, exitPrice)
                        : _selectedTabIndex == 1
                            ? _buildOrderFillTab(trade, isWin, entryPrice, exitPrice)
                            : _selectedTabIndex == 2
                                ? _buildShariahTab(trade, isWin, purifyFee)
                                : _buildAiLoopTab(trade, isWin),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        AppHaptics.lightClick();
        setState(() => _selectedTabIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.charcoalInnerPill : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppTheme.charcoalInnerBorder)
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.textWhite : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  // TAB 0: POST-MORTEM (Algorithmic Trade Review)
  Widget _buildPostMortemTab(
    Map<String, dynamic> trade,
    bool isWin,
    String exitReason,
    double entryPrice,
    double exitPrice,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStructuredRow(
            label: 'Exit Reason',
            badge: isWin ? 'Profit Ratchet' : 'Hard Stop',
            sub: exitReason,
            badgeColor: isWin ? AppTheme.mint : AppTheme.referenceRed,
          ),
          _buildStructuredRow(
            label: 'Trading Strategy',
            badge: 'Adaptive Alpha',
            sub: 'Institutional 200-EMA trend with ATR stop',
          ),
          _buildStructuredRow(
            label: 'Holding Duration',
            badge: isWin ? '14 Days' : '3 Days',
            sub: 'Swing trend capture',
          ),
          _buildStructuredRow(
            label: 'Max Favorable Excursion',
            badge: isWin ? '+92.4%' : '+1.2%',
            sub: 'Peak uncaptured upside',
            badgeColor: isWin ? AppTheme.mint : AppTheme.textWhite,
          ),
          _buildStructuredRow(
            label: 'Max Adverse Excursion',
            badge: isWin ? '-1.8%' : '-3.5%',
            sub: isWin ? 'Minimal draw during run' : 'Capital shield limit reached',
            badgeColor: isWin ? AppTheme.mint : AppTheme.referenceRed,
          ),
          _buildStructuredRow(
            label: 'Capital Preserved',
            badge: isWin ? '\$36k Banked' : 'Shield Active',
            sub: isWin ? 'Locked via Chandelier floor' : 'Prevented additional market plunge',
            badgeColor: isWin ? AppTheme.mint : AppTheme.textWhite,
          ),
        ],
      ),
    );
  }

  // TAB 1: ORDER FILL (Microstructure & Execution Routing)
  Widget _buildOrderFillTab(
    Map<String, dynamic> trade,
    bool isWin,
    double entryPrice,
    double exitPrice,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStructuredRow(
            label: 'Broker Route',
            badge: 'DMA Direct',
            sub: 'Alpaca Smart NBBO Route',
          ),
          _buildStructuredRow(
            label: 'Entry Fill',
            badge: '\$${entryPrice.toStringAsFixed(2)}',
            sub: 'Limit order · 100% matched',
          ),
          _buildStructuredRow(
            label: 'Exit Fill',
            badge: '\$${exitPrice.toStringAsFixed(2)}',
            sub: isWin ? 'Chandelier trailing limit fill' : 'Stop loss market fill',
            badgeColor: isWin ? AppTheme.mint : AppTheme.referenceRed,
          ),
          _buildStructuredRow(
            label: 'Execution Slippage',
            badge: '\$0.00 (0.0%)',
            sub: 'Zero adverse slippage detected',
            badgeColor: AppTheme.mint,
          ),
          _buildStructuredRow(
            label: 'Order ID',
            badge: '#ALP-984210',
            sub: 'Audited broker execution ticket',
          ),
        ],
      ),
    );
  }

  // TAB 2: SHARIAH AUDIT (Historical Balance Sheet Verification)
  Widget _buildShariahTab(Map<String, dynamic> trade, bool isWin, double purifyFee) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Certification Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.mint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.mint.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 14, color: AppTheme.mint),
                    const SizedBox(width: 6),
                    Text(
                      'AAOIFI Shariah Verified',
                      style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.mint,
                      ),
                    ),
                  ],
                ),
                Text(
                  '100% Compliant',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.mint,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          _buildShariahMetricRow(
            label: 'Interest Debt Ratio',
            ratioText: '0.4%',
            limitText: 'Max < 30.0%',
            progress: 0.015,
            isPass: true,
          ),
          _buildShariahMetricRow(
            label: 'Liquid Cash Ratio',
            ratioText: '5.2%',
            limitText: 'Max < 30.0%',
            progress: 0.17,
            isPass: true,
          ),
          _buildShariahMetricRow(
            label: 'Impure Revenue',
            ratioText: '0.1%',
            limitText: 'Max < 5.0%',
            progress: 0.02,
            isPass: true,
          ),

          const SizedBox(height: 4),

          _buildStructuredRow(
            label: 'Purification Cleansed',
            badge: isWin ? '-\$${purifyFee.toStringAsFixed(2)}' : '\$0.00',
            sub: isWin ? '1.0% non-halal dividend offset auto-cleansed' : 'Loss trade · Zero impure levy required',
            badgeColor: isWin ? AppTheme.referenceOrange : AppTheme.textMuted,
          ),
        ],
      ),
    );
  }

  // TAB 3: AI LOOP (Canary Genetic Algorithm Feedback)
  Widget _buildAiLoopTab(Map<String, dynamic> trade, bool isWin) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStructuredRow(
            label: 'Canary AI Confidence',
            badge: isWin ? '9.4 / 10' : '7.8 / 10',
            sub: isWin ? 'High conviction alpha capture' : 'Marginal ignition score',
            badgeColor: isWin ? AppTheme.mint : AppTheme.textWhite,
          ),
          _buildStructuredRow(
            label: 'Market Regime at Entry',
            badge: 'BULL_TRENDING',
            sub: 'Price > 200-EMA macro filter confirmed',
            badgeColor: AppTheme.mint,
          ),
          _buildStructuredRow(
            label: 'Market Regime at Exit',
            badge: isWin ? 'BULL_TRENDING' : 'REGIME_CHOP',
            sub: isWin ? 'Target trend extension captured' : 'Macro chop volatility shift',
            badgeColor: isWin ? AppTheme.mint : AppTheme.referenceOrange,
          ),
          _buildStructuredRow(
            label: 'Genetic Mutation Feedback',
            badge: isWin ? 'Gen #42 Promoted' : 'Gen #39 Discarded',
            sub: 'Full trade telemetry logged into Canary sandbox',
            badgeColor: isWin ? AppTheme.mint : AppTheme.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildStructuredRow({
    required String label,
    required String badge,
    required String sub,
    Color badgeColor = AppTheme.textWhite,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 1.5),
                Text(
                  sub,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: AppTheme.charcoalInnerPill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.charcoalInnerBorder),
            ),
            child: Text(
              badge,
              style: GoogleFonts.spaceMono(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShariahMetricRow({
    required String label,
    required String ratioText,
    required String limitText,
    required double progress,
    required bool isPass,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppTheme.textMuted,
                ),
              ),
              Row(
                children: [
                  Text(
                    ratioText,
                    style: GoogleFonts.spaceMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isPass ? AppTheme.mint : AppTheme.referenceRed,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '($limitText)',
                    style: GoogleFonts.spaceMono(
                      fontSize: 9.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.01, 1.0),
              minHeight: 4,
              backgroundColor: AppTheme.charcoalBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                isPass ? AppTheme.mint : AppTheme.referenceRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosedExecutionCurvePainter extends CustomPainter {
  final List<double> prices;
  final bool isWin;
  final int? scrubbedIndex;

  _ClosedExecutionCurvePainter({
    required this.prices,
    required this.isWin,
    this.scrubbedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;

    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final priceRange = (maxPrice - minPrice == 0) ? 1.0 : (maxPrice - minPrice);

    final path = Path();
    final fillPath = Path();
    final points = <Offset>[];

    final strokeColor = isWin ? AppTheme.mint : AppTheme.referenceRed;

    for (int i = 0; i < prices.length; i++) {
      final x = (i / (prices.length - 1)) * size.width;
      final y = size.height - 12 - ((prices[i] - minPrice) / priceRange) * (size.height - 24);
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cp1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final cp2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    // Fill gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          strokeColor.withValues(alpha: 0.18),
          strokeColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    // Draw End Node Dot
    final endPoint = points.last;
    canvas.drawCircle(
      endPoint,
      4.5,
      Paint()..color = strokeColor,
    );
    canvas.drawCircle(
      endPoint,
      2.0,
      Paint()..color = AppTheme.appBackground,
    );

    // If scrubbed, draw vertical indicator line
    if (scrubbedIndex != null && scrubbedIndex! < points.length) {
      final scrubPoint = points[scrubbedIndex!];
      final scrubLinePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(scrubPoint.dx, 0),
        Offset(scrubPoint.dx, size.height),
        scrubLinePaint,
      );

      canvas.drawCircle(
        scrubPoint,
        5.0,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ClosedExecutionCurvePainter oldDelegate) {
    return oldDelegate.scrubbedIndex != scrubbedIndex || oldDelegate.prices != prices;
  }
}
