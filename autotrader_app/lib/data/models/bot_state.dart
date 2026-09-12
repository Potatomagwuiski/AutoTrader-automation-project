class BotState {
  final double portfolioValue;
  final double cashBalance;
  final double buyingPower;
  final double totalGainPercent;
  final double totalGainDollars;
  final double todayGainDollars;
  final double winRate;
  final double profitFactor;
  final double payoffRatio;
  final double charityCleansedDollars;
  final bool executionLoopActive;
  final bool canaryAiActive;
  final bool shariahDaemonActive;
  final String activeRegime;
  final String currentTierName;
  final double annualSalaryTarget;
  final double recommendedHarvestAmount;
  final double safeCompoundingCapital;
  final String nextTierName;
  final double nextTierTarget;

  const BotState({
    this.portfolioValue = 20000.00,
    this.cashBalance = 20000.00,
    this.buyingPower = 20000.00,
    this.totalGainPercent = 0.0,
    this.totalGainDollars = 0.0,
    this.todayGainDollars = 0.0,
    this.winRate = 0.0,
    this.profitFactor = 0.0,
    this.payoffRatio = 0.0,
    this.charityCleansedDollars = 0.0,
    this.executionLoopActive = true,
    this.canaryAiActive = true,
    this.shariahDaemonActive = true,
    this.activeRegime = 'BULL_TRENDING',
    this.currentTierName = 'Alpaca Live Session',
    this.annualSalaryTarget = 0.00,
    this.recommendedHarvestAmount = 0.00,
    this.safeCompoundingCapital = 20000.00,
    this.nextTierName = 'Tier 1: Growth Target (\$25k)',
    this.nextTierTarget = 25000.00,
  });

  BotState copyWith({
    double? portfolioValue,
    double? cashBalance,
    double? buyingPower,
    double? totalGainPercent,
    double? totalGainDollars,
    double? todayGainDollars,
    double? winRate,
    double? profitFactor,
    double? payoffRatio,
    double? charityCleansedDollars,
    bool? executionLoopActive,
    bool? canaryAiActive,
    bool? shariahDaemonActive,
    String? activeRegime,
    String? currentTierName,
    double? annualSalaryTarget,
    double? recommendedHarvestAmount,
    double? safeCompoundingCapital,
    String? nextTierName,
    double? nextTierTarget,
  }) {
    return BotState(
      portfolioValue: portfolioValue ?? this.portfolioValue,
      cashBalance: cashBalance ?? this.cashBalance,
      buyingPower: buyingPower ?? this.buyingPower,
      totalGainPercent: totalGainPercent ?? this.totalGainPercent,
      totalGainDollars: totalGainDollars ?? this.totalGainDollars,
      todayGainDollars: todayGainDollars ?? this.todayGainDollars,
      winRate: winRate ?? this.winRate,
      profitFactor: profitFactor ?? this.profitFactor,
      payoffRatio: payoffRatio ?? this.payoffRatio,
      charityCleansedDollars:
          charityCleansedDollars ?? this.charityCleansedDollars,
      executionLoopActive: executionLoopActive ?? this.executionLoopActive,
      canaryAiActive: canaryAiActive ?? this.canaryAiActive,
      shariahDaemonActive: shariahDaemonActive ?? this.shariahDaemonActive,
      activeRegime: activeRegime ?? this.activeRegime,
      currentTierName: currentTierName ?? this.currentTierName,
      annualSalaryTarget: annualSalaryTarget ?? this.annualSalaryTarget,
      recommendedHarvestAmount:
          recommendedHarvestAmount ?? this.recommendedHarvestAmount,
      safeCompoundingCapital:
          safeCompoundingCapital ?? this.safeCompoundingCapital,
      nextTierName: nextTierName ?? this.nextTierName,
      nextTierTarget: nextTierTarget ?? this.nextTierTarget,
    );
  }
}
