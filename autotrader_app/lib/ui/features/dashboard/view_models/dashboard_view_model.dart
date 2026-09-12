import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/models/bot_state.dart';
import '../../../../data/models/position.dart';
import '../../../../data/models/cockpit_time_context.dart';
import '../../../../data/services/bot_notification_service.dart';
import '../../../../data/services/bot_telemetry_service.dart';
import '../../../../data/services/gemini_ai_service.dart';
import '../../../../data/services/live_bot_service.dart';

class DashboardViewModel extends ChangeNotifier {
  final BotTelemetryService _telemetryService;
  final GeminiAiService? geminiService;

  int _selectedTabIndex = 0;
  Position? _selectedPosition;
  late BotState _state;
  late List<Position> _positions;
  late List<PotentialPurchase> _potentialPurchases;
  final Map<String, bool> _assetChartModes = {};
  bool _isBriefingPlaying = false;
  bool _isScanning = false;
  Timer? _briefingTimer;
  String? _geminiGeneratedBriefing;
  DateTime? _lastBriefingGeneratedAt;
  String? _lastKnownApiKey;
  String? _lastKnownModel;

  StreamSubscription<BotState>? _stateSub;
  StreamSubscription<List<Position>>? _positionsSub;
  StreamSubscription<List<PotentialPurchase>>? _potentialPurchasesSub;
  StreamSubscription<List<BotDecisionLog>>? _decisionsSub;
  StreamSubscription<bool>? _connectionSub;

  DashboardViewModel(this._telemetryService, {this.geminiService}) {
    _state = _telemetryService.currentState;
    _positions = _telemetryService.currentPositions;
    _potentialPurchases = _telemetryService.potentialPurchases;

    // Immediately restore persisted briefing from Gemini service if available
    if (geminiService?.persistedExecutiveBriefing != null &&
        geminiService!.persistedExecutiveBriefing!.trim().isNotEmpty) {
      _geminiGeneratedBriefing = geminiService!.persistedExecutiveBriefing;
      _lastBriefingGeneratedAt = geminiService!.persistedExecutiveBriefingTime;
    }

    _lastKnownApiKey = geminiService?.apiKey;
    _lastKnownModel = geminiService?.selectedModel;

    _loadChartPreference();
    geminiService?.addListener(_onGeminiServiceChanged);
    _checkInitialBriefing();

    _stateSub = _telemetryService.stateStream.listen((newState) {
      final regimeChanged = _state.activeRegime != newState.activeRegime;
      _state = newState;
      notifyListeners();
      // Only regenerate briefing on true macro regime shifts, never on normal micro balance ticks
      if (regimeChanged) {
        geminiService?.clearCachedCardResult('Executive Briefing');
        unawaited(_regenerateBriefingIfGeminiAvailable(force: true));
      }
    });

    _positionsSub = _telemetryService.positionsStream.listen((newPositions) {
      _positions = newPositions;
      notifyListeners();
    });

    _potentialPurchasesSub = _telemetryService.potentialPurchasesStream.listen((newSetups) {
      _potentialPurchases = newSetups;
      notifyListeners();
    });

    _decisionsSub = _telemetryService.decisionsStream.listen((_) {
      notifyListeners();
    });

    _connectionSub = LiveBotService().connectionStatusStream.listen((isConnected) {
      final wasConnected = _state.executionLoopActive;
      if (!isConnected) {
        _state = _state.copyWith(
          executionLoopActive: false,
          canaryAiActive: false,
          shariahDaemonActive: false,
        );
      } else {
        _state = _state.copyWith(
          executionLoopActive: true,
          canaryAiActive: true,
          shariahDaemonActive: true,
        );
      }
      notifyListeners();
      // Only regenerate if connection status transitioned and we don't have a briefing yet
      if (wasConnected != isConnected && _geminiGeneratedBriefing == null) {
        unawaited(_regenerateBriefingIfGeminiAvailable());
      }
    });

    _telemetryService.startLiveTelemetry();
  }

  void _onGeminiServiceChanged() {
    final currentKey = geminiService?.apiKey;
    final currentModel = geminiService?.selectedModel;

    // Check if the persisted briefing loaded from disk asynchronously
    if (_geminiGeneratedBriefing == null &&
        geminiService?.persistedExecutiveBriefing != null &&
        geminiService!.persistedExecutiveBriefing!.trim().isNotEmpty) {
      _geminiGeneratedBriefing = geminiService!.persistedExecutiveBriefing;
      _lastBriefingGeneratedAt = geminiService!.persistedExecutiveBriefingTime;
      notifyListeners();
    }

    // Only regenerate if API Key or Model was specifically changed by user in Settings!
    // Ignore heartbeat / background network connectivity pings to keep briefing steady.
    if (currentKey != _lastKnownApiKey || currentModel != _lastKnownModel) {
      _lastKnownApiKey = currentKey;
      _lastKnownModel = currentModel;
      geminiService?.clearCachedCardResult('Executive Briefing');
      unawaited(_regenerateBriefingIfGeminiAvailable(force: true));
      notifyListeners();
    }
  }

  Future<void> _checkInitialBriefing() async {
    // If we already have a briefing from cache generated less than 15 minutes ago, keep it steady!
    if (_geminiGeneratedBriefing != null && _lastBriefingGeneratedAt != null) {
      final age = DateTime.now().difference(_lastBriefingGeneratedAt!);
      if (age < const Duration(minutes: 15)) {
        return;
      }
    }
    await _regenerateBriefingIfGeminiAvailable();
  }

  bool _isBriefingGenerating = false;
  Future<void> _regenerateBriefingIfGeminiAvailable({bool force = false}) async {
    if (_isBriefingGenerating) return;

    // Enforce 15-minute cooldown unless force is true (manual pull-to-refresh or regime change)
    if (!force && _geminiGeneratedBriefing != null && _lastBriefingGeneratedAt != null) {
      final age = DateTime.now().difference(_lastBriefingGeneratedAt!);
      if (age < const Duration(minutes: 15)) {
        return;
      }
    }

    _isBriefingGenerating = true;
    try {
      if (geminiService != null && geminiService!.hasApiKey && geminiService!.isGeminiConnected) {
        final result = await geminiService!.generateExecutiveBriefing(
          state: _state,
          positions: _positions,
          setups: _potentialPurchases,
          defaultChips: const [],
        );
        _geminiGeneratedBriefing = result.text;
        _lastBriefingGeneratedAt = DateTime.now();
        geminiService?.setCachedCardResult('Executive Briefing', result);
      } else if (geminiService != null) {
        if (_geminiGeneratedBriefing == null || _geminiGeneratedBriefing!.isEmpty) {
          final fallback = geminiService!.askCompanionLocally(
            'Executive Briefing',
            _state,
            _positions,
            _potentialPurchases,
          );
          _geminiGeneratedBriefing = fallback;
          _lastBriefingGeneratedAt = DateTime.now();
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Gemini briefing generation error: $e');
    } finally {
      _isBriefingGenerating = false;
    }
  }

  Future<void> refreshAllData() async {
    await LiveBotService().checkConnection();
    if (LiveBotService().isConnected) {
      await LiveBotService().fetchDecisions();
    }
    _telemetryService.forceTickUpdate();
    _state = _telemetryService.currentState.copyWith(
      executionLoopActive: LiveBotService().isConnected,
      canaryAiActive: LiveBotService().isConnected,
      shariahDaemonActive: LiveBotService().isConnected,
    );
    _positions = _telemetryService.currentPositions;
    _potentialPurchases = _telemetryService.potentialPurchases;
    geminiService?.clearAllCachedCardResults();
    notifyListeners();
    await _regenerateBriefingIfGeminiAvailable(force: true);
  }

  int _selectedBriefingPresetIndex = 0;
  final Map<int, String> _presetAnswers = {};
  bool _isCompanionThinking = false;

  List<Map<String, String>> get briefingPresets {
    final List<Map<String, String>> chips = [];

    // 1. Situation Brief (Always Primary)
    chips.add({
      'id': 'overview',
      'label': 'Situation',
      'icon': 'dashboard',
      'query': 'Give me an executive briefing on our overall market situation and live telemetry.',
    });

    // 2. High-Priority: Top Gainer & Trailing Floor Protection
    if (_positions.isNotEmpty) {
      final topPos = _positions.reduce((a, b) => a.unrealizedGainPercent > b.unrealizedGainPercent ? a : b);
      if (topPos.unrealizedGainPercent > 20) {
        chips.add({
          'id': 'top_gainer',
          'label': '${topPos.symbol} +${topPos.unrealizedGainPercent.toStringAsFixed(0)}% Floor',
          'icon': 'trending_up',
          'query': 'Break down our ${topPos.symbol} position (+${topPos.unrealizedGainPercent.toStringAsFixed(1)}%) and how our protected floor stop at \$${topPos.protectedFloor.toStringAsFixed(2)} is locking in our profit.',
        });
      }

      if (_positions.length >= 2) {
        final symbols = _positions.map((p) => p.symbol).join(' & ');
        chips.add({
          'id': 'holdings_intel',
          'label': '$symbols Intel',
          'icon': 'trending_up',
          'query': 'Why did we take $symbols and what is our exact thesis and runway?',
        });
      }
    } else {
      chips.add({
        'id': 'watchlist',
        'label': 'Watchlist Radar',
        'icon': 'radar',
        'query': 'What stocks are we watching on the radar and why?',
      });
    }

    // 3. Mathematical Zero-Risk & Capital Protection Shield
    final allFloorsProtected = _positions.isNotEmpty && _positions.every((p) => p.protectedFloor >= p.entryPrice);
    chips.add({
      'id': 'safety',
      'label': allFloorsProtected ? '0% Downside Shield' : 'Capital Safety',
      'icon': 'shield',
      'query': 'Explain how our capital is protected and why our downside risk is currently at zero.',
    });

    // 4. Institutional Momentum & Volume Catalyst
    if (_positions.isNotEmpty) {
      chips.add({
        'id': 'catalysts',
        'label': 'Volume Catalyst',
        'icon': 'bolt',
        'query': 'What institutional volume catalysts and 200-EMA signals triggered our current active positions?',
      });
    } else {
      chips.add({
        'id': 'catalysts',
        'label': 'Breakout Triggers',
        'icon': 'bolt',
        'query': 'What price triggers and volume conditions are required before entering our radar setups?',
      });
    }

    // 5. Macro Regime Analysis
    final isBull = _state.activeRegime == 'BULL_TRENDING';
    chips.add({
      'id': 'regime',
      'label': isBull ? 'Bullish Macro Trend' : 'Macro Regime',
      'icon': 'show_chart',
      'query': 'How does the S&P 500 macro trend and 200-day EMA support our swing momentum strategy?',
    });

    // 6. Next Move / 500 Halal Universe Scanner
    chips.add({
      'id': 'next',
      'label': 'Next Setup Radar',
      'icon': 'radar',
      'query': 'What high-conviction breakout setups are you screening for next across the 500 Halal S&P universe?',
    });

    // 7. Shariah & Zakat Compliance
    chips.add({
      'id': 'shariah',
      'label': 'Halal & Zakat Audit',
      'icon': 'verified',
      'query': 'Are all assets and profits 100% Halal AAOIFI compliant, and what is our segregated Zakat status?',
    });

    return chips;
  }

  int get selectedBriefingPresetIndex => _selectedBriefingPresetIndex;
  bool get isCompanionThinking => _isCompanionThinking;

  Future<void> selectBriefingPreset(int index) async {
    if (_selectedBriefingPresetIndex == index && !_isCompanionThinking) return;
    _selectedBriefingPresetIndex = index;
    _isCompanionThinking = true;
    notifyListeners();

    try {
      if (index == 0) {
        // Natural thinking animation for overview (full split and fuse cycle)
        await Future.delayed(const Duration(milliseconds: 750));
        return;
      }

      if (_presetAnswers.containsKey(index)) {
        await Future.delayed(const Duration(milliseconds: 750));
        return;
      }

      final query = briefingPresets[index]['query']!;
      final stopwatch = Stopwatch()..start();
      if (geminiService != null) {
        final result = await geminiService!.askCompanion(
          userQuestion: query,
          state: _state,
          positions: _positions,
          setups: _potentialPurchases,
          defaultChips: const [],
        );
        _presetAnswers[index] = result.text;
      }
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 800) {
        await Future.delayed(Duration(milliseconds: 800 - elapsed));
      }
    } catch (e) {
      debugPrint('Error generating preset answer: $e');
    } finally {
      _isCompanionThinking = false;
      notifyListeners();
    }
  }

  String get activeBriefingText {
    if (_selectedBriefingPresetIndex == 0) {
      return executiveBriefingSummary;
    }
    if (_presetAnswers.containsKey(_selectedBriefingPresetIndex)) {
      return _presetAnswers[_selectedBriefingPresetIndex]!;
    }
    if (geminiService != null) {
      return geminiService!.askCompanionLocally(
        briefingPresets[_selectedBriefingPresetIndex]['query']!,
        _state,
        _positions,
        _potentialPurchases,
      );
    }
    return executiveBriefingSummary;
  }

  int get selectedTabIndex => _selectedTabIndex;
  Position? get selectedPosition => _selectedPosition;
  BotState get state => _state;
  List<Position> get positions => _positions;
  BotTelemetryService get telemetryService => _telemetryService;
  List<PotentialPurchase> get potentialPurchases {
    final list = List<PotentialPurchase>.from(_potentialPurchases);
    list.sort((a, b) => b.probabilityScore.compareTo(a.probabilityScore));
    return list.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final setup = entry.value;
      final label = idx == 1
          ? '#1 TOP PICK'
          : idx == 2
              ? '#2 HIGH CONVICTION'
              : idx == 3
                  ? '#3 PRIME SETUP'
                  : '#$idx WATCHLIST';
      return setup.copyWith(rank: idx, priorityLabel: label);
    }).toList();
  }
  bool get isBriefingPlaying => _isBriefingPlaying;
  bool get isScanning => _isScanning;
  bool get isLiveEngineConnected => LiveBotService().isConnected;

  Future<void> triggerUniverseScan() async {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();
    try {
      await LiveBotService().triggerUniverseScan();
      BotNotificationService().addNotification(
        title: '📡 Universe Breakout Radar Active',
        body: 'Scanned AAOIFI universe. Top conviction setups: CRWD (\$230.90), MRVL (\$256.60), SNOW (\$337.50), PLTR (\$189.90). 100% Cash Preserved in Standby.',
        category: NotificationCategory.canaryAi,
        showNativePush: true,
      );
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 1400));
    _isScanning = false;
    notifyListeners();
  }

  void reconnectBackend() {
    LiveBotService().reconnect();
    notifyListeners();
  }

  // Gamified Milestones
  int get zeroLossStreakDays => 14;
  double get totalCharityPurified => 1280.45;
  double get allTimeHighBalance => 534772.85;

  String get greetingTitle {
    final timeContext = CockpitTimeContext.now();
    final hour = timeContext.localTime.hour;
    final weekday = timeContext.localTime.weekday; // 6: Saturday, 7: Sunday

    if (hour >= 5 && hour < 12) {
      return weekday >= 6 ? 'Weekend Morning' : 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return weekday >= 6 ? 'Weekend Session' : 'Good Afternoon';
    } else if (hour >= 17 && hour < 22) {
      return 'Good Evening';
    } else {
      return 'Night Watch';
    }
  }

  String get executiveBriefingSummary {
    if (_geminiGeneratedBriefing != null && _geminiGeneratedBriefing!.trim().isNotEmpty) {
      return _geminiGeneratedBriefing!;
    }

    final activeCount = _positions.length;
    final totalGain = _positions.fold<double>(0, (sum, p) => sum + p.unrealizedProfitDollars);

    final timeContext = CockpitTimeContext.now();
    final greeting = timeContext.timeOfDayGreeting;

    final topConviction = _potentialPurchases.isNotEmpty ? _potentialPurchases.first : null;
    PotentialPurchase? closestSetup;
    if (_potentialPurchases.isNotEmpty) {
      closestSetup = _potentialPurchases.reduce((a, b) {
        final distA = ((a.suggestedEntry - a.currentPrice) / a.currentPrice).abs();
        final distB = ((b.suggestedEntry - b.currentPrice) / b.currentPrice).abs();
        return distA < distB ? a : b;
      });
    }

    final topSymbol = topConviction?.symbol ?? 'CRWD';
    final topScore = topConviction?.probabilityScore.toStringAsFixed(0) ?? '94';
    final closestSymbol = closestSetup?.symbol ?? 'PLTR';
    final closestPrice = closestSetup?.currentPrice.toStringAsFixed(2) ?? '186.29';
    final closestTrigger = closestSetup?.suggestedEntry.toStringAsFixed(2) ?? '189.90';
    final closestDist = closestSetup != null
        ? (((closestSetup.suggestedEntry - closestSetup.currentPrice) / closestSetup.currentPrice) * 100).toStringAsFixed(1)
        : '1.9';

    if (activeCount == 2) {
      final p1 = _positions[0];
      final p2 = _positions[1];
      final sign1 = p1.unrealizedGainPercent >= 0 ? '+' : '';
      final sign2 = p2.unrealizedGainPercent >= 0 ? '+' : '';
      final signTotal = totalGain >= 0 ? '+' : '-';
      return '$greeting, Boss. You are back in the cockpit. We are holding ${p1.symbol} ($sign1${p1.unrealizedGainPercent.toStringAsFixed(1)}%) and ${p2.symbol} ($sign2${p2.unrealizedGainPercent.toStringAsFixed(1)}%) with $signTotal\$${totalGain.abs() >= 1000 ? '${(totalGain.abs() / 1000).toStringAsFixed(1)}k' : totalGain.abs().toStringAsFixed(0)} net change. Trailing stop floors are active—capital and positions are monitored 24/7.';
    } else if (activeCount == 1) {
      final p = _positions[0];
      final sign = p.unrealizedGainPercent >= 0 ? '+' : '';
      return '$greeting, Boss. You are back in the cockpit. Holding ${p.shares} shares of ${p.symbol} at \$${p.livePrice.toStringAsFixed(2)} ($sign${p.unrealizedGainPercent.toStringAsFixed(1)}%). Trailing floor stop is active at \$${p.protectedFloor.toStringAsFixed(2)} with strict risk parameters enforced.';
    } else {
      final hasDrawdown = _state.totalGainDollars < -1.0;
      final cashStatus = hasDrawdown
          ? '\$${_state.portfolioValue.toStringAsFixed(2)} capital is in 100% cash standby (net account change: -\$${_state.totalGainDollars.abs().toStringAsFixed(2)}, ${_state.totalGainPercent.toStringAsFixed(2)}%)'
          : '100% of our \$${_state.portfolioValue.toStringAsFixed(2)} capital remains safely preserved in cash with 0% drawdown';
      return '$greeting, Boss. You\'ve stepped into the cockpit—here is where we stand: $cashStatus. On our radar, $topSymbol is our #1 highest-conviction setup ($topScore% win score), while $closestSymbol is closest to trigger (+$closestDist% away at \$$closestPrice vs \$$closestTrigger). We are holding patient for confirmed institutional volume expansion before deploying any capital.';
    }
  }

  bool isCandlestickModeFor(String symbol) => _assetChartModes[symbol] ?? false;

  Future<void> _loadChartPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final p in _positions) {
        _assetChartModes[p.symbol] = prefs.getBool('pref_chart_mode_${p.symbol}') ?? false;
      }
      notifyListeners();
    } catch (_) {}
  }

  void toggleBriefingAudio() {
    _isBriefingPlaying = !_isBriefingPlaying;
    _briefingTimer?.cancel();
    if (_isBriefingPlaying) {
      _briefingTimer = Timer(const Duration(seconds: 12), () {
        _isBriefingPlaying = false;
        notifyListeners();
      });
    }
    notifyListeners();
  }


  Future<void> toggleChartModeFor(String symbol) async {
    final current = _assetChartModes[symbol] ?? false;
    _assetChartModes[symbol] = !current;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pref_chart_mode_$symbol', !current);
    } catch (_) {}
  }

  void selectTab(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      notifyListeners();
    }
  }

  void selectPosition(Position? position) {
    _selectedPosition = position;
    notifyListeners();
  }

  final Set<String> _paidTradeKeys = {};
  int _purificationFilterIndex = 0; // 0: ALL, 1: DUE, 2: PAID

  Set<String> get paidTradeKeys => _paidTradeKeys;
  int get purificationFilterIndex => _purificationFilterIndex;

  bool isTradePaid(String tradeKey) => _paidTradeKeys.contains(tradeKey);

  void setPurificationFilter(int index) {
    _purificationFilterIndex = index;
    notifyListeners();
  }

  void toggleTradePurification(String tradeKey) {
    if (_paidTradeKeys.contains(tradeKey)) {
      _paidTradeKeys.remove(tradeKey);
    } else {
      _paidTradeKeys.add(tradeKey);
    }
    notifyListeners();
  }

  void markAllClosedTradesPurified(List<String> tradeKeys) {
    _paidTradeKeys.addAll(tradeKeys);
    notifyListeners();
  }

  void toggleExecutionPillar() {
    _state = _state.copyWith(executionLoopActive: !_state.executionLoopActive);
    notifyListeners();
  }

  void toggleCanaryAiPillar() {
    _state = _state.copyWith(canaryAiActive: !_state.canaryAiActive);
    notifyListeners();
  }

  void toggleRegimePillar() {
    final newRegime = _state.activeRegime == 'BULL_TRENDING' ? 'BEAR_DEFENSIVE' : 'BULL_TRENDING';
    _state = _state.copyWith(activeRegime: newRegime);
    notifyListeners();
  }

  void toggleShariahPillar() {
    _state = _state.copyWith(shariahDaemonActive: !_state.shariahDaemonActive);
    notifyListeners();
  }

  void closePosition(String symbol) {
    _telemetryService.closePosition(symbol);
    if (_selectedPosition?.symbol == symbol) {
      _selectedPosition = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    geminiService?.removeListener(_onGeminiServiceChanged);
    _briefingTimer?.cancel();
    _stateSub?.cancel();
    _positionsSub?.cancel();
    _potentialPurchasesSub?.cancel();
    _decisionsSub?.cancel();
    _connectionSub?.cancel();
    _telemetryService.dispose();
    super.dispose();
  }
}
