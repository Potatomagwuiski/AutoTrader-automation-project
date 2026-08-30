import 'package:flutter_test/flutter_test.dart';
import 'package:autotrader_app/main.dart';

void main() {
  testWidgets('AutoTrader App smoke test and initial render', (
    WidgetTester tester,
  ) async {
    // Build the app
    await tester.pumpWidget(const AutoTraderApp());
    await tester.pumpAndSettle();

    // Verify key titles exist
    expect(find.text('Alpaca Linked'), findsOneWidget);
    expect(find.text('\$49,785.35'), findsOneWidget);
    expect(find.text('Execution Loop'), findsOneWidget);
    expect(find.text('Canary AI'), findsOneWidget);
    expect(find.text('Shariah Daemon'), findsOneWidget);
    expect(find.text('AMD'), findsOneWidget);
    expect(find.text('PLTR'), findsOneWidget);

    // Test tapping AMD card to open detail sheet
    await tester.tap(find.text('AMD'));
    await tester.pumpAndSettle();

    // Verify trade detail sheet opened
    expect(find.text('Entry Price:'), findsOneWidget);
    expect(find.text('Take Profit Now'), findsOneWidget);

    // Close the sheet
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Test switching to Positions tab
    await tester.tap(find.text('Positions'));
    await tester.pumpAndSettle();
    expect(find.text('10-YEAR COMPOUNDING'), findsOneWidget);
    expect(find.text('COMPLETED TRADES LEDGER'), findsOneWidget);

    // Test switching to Logs tab
    await tester.tap(find.text('Logs'));
    await tester.pumpAndSettle();
    expect(find.text('MARKET REGIME RADAR'), findsOneWidget);
    expect(find.text('CANARY MUTATION SANDBOX'), findsOneWidget);

    // Test switching to Account tab
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Charity Cleansed (1% Duty)'), findsOneWidget);
    expect(find.text('SEC 10-Q BALANCE SHEET AUDIT'), findsOneWidget);
  });
}
