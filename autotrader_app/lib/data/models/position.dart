class Position {
  final String symbol;
  final String companyName;
  final double entryPrice;
  final double livePrice;
  final int shares;
  final double protectedFloor;
  final double lockedGainPercent;
  final String ratchetTier;
  final bool isHalal;
  final List<double> priceNodes;
  final double charityPurificationRate; // e.g. 0.01 (1%)

  const Position({
    required this.symbol,
    required this.companyName,
    required this.entryPrice,
    required this.livePrice,
    required this.shares,
    required this.protectedFloor,
    required this.lockedGainPercent,
    required this.ratchetTier,
    this.isHalal = true,
    required this.priceNodes,
    this.charityPurificationRate = 0.01,
  });

  double get totalInvested => entryPrice * shares;
  double get currentMarketValue => livePrice * shares;
  double get unrealizedProfitDollars => currentMarketValue - totalInvested;
  double get currentGainDollars => unrealizedProfitDollars;
  double get unrealizedProfitPercent =>
      ((livePrice - entryPrice) / entryPrice) * 100.0;
  double get unrealizedGainPercent => unrealizedProfitPercent;
  double get charityPurificationDollars =>
      (unrealizedProfitDollars > 0)
          ? unrealizedProfitDollars * charityPurificationRate
          : 0.0;

  Position copyWith({
    String? symbol,
    String? companyName,
    double? entryPrice,
    double? livePrice,
    int? shares,
    double? protectedFloor,
    double? lockedGainPercent,
    String? ratchetTier,
    bool? isHalal,
    List<double>? priceNodes,
    double? charityPurificationRate,
  }) {
    return Position(
      symbol: symbol ?? this.symbol,
      companyName: companyName ?? this.companyName,
      entryPrice: entryPrice ?? this.entryPrice,
      livePrice: livePrice ?? this.livePrice,
      shares: shares ?? this.shares,
      protectedFloor: protectedFloor ?? this.protectedFloor,
      lockedGainPercent: lockedGainPercent ?? this.lockedGainPercent,
      ratchetTier: ratchetTier ?? this.ratchetTier,
      isHalal: isHalal ?? this.isHalal,
      priceNodes: priceNodes ?? this.priceNodes,
      charityPurificationRate:
          charityPurificationRate ?? this.charityPurificationRate,
    );
  }
}
