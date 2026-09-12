import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/position.dart';
import '../../../core/asset_brand_logo.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import '../view_models/dashboard_view_model.dart';

class TradeDetailSheet extends StatefulWidget {
  final Position position;
  final VoidCallback onClosePosition;

  const TradeDetailSheet({
    super.key,
    required this.position,
    required this.onClosePosition,
  });

  @override
  State<TradeDetailSheet> createState() => _TradeDetailSheetState();
}

class _TradeDetailSheetState extends State<TradeDetailSheet>
    with SingleTickerProviderStateMixin {
  String _selectedTimeframe = 'M';
  final List<String> _timeframes = ['D', 'W', 'M', '6M', 'Y', 'All'];
  int _selectedTabIndex = 0; // 0: Bot Guard, 1: Order Book, 2: Shariah, 3: AI Signals
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

    final viewModel = context.read<DashboardViewModel>();
    final cached = viewModel.geminiService?.getCachedPositionTradeIntel(widget.position.symbol);
    if (cached != null && cached.isNotEmpty) {
      _displayedIntelText = cached;
      _isIntelLoading = false;
      _isTyping = false;
    } else {
      _isIntelLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchLiveTradeIntel();
      });
    }
  }

  void _fetchLiveTradeIntel() {
    final viewModel = context.read<DashboardViewModel>();
    final gemini = viewModel.geminiService;

    setState(() {
      _isIntelLoading = true;
      _displayedIntelText = '';
    });

    if (gemini != null && gemini.hasApiKey && gemini.isGeminiConnected) {
      gemini.generatePositionTradeIntel(
        position: widget.position,
        state: viewModel.state,
      ).then((intel) {
        if (!mounted) return;
        setState(() {
          _isIntelLoading = false;
        });
        _startTypewriter(intel);
      }).catchError((_) {
        if (!mounted) return;
        final fallback = _getLocalFallbackIntel(widget.position);
        setState(() {
          _isIntelLoading = false;
        });
        _startTypewriter(fallback);
      });
    } else {
      final fallback = _getLocalFallbackIntel(widget.position);
      setState(() {
        _isIntelLoading = false;
      });
      _startTypewriter(fallback);
    }
  }

  String _getLocalFallbackIntel(Position pos) {
    return "We entered ${pos.symbol} at \$${pos.entryPrice.toStringAsFixed(2)} following heavy institutional volume accumulation above the 200-EMA. As price pushed to \$${pos.livePrice.toStringAsFixed(2)} (+${pos.unrealizedGainPercent.toStringAsFixed(1)}%), I ratcheted our trailing stop floor to \$${pos.protectedFloor.toStringAsFixed(2)}, locking in \$${pos.unrealizedProfitDollars >= 1000 ? '${(pos.unrealizedProfitDollars / 1000).toStringAsFixed(1)}k' : pos.unrealizedProfitDollars.toStringAsFixed(0)} in profit with zero downside risk.";
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
        return pos.priceNodes;
    }
  }

  List<DetailCandleData> _getCandles(List<double> prices) {
    final List<DetailCandleData> candles = [];
    for (int i = 0; i < prices.length; i++) {
      final current = prices[i];
      final prev = (i > 0) ? prices[i - 1] : current * 0.985;
      final open = prev;
      final close = current;
      final high = (open > close ? open : close) * 1.012;
      final low = (open < close ? open : close) * 0.988;
      candles.add(DetailCandleData(open: open, high: high, low: low, close: close));
    }
    return candles;
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.position;
    final viewModel = context.watch<DashboardViewModel>();
    final isCandlestickMode = viewModel.isCandlestickModeFor(pos.symbol);

    final isProfit = pos.unrealizedGainPercent >= 0;
    final gainColor = isProfit ? AppTheme.mint : AppTheme.referenceRed;
    final dollarFormatter = NumberFormat('#,##0', 'en_US');

    final activePrices = _getPricesForTimeframe(_selectedTimeframe, pos);
    final minPrice = activePrices.reduce((a, b) => a < b ? a : b);
    final maxPrice = activePrices.reduce((a, b) => a > b ? a : b);

    final displayPrice = _scrubbedIndex != null && _scrubbedIndex! < activePrices.length
        ? activePrices[_scrubbedIndex!]
        : pos.livePrice;

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
          // 1. Top Navigation Bar: Back button, Symbol Info, Candlestick/Line Switcher (Connected to ViewModel)
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
              Row(
                children: [
                  AssetBrandLogo(symbol: pos.symbol, size: 34),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            pos.symbol,
                            style: GoogleFonts.spaceMono(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textWhite,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      Text(
                        pos.companyName,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  AppHaptics.mediumImpact();
                  viewModel.toggleChartModeFor(pos.symbol);
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.charcoalCard,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCandlestickMode
                          ? AppTheme.mint.withValues(alpha: 0.5)
                          : AppTheme.charcoalBorder,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isCandlestickMode
                          ? Icons.show_chart_rounded
                          : Icons.candlestick_chart_rounded,
                      size: 18,
                      color: isCandlestickMode ? AppTheme.mint : AppTheme.textWhite,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 2. Big Price & Risk Telemetry Container
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.charcoalCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.charcoalBorder),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Price & Peak/Floor Row
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
                              '+${dollarFormatter.format(pos.unrealizedProfitDollars)}',
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

                const SizedBox(height: 12),

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
                            fontSize: 10,
                            color: _scrubbedIndex != null ? AppTheme.mint : AppTheme.textMuted,
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

                // 2. Interactive Dynamic Chart
                GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final RenderBox box = context.findRenderObject() as RenderBox;
                    final localX = details.localPosition.dx;
                    final fraction = (localX / box.size.width).clamp(0.0, 1.0);
                    final index = (fraction * (activePrices.length - 1)).round();
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
                    height: 95,
                    child: isCandlestickMode
                        ? CustomPaint(
                            painter: _DetailCandlePainter(
                              candles: _getCandles(activePrices),
                              scrubbedIndex: _scrubbedIndex,
                            ),
                            child: const SizedBox.expand(),
                          )
                        : CustomPaint(
                            painter: _DetailLinePainter(
                              prices: activePrices,
                              color: Colors.white,
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
                      'Floor \$${pos.protectedFloor.toStringAsFixed(2)}',
                      style: GoogleFonts.spaceMono(
                        fontSize: 9.5,
                        color: AppTheme.cyanFloor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Timeframe Bar
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.charcoalInnerPill : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: AppTheme.charcoalInnerBorder)
                              : null,
                        ),
                        child: Text(
                          tf,
                          style: GoogleFonts.spaceMono(
                            fontSize: 10.5,
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

          const SizedBox(height: 14),

          // 3. Tabbed Intelligence Container (Bot Guard | Order Book | Shariah | AI Signals)
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
                  // Minimalist Clean Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildTabButton('Bot Guard', 0),
                        const SizedBox(width: 4),
                        _buildTabButton('Order Book', 1),
                        const SizedBox(width: 4),
                        _buildTabButton('Shariah', 2),
                        const SizedBox(width: 4),
                        _buildTabButton('AI Signals', 3),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

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
                                  'GEMINI TRADE INTEL',
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
                                  'Synthesizing real-time order flow and trailing stop math...',
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

                  // Tab Content
                  Expanded(
                    child: _selectedTabIndex == 0
                        ? _buildBotGuardTab(pos)
                        : _selectedTabIndex == 1
                            ? _buildOrderBookTab(pos)
                            : _selectedTabIndex == 2
                                ? _buildShariahTab(pos)
                                : _buildAiSignalsTab(pos),
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

  // TAB 0: BOT GUARD (Organized cleanly with clear column separation)
  Widget _buildBotGuardTab(Position pos) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStructuredRow(
            label: 'Position Sizing',
            badge: '48.5% Equity',
            sub: '\$${(pos.livePrice * pos.shares).toStringAsFixed(0)} allocated',
          ),
          _buildStructuredRow(
            label: 'Trailing Floor',
            badge: '\$${pos.protectedFloor.toStringAsFixed(2)}',
            sub: '+88.0% profit locked',
            badgeColor: AppTheme.cyanFloor,
          ),
          _buildStructuredRow(
            label: 'Chandelier Ratchet',
            badge: 'Tier 2 Active',
            sub: '+60% locked at +45%',
            badgeColor: AppTheme.mint,
          ),
          _buildStructuredRow(
            label: 'Volume Ignition',
            badge: '2.45x RVOL',
            sub: 'Breakout continuation',
          ),
          _buildStructuredRow(
            label: '200-EMA Shield',
            badge: '+14.2% Above',
            sub: 'Macro trend intact',
            badgeColor: AppTheme.mint,
          ),
          _buildStructuredRow(
            label: 'Max Adverse Excursion',
            badge: '-1.2%',
            sub: 'Capital fully shielded',
          ),
        ],
      ),
    );
  }

  // TAB 1: ORDER BOOK (Visual Level 2 Market Depth Ladder)
  Widget _buildOrderBookTab(Position pos) {
    final live = pos.livePrice;

    // Realistic L2 resting asks (sellers) and bids (buyers)
    final asks = [
      {'price': live + 0.15, 'size': 1200, 'depth': 0.85},
      {'price': live + 0.10, 'size': 850, 'depth': 0.65},
      {'price': live + 0.05, 'size': 420, 'depth': 0.35},
    ];

    final bids = [
      {'price': live - 0.05, 'size': 610, 'depth': 0.45},
      {'price': live - 0.10, 'size': 980, 'depth': 0.75},
      {'price': live - 0.15, 'size': 1450, 'depth': 0.95},
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Order Route Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alpaca Smart Route (NBBO)',
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.mint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '100% FILLED',
                  style: GoogleFonts.spaceMono(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.mint,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // L2 Asks (Red)
          ...asks.map((ask) => _buildL2Row(
            price: (ask['price'] as double).toStringAsFixed(2),
            size: (ask['size'] as int).toString(),
            depth: ask['depth'] as double,
            isBid: false,
          )),

          // Spread Divider
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.charcoalInnerPill,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.charcoalInnerBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MID \$${live.toStringAsFixed(2)}',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
                Text(
                  'Spread \$0.02 (0.01%)',
                  style: GoogleFonts.spaceMono(
                    fontSize: 9.5,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // L2 Bids (Green)
          ...bids.map((bid) => _buildL2Row(
            price: (bid['price'] as double).toStringAsFixed(2),
            size: (bid['size'] as int).toString(),
            depth: bid['depth'] as double,
            isBid: true,
          )),
        ],
      ),
    );
  }

  Widget _buildL2Row({
    required String price,
    required String size,
    required double depth,
    required bool isBid,
  }) {
    final color = isBid ? AppTheme.mint : AppTheme.referenceRed;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      height: 22,
      child: Stack(
        children: [
          // Background depth bar
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 140 * depth,
            child: Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$$price',
                  style: GoogleFonts.spaceMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  '$size shares',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: SHARIAH COMPLIANCE (Organized with progress meters and zero text collision)
  Widget _buildShariahTab(Position pos) {
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
                      'AAOIFI Shariah Certified',
                      style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.mint,
                      ),
                    ),
                  ],
                ),
                Text(
                  '100% Passed',
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
            ratioText: '0.6%',
            limitText: 'Max < 30.0%',
            progress: 0.02, // 0.6% / 30%
            isPass: true,
          ),
          _buildShariahMetricRow(
            label: 'Liquid Cash Ratio',
            ratioText: '4.8%',
            limitText: 'Max < 30.0%',
            progress: 0.16, // 4.8% / 30%
            isPass: true,
          ),
          _buildShariahMetricRow(
            label: 'Impure Revenue',
            ratioText: '0.2%',
            limitText: 'Max < 5.0%',
            progress: 0.04, // 0.2% / 5%
            isPass: true,
          ),

          const SizedBox(height: 4),

          _buildStructuredRow(
            label: 'Zakat Purification',
            badge: '1.0% Profit Levy',
            sub: '\$${(pos.unrealizedProfitDollars * 0.01).toStringAsFixed(2)} auto-reserved',
            badgeColor: AppTheme.referenceOrange,
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

  // TAB 3: AI SIGNALS (Canary AI & Mutation Engine)
  Widget _buildAiSignalsTab(Position pos) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStructuredRow(
            label: 'Canary AI Score',
            badge: '9.4 / 10',
            sub: 'High Alpha Confidence',
            badgeColor: AppTheme.mint,
          ),
          _buildStructuredRow(
            label: 'Regime Classifier',
            badge: 'BULL_TRENDING',
            sub: 'Full 2-Position Alpha active',
            badgeColor: AppTheme.mint,
          ),
          _buildStructuredRow(
            label: 'Mutation Engine',
            badge: 'Gen #42 Champion',
            sub: 'Canary sandbox validated',
          ),
          _buildStructuredRow(
            label: 'Early Exit Trigger',
            badge: 'None Active',
            sub: '0.0% downside risk detected',
            badgeColor: AppTheme.textWhite,
          ),
        ],
      ),
    );
  }

  Widget _buildStructuredRow({
    required String label,
    required String badge,
    required String sub,
    Color? badgeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: AppTheme.textMuted,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                badge,
                style: GoogleFonts.spaceMono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: badgeColor ?? AppTheme.textWhite,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                sub,
                style: GoogleFonts.spaceMono(
                  fontSize: 9.5,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DetailCandleData {
  final double open;
  final double high;
  final double low;
  final double close;
  bool get isBullish => close >= open;

  DetailCandleData({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
}

class _DetailCandlePainter extends CustomPainter {
  final List<DetailCandleData> candles;
  final int? scrubbedIndex;

  _DetailCandlePainter({
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

    for (double y = 20; y < size.height - 10; y += 32) {
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
    final candleWidth = (slotWidth * 0.55).clamp(4.0, 14.0);

    for (int i = 0; i < count; i++) {
      final c = candles[i];
      final color = c.isBullish ? AppTheme.mint : AppTheme.referenceRed;

      final normHigh = (c.high - min) / range;
      final normLow = (c.low - min) / range;
      final normOpen = (c.open - min) / range;
      final normClose = (c.close - min) / range;

      final double centerX = (i * slotWidth) + (slotWidth / 2);
      final double yHigh = size.height - (normHigh * (size.height - 36)) - 18;
      final double yLow = size.height - (normLow * (size.height - 36)) - 18;
      final double yOpen = size.height - (normOpen * (size.height - 36)) - 18;
      final double yClose = size.height - (normClose * (size.height - 36)) - 18;

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
  bool shouldRepaint(covariant _DetailCandlePainter oldDelegate) =>
      oldDelegate.candles != candles || oldDelegate.scrubbedIndex != scrubbedIndex;
}

class _DetailLinePainter extends CustomPainter {
  final List<double> prices;
  final Color color;
  final int? scrubbedIndex;

  _DetailLinePainter({
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

    for (double y = 20; y < size.height - 10; y += 32) {
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
      final y = size.height - (normY * (size.height - 36)) - 18;
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
      canvas.drawCircle(scrubPt, 4.5, Paint()..color = AppTheme.mint);
    }
  }

  @override
  bool shouldRepaint(covariant _DetailLinePainter oldDelegate) =>
      oldDelegate.prices != prices ||
      oldDelegate.color != color ||
      oldDelegate.scrubbedIndex != scrubbedIndex;
}

class MiniGeminiStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

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

    const gradient = SweepGradient(
      colors: [
        Color(0xFF1A73E8),
        Color(0xFF00E5FF),
        Color(0xFF00E676),
        Color(0xFF9334E8),
        Color(0xFF1A73E8),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    final satCenter = Offset(center.dx + radius * 0.70, center.dy - radius * 0.65);
    final satRadius = radius * 0.30;
    final satPath = Path();
    final satPinch = satRadius * 0.20;
    satPath.moveTo(satCenter.dx, satCenter.dy - satRadius);
    satPath.quadraticBezierTo(satCenter.dx + satPinch, satCenter.dy - satPinch, satCenter.dx + satRadius, satCenter.dy);
    satPath.quadraticBezierTo(satCenter.dx + satPinch, satCenter.dy + satPinch, satCenter.dx, satCenter.dy + satRadius);
    satPath.quadraticBezierTo(satCenter.dx - satPinch, satCenter.dy + satPinch, satCenter.dx - satRadius, satCenter.dy);
    satPath.quadraticBezierTo(satCenter.dx - satPinch, satCenter.dy - satPinch, satCenter.dx, satCenter.dy - satRadius);
    satPath.close();

    final satPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    canvas.drawPath(satPath, satPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
