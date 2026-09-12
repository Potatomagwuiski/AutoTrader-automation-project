import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotrader_app/main.dart';
import 'package:autotrader_app/data/services/gemini_ai_service.dart';

void main() {
  testWidgets('AutoTrader App smoke test and initial render', (
    WidgetTester tester,
  ) async {
    final gemini = GeminiAiService();

    // Build the app
    await tester.pumpWidget(AutoTraderApp(geminiService: gemini));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify dock navigation labels exist
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Wallet'), findsWidgets);
    expect(find.text('Analytics'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    // Test switching to Wallet tab
    await tester.tap(find.text('Wallet').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Test switching to Analytics tab
    await tester.tap(find.text('Analytics').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Test switching to Settings tab
    await tester.tap(find.text('Settings').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Test switching back to Home tab
    await tester.tap(find.text('Home').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Unmount widget tree to cleanly dispose all background timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    gemini.dispose();
  });
}
