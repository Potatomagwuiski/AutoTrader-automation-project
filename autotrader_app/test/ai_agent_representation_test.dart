import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:autotrader_app/data/models/bot_state.dart';
import 'package:autotrader_app/data/services/bot_telemetry_service.dart';
import 'package:autotrader_app/data/services/gemini_ai_service.dart';
import 'package:autotrader_app/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:autotrader_app/ui/features/dashboard/views/ai_companion_chat_sheet.dart';
import 'package:autotrader_app/ui/features/ai_brain/views/gemini_agentic_workspace_sheet.dart';
import 'package:autotrader_app/data/models/cockpit_time_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mockState = BotState(
    portfolioValue: 20000.00,
    cashBalance: 20000.00,
    buyingPower: 20000.00,
    activeRegime: 'BULL_TRENDING',
    executionLoopActive: true,
    canaryAiActive: true,
    shariahDaemonActive: true,
  );

  final List<PotentialPurchase> mockSetups = [
    const PotentialPurchase(
      rank: 1,
      priorityLabel: '#1 TOP PICK',
      symbol: 'SNOW',
      companyName: 'Snowflake Inc.',
      currentPrice: 361.80,
      suggestedEntry: 367.80,
      suggestedStopLoss: 307.13,
      rvol: 2.1,
      distance200Ema: 8.4,
      probabilityScore: 88,
      setupReason: 'Breakout above 200-EMA',
    ),
    const PotentialPurchase(
      rank: 2,
      priorityLabel: '#2 RUNNER UP',
      symbol: 'PLTR',
      companyName: 'Palantir Technologies',
      currentPrice: 184.20,
      suggestedEntry: 189.90,
      suggestedStopLoss: 172.81,
      rvol: 1.9,
      distance200Ema: 6.2,
      probabilityScore: 84,
      setupReason: 'Institutional accumulation breakout',
    ),
  ];

  group('Gemini Autonomous Agent Visual Payload Tests', () {
    final gemini = GeminiAiService();

    test('buildAgentWidget creates assetCard for SNOW query', () {
      final widget = gemini.buildAgentWidget(
        userQuery: 'Pull up SNOW',
        state: mockState,
        positions: [],
        setups: mockSetups,
      );

      expect(widget, isNotNull);
      expect(widget!.type, equals(AgentVisualType.assetCard));
      expect(widget.data['symbol'], equals('SNOW'));
      expect(widget.data['currentPrice'], equals(361.80));
      expect(widget.data['trigger'], equals(367.80));
    });

    test('buildAgentWidget creates riskShield for risk query', () {
      final widget = gemini.buildAgentWidget(
        userQuery: 'Show downside shield and risk limits',
        state: mockState,
        positions: [],
        setups: mockSetups,
      );

      expect(widget, isNotNull);
      expect(widget!.type, equals(AgentVisualType.riskShield));
      expect(widget.data['portfolioValue'], equals(20000.00));
      expect(widget.data['drawdown'], equals(0.0));
      expect(widget.data['maxLossPerTrade'], equals(200.00));
    });

    test('buildAgentWidget creates radarMatrix for watchlist query', () {
      final widget = gemini.buildAgentWidget(
        userQuery: 'What are our top breakout radar setups?',
        state: mockState,
        positions: [],
        setups: mockSetups,
      );

      expect(widget, isNotNull);
      expect(widget!.type, equals(AgentVisualType.radarMatrix));
      final candidates = widget.data['candidates'] as List;
      expect(candidates.length, equals(2));
      expect(candidates.first['symbol'], equals('SNOW'));
    });

    test('buildAgentWidget creates decisionFeed for cycles query', () {
      final widget = gemini.buildAgentWidget(
        userQuery: 'What did the bot do recently in autonomous cycles?',
        state: mockState,
        positions: [],
        setups: mockSetups,
      );

      expect(widget, isNotNull);
      expect(widget!.type, equals(AgentVisualType.decisionFeed));
      final cycles = widget.data['recentCycles'] as List;
      expect(cycles.isNotEmpty, isTrue);
      expect(cycles.first['cycle'], equals('114'));
    });

    test('buildAgentWidget creates shariahAudit for Halal query', () {
      final widget = gemini.buildAgentWidget(
        userQuery: 'Show shariah compliance and debt ratios',
        state: mockState,
        positions: [],
        setups: mockSetups,
      );

      expect(widget, isNotNull);
      expect(widget!.type, equals(AgentVisualType.shariahAudit));
      expect(widget.data['standard'], contains('AAOIFI'));
      final assets = widget.data['assets'] as List;
      expect(assets.length, equals(4));
    });
  });

  group('AiCompanionChatSheet Widget Rendering Test', () {
    testWidgets('renders AiCompanionChatSheet with initial greeting and agent controls', (tester) async {
      final telemetry = BotTelemetryService();
      final gemini = GeminiAiService();
      final viewModel = DashboardViewModel(telemetry, geminiService: gemini);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: viewModel),
            ChangeNotifierProvider.value(value: gemini),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AiCompanionChatSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AI QUANTITATIVE AGENT'), findsOneWidget);
      expect(find.textContaining('100% of our \$20,000.00 capital is preserved in cash defense'), findsOneWidget);
      expect(find.text('📊 Pull up SNOW'), findsOneWidget);
      expect(find.text('🛡️ Downside Shield'), findsOneWidget);

      viewModel.dispose();
      gemini.dispose();
      telemetry.dispose();
    });

    testWidgets('tapping Pull up SNOW chip triggers agent assetCard widget', (tester) async {
      final telemetry = BotTelemetryService();
      final gemini = GeminiAiService();
      final viewModel = DashboardViewModel(telemetry, geminiService: gemini);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: viewModel),
            ChangeNotifierProvider.value(value: gemini),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AiCompanionChatSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter "Pull up SNOW" in TextField and send
      await tester.enterText(find.byType(TextField), 'Pull up SNOW');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // Verify the visual agent asset card rendered
      expect(find.text('SNOW'), findsWidgets);
      expect(find.text('BREAKOUT TRIGGER'), findsOneWidget);
      expect(find.text('TRIGGER PROXIMITY'), findsOneWidget);
      expect(find.textContaining('AAOIFI Shariah Pass'), findsOneWidget);

      viewModel.dispose();
      gemini.dispose();
      telemetry.dispose();
    });

    testWidgets('submitting Downside Shield query triggers agent riskShield widget', (tester) async {
      final telemetry = BotTelemetryService();
      final gemini = GeminiAiService();
      final viewModel = DashboardViewModel(telemetry, geminiService: gemini);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: viewModel),
            ChangeNotifierProvider.value(value: gemini),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AiCompanionChatSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter "Show downside shield" in TextField and send
      await tester.enterText(find.byType(TextField), 'Show downside shield');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // Verify the visual agent risk shield rendered
      expect(find.text('DOWNSIDE SHIELD'), findsOneWidget);
      expect(find.text('0.0% DRAWDOWN'), findsOneWidget);
      expect(find.text('PORTFOLIO EQUITY'), findsOneWidget);
      expect(find.text('MAX RISK / TRADE'), findsOneWidget);

      viewModel.dispose();
      gemini.dispose();
      telemetry.dispose();
    });

    testWidgets('GeminiAgenticWorkspaceSheet renders clean canvas without redundant placeholder card', (tester) async {
      final telemetry = BotTelemetryService();
      final gemini = GeminiAiService();
      final viewModel = DashboardViewModel(telemetry, geminiService: gemini);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: viewModel),
            ChangeNotifierProvider.value(value: gemini),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: GeminiAgenticWorkspaceSheet(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify redundant placeholder card is removed
      expect(find.text('I am right here with you in the cockpit.'), findsNothing);
      expect(find.text('100% CAPITAL PROTECTED IN CASH DEFENSE'), findsNothing);
      // Quick prompt chips and header remain accessible
      expect(find.text('📊 Pull up SNOW'), findsOneWidget);

      viewModel.dispose();
      gemini.dispose();
      telemetry.dispose();
    });

    test('askAgenticPartner pulls up specific PotentialPurchase payload when query specifies SNOW', () async {
      final gemini = GeminiAiService();
      final response = await gemini.askAgenticPartner(
        userQuery: 'Can you pull up SNOW?',
        state: mockState,
        positions: const [],
        setups: mockSetups,
        decisions: const [],
        shariahAudits: const [],
      );

      expect(response.actionType, AgenticActionType.setups);
      expect(response.payload, isA<PotentialPurchase>());
      final setup = response.payload as PotentialPurchase;
      expect(setup.symbol, 'SNOW');
      expect(setup.suggestedEntry, 367.80);
      expect(response.text, contains('Snowflake'));

      gemini.dispose();
    });

    test('askAgenticPartner provides check-in cockpit awareness response when user asks anything new', () async {
      final gemini = GeminiAiService();
      final response = await gemini.askAgenticPartner(
        userQuery: 'Anything new in our system?',
        state: mockState,
        positions: const [],
        setups: mockSetups,
        decisions: const [],
        shariahAudits: const [],
      );

      expect(response.text, contains('Welcome back to the cockpit!'));
      expect(response.text, contains('\$20,000'));
      expect(response.text, contains('cash defense'));

      gemini.dispose();
    });

    test('GeminiAiService modelDisplayName dynamically reflects model selection', () {
      final gemini = GeminiAiService();
      expect(gemini.modelDisplayName, equals('Gemini 3.5 Flash'));

      gemini.setModel('gemini-2.5-flash-lite');
      expect(gemini.modelDisplayName, equals('Gemini 3.5 Flash Lite'));

      gemini.setModel('gemini-2.5-pro');
      expect(gemini.modelDisplayName, equals('Gemini 3.5 Pro'));

      gemini.setModel('gemini-3.1-flash');
      expect(gemini.modelDisplayName, equals('Gemini 3.1 Flash'));
      gemini.dispose();
    });

    test('GeminiAiService card cache clearing operates safely', () {
      final gemini = GeminiAiService();
      gemini.clearCachedCardResult('briefing_v1');
      gemini.clearAllCachedCardResults();
      expect(gemini.getCachedCardResult('briefing_v1'), isNull);
      gemini.dispose();
    });

    test('BotState and telemetry JSON with NaN replaces cleanly', () {
      var rawPayload = '{"state": {"portfolio_value": 49785.35, "today_gain_dollars": NaN, "total_gain_dollars": 1240.50, "active_regime": "BULL_TRENDING", "execution_loop_active": true}}';
      rawPayload = rawPayload
          .replaceAll(': NaN', ': null')
          .replaceAll(': nan', ': null')
          .replaceAll(': -NaN', ': null')
          .replaceAll(': -nan', ': null')
          .replaceAll(': Infinity', ': null')
          .replaceAll(': -Infinity', ': null');

      final parsed = jsonDecode(rawPayload);
      final s = parsed['state'];
      final state = BotState(
        portfolioValue: (s['portfolio_value'] as num?)?.toDouble() ?? 20000.0,
        todayGainDollars: (s['today_gain_dollars'] as num?)?.toDouble() ?? 0.0,
        totalGainDollars: (s['total_gain_dollars'] as num?)?.toDouble() ?? 0.0,
        activeRegime: s['active_regime'] ?? 'BULL_TRENDING',
        executionLoopActive: s['execution_loop_active'] ?? true,
      );

      expect(state.portfolioValue, equals(49785.35));
      expect(state.todayGainDollars, equals(0.0)); // was NaN -> null -> 0.0
      expect(state.activeRegime, equals('BULL_TRENDING'));
    });

    test('CockpitTimeContext never greets Good Morning at night or post-midnight', () {
      // Midnight / 01:30 AM (Late night / overnight)
      final lateNight = DateTime(2026, 9, 4, 1, 30);
      final lateNightCtx = CockpitTimeContext.fromDateTime(lateNight);
      expect(lateNightCtx.timeOfDayGreeting, equals('Good evening'));
      expect(lateNightCtx.timeOfDayGreeting, isNot(equals('Good morning')));

      // 04:00 AM (Early night)
      final fourAm = DateTime(2026, 9, 4, 4, 0);
      final fourAmCtx = CockpitTimeContext.fromDateTime(fourAm);
      expect(fourAmCtx.timeOfDayGreeting, equals('Good evening'));
      expect(fourAmCtx.timeOfDayGreeting, isNot(equals('Good morning')));

      // 08:30 AM (Morning)
      final morning = DateTime(2026, 9, 4, 8, 30);
      final morningCtx = CockpitTimeContext.fromDateTime(morning);
      expect(morningCtx.timeOfDayGreeting, equals('Good morning'));

      // 14:00 (Afternoon)
      final afternoon = DateTime(2026, 9, 4, 14, 0);
      final afternoonCtx = CockpitTimeContext.fromDateTime(afternoon);
      expect(afternoonCtx.timeOfDayGreeting, equals('Good afternoon'));

      // 19:30 (Evening)
      final evening = DateTime(2026, 9, 4, 19, 30);
      final eveningCtx = CockpitTimeContext.fromDateTime(evening);
      expect(eveningCtx.timeOfDayGreeting, equals('Good evening'));

      // 23:45 (Night)
      final night = DateTime(2026, 9, 4, 23, 45);
      final nightCtx = CockpitTimeContext.fromDateTime(night);
      expect(nightCtx.timeOfDayGreeting, equals('Good evening'));
      expect(nightCtx.timeOfDayGreeting, isNot(equals('Good morning')));
    });

    test('CockpitTimeContext correctly identifies weekend market standby', () {
      // Sunday
      final sunday = DateTime.utc(2026, 9, 6, 14, 0); // Sunday 10am ET
      final sundayCtx = CockpitTimeContext.fromDateTime(sunday.toLocal());
      expect(sundayCtx.marketSession, equals('WEEKEND_STANDBY'));
      expect(sundayCtx.isMarketOpen, isFalse);
    });

    test('DashboardViewModel immediately loads persisted briefing on Frame 0 with zero fallback flash', () {
      final telemetry = BotTelemetryService();
      final gemini = GeminiAiService();
      const testBriefing = 'Good afternoon. You have stepped into the cockpit. 100% of capital safe in cash.';
      gemini.setPersistedExecutiveBriefingForTest(testBriefing);

      final vm = DashboardViewModel(telemetry, geminiService: gemini);
      // Immediately on creation, before any async events or network calls
      expect(vm.executiveBriefingSummary, equals(testBriefing));
      vm.dispose();
      telemetry.dispose();
    });

    test('DashboardViewModel maintains stable briefing and does not loop on notifyListeners calls', () async {
      final telemetry = BotTelemetryService();
      final gemini = GeminiAiService();
      const testBriefing = 'Market Intel Stable. Preserving cash defense.';
      gemini.setPersistedExecutiveBriefingForTest(testBriefing);

      final vm = DashboardViewModel(telemetry, geminiService: gemini);
      expect(vm.executiveBriefingSummary, equals(testBriefing));

      // Simulate rapid periodic pings from GeminiAiService (heartbeat pings)
      gemini.notifyListeners();
      gemini.notifyListeners();
      gemini.notifyListeners();

      // Ensure briefing text did not get wiped or replaced with generic fallback
      expect(vm.executiveBriefingSummary, equals(testBriefing));

      vm.dispose();
      telemetry.dispose();
    });

    test('DashboardViewModel executiveBriefingSummary addresses user as Boss and distinguishes CRWD vs PLTR', () {
      final telemetry = BotTelemetryService();
      final vm = DashboardViewModel(telemetry);

      final summary = vm.executiveBriefingSummary;
      expect(summary, contains('Boss'));
      expect(summary, contains('CRWD is our #1 highest-conviction setup'));
      expect(summary, contains('PLTR is closest to trigger'));

      vm.dispose();
      telemetry.dispose();
    });

    test('GeminiAiService.sanitizeConversationalGreeting strips repeated Morning prefixes', () {
      // Direct screenshot scenarios
      expect(
        GeminiAiService.sanitizeConversationalGreeting(
          "Morning. Yes, absolutely. Our quantitative model is actually architected specifically around a Concentrated 2-Position Alpha framework.",
          isExplicitUserGreeting: false,
          hasHistory: true,
        ),
        equals("Yes, absolutely. Our quantitative model is actually architected specifically around a Concentrated 2-Position Alpha framework."),
      );

      expect(
        GeminiAiService.sanitizeConversationalGreeting(
          "Morning. While it is mechanically possible to execute a single 100% allocation, our risk engine strictly prohibits it.",
          isExplicitUserGreeting: false,
          hasHistory: true,
        ),
        equals("While it is mechanically possible to execute a single 100% allocation, our risk engine strictly prohibits it."),
      );

      // Comma, exclamation, and Boss variants
      expect(
        GeminiAiService.sanitizeConversationalGreeting(
          "Good morning! We are holding 100% cash.",
          isExplicitUserGreeting: false,
          hasHistory: true,
        ),
        equals("We are holding 100% cash."),
      );

      expect(
        GeminiAiService.sanitizeConversationalGreeting(
          "Good morning, Boss. All systems are green.",
          isExplicitUserGreeting: false,
          hasHistory: true,
        ),
        equals("All systems are green."),
      );

      expect(
        GeminiAiService.sanitizeConversationalGreeting(
          "Morning, yes we can allocate 50% per trade.",
          isExplicitUserGreeting: false,
          hasHistory: true,
        ),
        equals("Yes we can allocate 50% per trade."),
      );

      expect(
        GeminiAiService.sanitizeConversationalGreeting(
          "Boss, we have 100% capital safe.",
          isExplicitUserGreeting: false,
          hasHistory: true,
        ),
        equals("We have 100% capital safe."),
      );

      // Substantive sentences beginning with Morning are preserved
      expect(
        GeminiAiService.sanitizeConversationalGreeting(
          "Morning session volume is accelerating institutional buying.",
          isExplicitUserGreeting: false,
          hasHistory: true,
        ),
        equals("Morning session volume is accelerating institutional buying."),
      );

      // Explicit greeting is preserved even with history
      expect(
        GeminiAiService.sanitizeConversationalGreeting(
          "Hey Boss! Great to see you in the cockpit. What are we looking at today?",
          isExplicitUserGreeting: true,
          hasHistory: true,
        ),
        equals("Hey Boss! Great to see you in the cockpit. What are we looking at today?"),
      );
    });

    test('askAgenticPartner handles simple greeting "hello gem" naturally with Boss and no telemetry dump', () async {
      final gemini = GeminiAiService();
      final response = await gemini.askAgenticPartner(
        userQuery: 'hello gem',
        state: mockState,
        positions: const [],
        setups: mockSetups,
        decisions: const [],
        shariahAudits: const [],
      );

      expect(response.text, contains('Boss'));
      expect(response.text, contains('cockpit'));
      // Must NOT contain robotic unsolicited overnight lecture
      expect(response.text.contains('overnight standby with our \$20,000 capital safely parked in cash'), isFalse);

      gemini.dispose();
    });

    test('askAgenticPartner directly answers "is the market open?" with clear market status', () async {
      final gemini = GeminiAiService();
      final response = await gemini.askAgenticPartner(
        userQuery: 'is the market open?',
        state: mockState,
        positions: const [],
        setups: mockSetups,
        decisions: const [],
        shariahAudits: const [],
      );

      expect(response.text.contains('US equity markets (NYSE/Nasdaq) are currently'), isTrue);
      // Must NOT deliver general macro regime speech
      expect(response.text.contains('During defensive regimes, our priority is capital preservation'), isFalse);

      gemini.dispose();
    });

    test('askAgenticPartner handles small talk "how are you" conversationally', () async {
      final gemini = GeminiAiService();
      final response = await gemini.askAgenticPartner(
        userQuery: 'how are you',
        state: mockState,
        positions: const [],
        setups: mockSetups,
        decisions: const [],
        shariahAudits: const [],
      );

      expect(response.text, contains('Doing great, Boss!'));
      expect(response.text, contains('risk'));

      gemini.dispose();
    });

    test('askAgenticPartner handles readiness check "are you ready" confidently', () async {
      final gemini = GeminiAiService();
      final response = await gemini.askAgenticPartner(
        userQuery: 'are you ready',
        state: mockState,
        positions: const [],
        setups: mockSetups,
        decisions: const [],
        shariahAudits: const [],
      );

      expect(response.text, contains('Locked and loaded, Boss'));

      gemini.dispose();
    });

    test('askAgenticPartner handles gratitude "thanks" and "ok" graciously', () async {
      final gemini = GeminiAiService();
      final thanksResponse = await gemini.askAgenticPartner(
        userQuery: 'thanks gem',
        state: mockState,
        positions: const [],
        setups: mockSetups,
        decisions: const [],
        shariahAudits: const [],
      );
      expect(thanksResponse.text, contains('Anytime, Boss!'));

      final okResponse = await gemini.askAgenticPartner(
        userQuery: 'ok got it',
        state: mockState,
        positions: const [],
        setups: mockSetups,
        decisions: const [],
        shariahAudits: const [],
      );
      expect(okResponse.text, contains('Sounds good, Boss'));

      gemini.dispose();
    });

    test('askAgenticPartner handles identity question "who are you" with crisp capability breakdown', () async {
      final gemini = GeminiAiService();
      final response = await gemini.askAgenticPartner(
        userQuery: 'who are you',
        state: mockState,
        positions: const [],
        setups: mockSetups,
        decisions: const [],
        shariahAudits: const [],
      );

      expect(response.text, contains("I'm Gemini, your quantitative co-pilot"));
      expect(response.text, contains('200-EMA'));
      expect(response.text, contains('AAOIFI'));

      gemini.dispose();
    });

    test('askAgenticPartner does not prepend Morning or greeting when in ongoing conversation', () async {
      final gemini = GeminiAiService();
      final priorUserMsg = AgenticChatMessage(
        id: '1',
        text: 'can you put 50% on one trade',
        isUser: true,
        timestamp: DateTime.now(),
      );
      final priorGeminiMsg = AgenticChatMessage(
        id: '2',
        text: 'Yes, exactly! Our quantitative architecture is built on a Concentrated 2-Position Alpha Model.',
        isUser: false,
        timestamp: DateTime.now(),
      );

      final response = await gemini.askAgenticPartner(
        userQuery: 'is it possible to do 100% on one trade',
        state: mockState,
        positions: const [],
        setups: mockSetups,
        decisions: const [],
        shariahAudits: const [],
        history: [priorUserMsg, priorGeminiMsg],
      );

      expect(response.text.startsWith('Morning'), isFalse);
      expect(response.text.startsWith('Good morning'), isFalse);
      expect(response.text.startsWith('Hey'), isFalse);

      gemini.dispose();
    });
  });
}

