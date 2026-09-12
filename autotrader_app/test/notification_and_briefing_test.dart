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
  });
}
