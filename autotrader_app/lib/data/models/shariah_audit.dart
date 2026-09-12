class ShariahStockAudit {
  final String symbol;
  final String companyName;
  final double debtRatio; // Debt / MarketCap (< 30%)
  final double cashRatio; // Cash / MarketCap (< 30%)
  final double nonOperatingInterestRatio; // (< 5%)
  final bool isCompliant;
  final String secFilingDate;

  const ShariahStockAudit({
    required this.symbol,
    required this.companyName,
    required this.debtRatio,
    required this.cashRatio,
    required this.nonOperatingInterestRatio,
    this.isCompliant = true,
    required this.secFilingDate,
  });
}
