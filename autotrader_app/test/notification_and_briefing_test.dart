import 'package:flutter_test/flutter_test.dart';
import 'package:autotrader_app/data/models/position.dart';
import 'package:autotrader_app/data/services/bot_telemetry_service.dart';
import 'package:autotrader_app/data/services/bot_notification_service.dart';
import 'package:autotrader_app/data/services/gemini_ai_service.dart';
import 'package:autotrader_app/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Executive Briefing Cache Invalidation Tests', () {
    test('executiveBriefingSummary invalidates stale 100% cash briefing when positions exist', () async {
      final telemetry = BotTelemetryService();
      final gemini = GeminiAiService();
      
      gemini.setPersistedExecutiveBriefingForTest(
        "Good morning, Boss. You've stepped into the cockpit—here is where we stand: 100% of our \$20000.00 capital remains safely preserved in cash with 0% drawdown.",
      );

      final vm = DashboardViewModel(telemetry, geminiService: gemini);
      expect(vm.positions.isEmpty, isTrue);

      final amdPosition = const Position(
        symbol: 'AMD',
        companyName: 'Advanced Micro Devices',
        entryPrice: 522.16,
        livePrice: 516.13,
        shares: 35,
        protectedFloor: 511.72,
        lockedGainPercent: -1.2,
        ratchetTier: 'Live Position',
        isHalal: true,
        priceNodes: [522.16, 516.13],
      );

      telemetry.updatePositionsForTest([amdPosition]);
      await Future.delayed(const Duration(milliseconds: 50));

      final summary = vm.executiveBriefingSummary;
      expect(summary.contains('AMD'), isTrue);
      expect(summary.contains('35 shares'), isTrue);
      expect(summary.contains('\$511.72'), isTrue);
      expect(summary.contains('100% of our \$20000.00 capital remains safely preserved in cash'), isFalse);

      vm.dispose();
      telemetry.dispose();
    });

    test('Position math and Zakat auto-reservation calculates accurately', () {
      const posLoss = Position(
        symbol: 'AMD',
        companyName: 'Advanced Micro Devices',
        entryPrice: 522.16,
        livePrice: 516.13,
        shares: 35,
        protectedFloor: 511.72,
        lockedGainPercent: -1.2,
        ratchetTier: 'Alpaca Live Position',
        isHalal: true,
        priceNodes: [522.16, 516.13],
      );

      // Allocated capital: 35 * 516.13 = $18,064.55
      expect(posLoss.currentMarketValue, closeTo(18064.55, 0.1));
      // Equity % of $19,800: ~91.2%
      final equityPct = (posLoss.currentMarketValue / 19800.0) * 100;
      expect(equityPct, closeTo(91.2, 0.5));
      // Floor delta: (511.72 - 522.16) / 522.16 = -2.00%
      final floorDelta = ((posLoss.protectedFloor - posLoss.entryPrice) / posLoss.entryPrice) * 100;
      expect(floorDelta, closeTo(-2.00, 0.05));
      // In loss, Zakat auto-reservation is $0.00
      expect(posLoss.charityPurificationDollars, equals(0.0));

      const posGain = Position(
        symbol: 'AMD',
        companyName: 'Advanced Micro Devices',
        entryPrice: 500.0,
        livePrice: 550.0,
        shares: 20,
        protectedFloor: 525.0,
        lockedGainPercent: 5.0,
        ratchetTier: 'Tier 2 Active',
        isHalal: true,
        priceNodes: [500.0, 550.0],
      );
      // Gain: 20 * (550 - 500) = $1,000. 1% Zakat = $10.00
      expect(posGain.charityPurificationDollars, equals(10.0));
      final gainFloorDelta = ((posGain.protectedFloor - posGain.entryPrice) / posGain.entryPrice) * 100;
      expect(gainFloorDelta, equals(5.0));
    });
  });
}
