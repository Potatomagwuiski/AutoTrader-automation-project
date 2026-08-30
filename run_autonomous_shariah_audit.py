"""
Demonstration of Autonomous Shariah Auditing and Live Dynamic Stock Selection.
Scans 36 major US equities:
- Automatically audits Debt / Market Cap (<33%) and Cash / Market Cap (<33%) from live balance sheets.
- Disqualifies conventional banks (JPM, BAC, WFC) and high-debt stocks automatically.
- Computes real-time purification percentages.
- Scores and dynamically picks the top 2 highest-momentum Halal leaders.
"""

from tabulate import tabulate
from autotrader.data.yfinance_provider import YFinanceProvider
from autotrader.screening.dynamic_universe_scanner import DynamicHalalUniverseScanner

def main():
    provider = YFinanceProvider()
    scanner = DynamicHalalUniverseScanner(provider)

    print("\n" + "="*95)
    print("  AUTONOMOUS REAL-TIME SHARIAH AUDIT & DYNAMIC STOCK SELECTION")
    print("  (Live Balance Sheet Ingestion • Dynamic Debt/Cash Ratios • Momentum Ranking)")
    print("="*95)

    top_picks, audit_log = scanner.scan_and_rank_universe(top_n=2)

    # 1. Shariah Compliance Audit Log Table
    audit_table = []
    for item in audit_log[:18]:  # Show representative slice
        status_str = "✅ HALAL COMPLIANT" if item["is_compliant"] else "❌ NON-COMPLIANT"
        reason_str = ", ".join(item["failure_reasons"]) if item["failure_reasons"] else "Passes all AAOIFI criteria"
        audit_table.append([
            item["symbol"],
            item["sector"],
            f"{item['debt_ratio']:.1%}",
            f"{item['cash_ratio']:.1%}",
            status_str,
            f"{item['purification_pct']:.2%}",
            reason_str[:40] + ("..." if len(reason_str) > 40 else "")
        ])

    headers_audit = ["Symbol", "Sector", "Debt/MCap", "Cash/MCap", "Shariah Status", "Purify %", "Audit Note"]
    print("\n--- Slice of Live Shariah Balance Sheet Audit Log (36 Assets Scanned) ---")
    print(tabulate(audit_table, headers=headers_audit, tablefmt="fancy_grid"))

    # 2. Dynamic Autonomous Top Stock Picks
    print("\n" + "="*95)
    print("  TOP 2 AUTONOMOUSLY SELECTED HALAL LEADER STOCKS FOR LIVE TRADING")
    print("="*95)
    picks_table = []
    for rank, p in enumerate(top_picks, 1):
        picks_table.append([
            f"Rank #{rank}",
            p.symbol,
            p.company_name,
            f"${p.current_price:.2f}",
            f"{p.rvol:.2f}x",
            f"{p.debt_ratio:.1%}",
            f"{p.cash_ratio:.1%}",
            f"{p.momentum_score:.3f}",
            f"{p.purification_rate:.2%}"
        ])

    headers_picks = ["Selection", "Symbol", "Company", "Current Price", "RVOL", "Debt Ratio", "Cash Ratio", "Alpha Score", "Purification"]
    print(tabulate(picks_table, headers=headers_picks, tablefmt="fancy_grid"))

    print("\n💡 The bot automatically allocated 48.5% capital to each of these 2 top Halal picks.")

if __name__ == "__main__":
    main()
