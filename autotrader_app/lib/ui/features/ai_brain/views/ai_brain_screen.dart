import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/asset_brand_logo.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import '../../dashboard/view_models/dashboard_view_model.dart';
import '../../dashboard/views/ai_companion_settings_sheet.dart';
import '../../../../data/models/bot_state.dart';
import '../../../../data/services/bot_telemetry_service.dart';
import '../../../../data/services/gemini_ai_service.dart';

class AiBrainScreen extends StatefulWidget {
  const AiBrainScreen({super.key});

  @override
  State<AiBrainScreen> createState() => _AiBrainScreenState();
}

class _AiBrainScreenState extends State<AiBrainScreen> {
  String _selectedDateKey = 'Today';
  String _selectedAssetFilter = 'ALL'; // 'ALL', 'RADAR', 'SYSTEM'

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();
    final availableDates = viewModel.telemetryService.availableDecisionDates;
    final activeDateKey = availableDates.contains(_selectedDateKey)
        ? _selectedDateKey
        : (availableDates.isNotEmpty ? availableDates.first : 'Today');
    var decisions = viewModel.telemetryService.getDecisionsForDate(activeDateKey);

    // Apply asset filter
    if (_selectedAssetFilter == 'RADAR') {
      decisions = decisions.where((d) => d.category == 'SHARIAH_AUDIT' || d.category == 'SCAN' || d.category == 'SETUP').toList();
    } else if (_selectedAssetFilter == 'SYSTEM') {
      decisions = decisions.where((d) => d.assetSymbol == 'MACRO' || d.assetSymbol == 'CANARY' || d.assetSymbol == 'RISK' || d.assetSymbol == 'ALPACA' || d.assetSymbol == 'EXECUTION').toList();
    }

    final isToday = activeDateKey == 'Today';
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return RefreshIndicator(
      color: AppTheme.mint,
      backgroundColor: AppTheme.charcoalCard,
      strokeWidth: 2.5,
      onRefresh: () async {
        AppHaptics.mediumImpact();
        await context.read<DashboardViewModel>().refreshAllData();
        AppHaptics.successNotification();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: bottomInset + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // ================= CARD 1: AI BRAIN HERO CARD =================
          _buildBrainHeroCard(context, viewModel.state),

          const SizedBox(height: 18),

          // ================= SECTION HEADER: DECISION STREAM & DATE SELECTOR =================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Decision Stream',
                      style: GoogleFonts.spaceMono(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Audited Cycle Telemetry',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                // Date Dropdown Modal Trigger Button
                GestureDetector(
                  onTap: () {
                    AppHaptics.lightClick();
                    _showDateDropdownModal(context, viewModel, availableDates);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.charcoalInnerPill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.charcoalInnerBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.textWhite),
                        const SizedBox(width: 6),
                        Text(
                          activeDateKey,
                          style: GoogleFonts.spaceMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textWhite,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppTheme.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ================= HORIZONTAL DATE SELECTOR PILLS =================
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: availableDates.map((dateKey) {
                final isSelected = dateKey == activeDateKey;
                final dateCount = viewModel.telemetryService.getDecisionsForDate(dateKey).length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      AppHaptics.selectionClick();
                      setState(() => _selectedDateKey = dateKey);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.charcoalCard : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.charcoalBorder : AppTheme.charcoalInnerBorder.withValues(alpha: 0.5),
                        ),
                        boxShadow: isSelected ? AppTheme.cardShadow : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (dateKey == 'Today') ...[
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: AppTheme.mint,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          Text(
                            dateKey,
                            style: GoogleFonts.spaceMono(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.textWhite : AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppTheme.charcoalInnerPill,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$dateCount',
                              style: GoogleFonts.spaceMono(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppTheme.textWhite : AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // ================= ASSET FILTER PILLS (RELATE QUICKLY) =================
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAssetFilterPill('ALL', 'All Targets'),
                _buildAssetFilterPill('RADAR', 'Watchlist Radar', icon: Icons.radar_rounded),
                _buildAssetFilterPill('SYSTEM', 'Macro & System', icon: Icons.tune_rounded),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ================= DATE SUMMARY INFO ROW =================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isToday
                      ? 'Live Execution Feed'
                      : 'Audited Cycle Archive ($_selectedDateKey)',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
                Text(
                  '${decisions.length} ${isToday ? 'LIVE' : 'LOGGED'} ACTIONS',
                  style: GoogleFonts.spaceMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ================= INDIVIDUAL DECISION CARDS =================
          if (decisions.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.charcoalCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.charcoalBorder),
              ),
              child: Center(
                child: Text(
                  'No cycle telemetry recorded for $_selectedDateKey with filter $_selectedAssetFilter.',
                  style: GoogleFonts.spaceMono(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          ] else ...[
            ...decisions.map((log) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildIndividualDecisionCard(context, log),
                )),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildAssetFilterPill(String filterKey, String label, {String? symbol, IconData? icon}) {
    final isSelected = _selectedAssetFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          AppHaptics.selectionClick();
          setState(() => _selectedAssetFilter = filterKey);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.charcoalInnerPill : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.textWhite.withValues(alpha: 0.6) : AppTheme.charcoalInnerBorder.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (symbol != null) ...[
                AssetBrandLogo(symbol: symbol, size: 14),
                const SizedBox(width: 5),
              ] else if (icon != null) ...[
                Icon(icon, size: 12, color: isSelected ? AppTheme.textWhite : AppTheme.textMuted),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppTheme.textWhite : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDateDropdownModal(
    BuildContext context,
    DashboardViewModel viewModel,
    List<String> availableDates,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: const BoxDecoration(
            color: AppTheme.appBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Cycle Log Date',
                    style: GoogleFonts.spaceMono(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...availableDates.map((dateKey) {
                final isSelected = dateKey == _selectedDateKey;
                final count = viewModel.telemetryService.getDecisionsForDate(dateKey).length;
                return GestureDetector(
                  onTap: () {
                    AppHaptics.mediumImpact();
                    setState(() => _selectedDateKey = dateKey);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.charcoalCard : AppTheme.charcoalInnerPill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppTheme.mint.withValues(alpha: 0.5) : AppTheme.charcoalInnerBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              dateKey == 'Today' ? Icons.fiber_manual_record : Icons.calendar_today_outlined,
                              size: 14,
                              color: isSelected ? AppTheme.mint : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              dateKey == 'Today'
                                  ? 'Today (Aug 28, 2026 - Live)'
                                  : dateKey == 'Yesterday'
                                      ? 'Yesterday (Aug 27, 2026)'
                                      : '$dateKey, 2026 (Audited)',
                              style: GoogleFonts.spaceMono(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppTheme.textWhite : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '$count cycles',
                              style: GoogleFonts.spaceMono(
                                fontSize: 10,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.mint),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // CARD 1: AI Brain Hero (Minimal & Prominent with Dynamic Regime Color)
  Widget _buildBrainHeroCard(BuildContext context, BotState state) {
    final regime = state.activeRegime;
    final formattedRegime = regime.replaceAll('_', ' ').toUpperCase();
    final regimeColor = _getRegimeColor(regime);
    final isBull = regime.toUpperCase().contains('BULL');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.charcoalBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.charcoalInnerPill,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.charcoalInnerBorder),
                ),
                child: const Center(
                  child: Icon(Icons.shield_outlined, color: AppTheme.textWhite, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Market Regime & Safety Guard',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Macro Trend & Position Sizing',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Regime Label
          Text(
            'MARKET CONDITION',
            style: GoogleFonts.spaceMono(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),

          // Status & Sizing (Color Coded Based on Market Condition - Overflow Safe)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  formattedRegime,
                  style: GoogleFonts.spaceMono(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: regimeColor,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isBull ? '200-EMA SHIELD' : 'CASH PRESERVE',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isBull ? 'Sizing: 48.5% x 2' : 'Sizing: 0% (100% Cash)',
                    style: GoogleFonts.spaceMono(
                      fontSize: 9.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: AppTheme.charcoalBorder.withValues(alpha: 0.6)),
          const SizedBox(height: 10),

          // Gemini API Integration Bar
          Builder(
            builder: (ctx) {
              final gemini = ctx.watch<GeminiAiService>();
              final isLive = gemini.isGeminiConnected && gemini.hasApiKey;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  AppHaptics.mediumImpact();
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (sheetCtx) => const AiCompanionSettingsSheet(),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 13,
                        color: isLive ? AppTheme.geminiBlue : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isLive ? gemini.modelDisplayName : 'AI Engine: Local',
                          style: GoogleFonts.spaceMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isLive ? AppTheme.geminiBlue : AppTheme.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLive ? 'Manage' : 'Connect',
                            style: GoogleFonts.spaceMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isLive ? AppTheme.textWhite : AppTheme.mint,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 13,
                            color: isLive ? AppTheme.textWhite : AppTheme.mint,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getRegimeColor(String regime) {
    final r = regime.toUpperCase();
    if (r.contains('BULL') || r.contains('EXPANSION')) {
      return AppTheme.mint; // Green for Bull Trending
    } else if (r.contains('BEAR') || r.contains('DEFENSIVE') || r.contains('SHIELD') || r.contains('CASH')) {
      return AppTheme.referenceRed; // Red for Bear Market / Defensive
    } else if (r.contains('CHOP') || r.contains('SIDEWAYS') || r.contains('NEUTRAL') || r.contains('RANGE')) {
      return AppTheme.referenceOrange; // Amber for Range-bound Chop
    }
    return AppTheme.mint;
  }

  // INDIVIDUAL DECISION CARD (Minimal Single Card & Floating Organised AI Takeaway)
  Widget _buildIndividualDecisionCard(BuildContext context, BotDecisionLog log) {
    final isPos = log.isPositive;
    final isStock = log.assetSymbol == 'AMD' ||
        log.assetSymbol == 'ARM' ||
        log.assetSymbol == 'NVDA' ||
        log.assetSymbol == 'SNOW' ||
        log.assetSymbol == 'MRVL';

    final themeColor = isPos
        ? AppTheme.mint
        : (log.category == 'CANARY_AI' ? AppTheme.referenceRed : AppTheme.referenceOrange);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.charcoalBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Asset & Target Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (isStock)
                      AssetBrandLogo(symbol: log.assetSymbol, size: 32)
                    else
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.charcoalInnerPill,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.charcoalInnerBorder),
                        ),
                        child: Center(
                          child: Icon(
                            _getCategoryIcon(log.category),
                            size: 16,
                            color: AppTheme.textWhite,
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                log.assetSymbol,
                                style: GoogleFonts.spaceMono(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textWhite,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: themeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    log.impactBadge,
                                    style: GoogleFonts.spaceMono(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: themeColor,
                                      letterSpacing: 0.3,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            log.assetName,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                log.timestamp,
                style: GoogleFonts.spaceMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Action Title
          Text(
            log.title,
            style: GoogleFonts.spaceMono(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textWhite,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 6),

          // 3. Technical Detail
          Text(
            log.detail,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textMuted,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: AppTheme.charcoalBorder.withValues(alpha: 0.6)),
          const SizedBox(height: 12),

          // 4. ✨ Automated AI Plain-English Takeaway (Signature Gemini Electric Blue)
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: AppTheme.geminiBlue,
              ),
              const SizedBox(width: 6),
              Text(
                'AI PLAIN-ENGLISH TAKEAWAY',
                style: GoogleFonts.spaceMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.geminiBlue,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            log.aiTakeaway,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.5,
              color: AppTheme.textWhite.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'TRAILING_STOP':
        return Icons.trending_up_rounded;
      case 'REGIME_SHIFT':
        return Icons.candlestick_chart_rounded;
      case 'SHARIAH_AUDIT':
        return Icons.verified_user_outlined;
      case 'RISK_GATE':
        return Icons.security_rounded;
      case 'EXECUTION':
        return Icons.flash_on_rounded;
      case 'CANARY_AI':
      default:
        return Icons.psychology_outlined;
    }
  }
}


