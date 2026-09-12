import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../data/services/bot_notification_service.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    AppHaptics.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsSheet(),
    );
  }

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  NotificationCategory? _selectedCategoryFilter;

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notifDay = DateTime(dt.year, dt.month, dt.day);

    if (notifDay == today) {
      return 'Today, ${DateFormat('hh:mm a').format(dt)}';
    } else if (notifDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${DateFormat('hh:mm a').format(dt)}';
    } else {
      return DateFormat('MMM dd, hh:mm a').format(dt);
    }
  }

  IconData _getCategoryIcon(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.execution:
        return Icons.bolt_rounded;
      case NotificationCategory.regimeShift:
        return Icons.trending_up_rounded;
      case NotificationCategory.riskSentinel:
        return Icons.shield_rounded;
      case NotificationCategory.shariahAudit:
        return Icons.verified_rounded;
      case NotificationCategory.canaryAi:
        return Icons.biotech_rounded;
      case NotificationCategory.systemAlert:
        return Icons.info_outline_rounded;
    }
  }

  String _getCategoryLabel(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.execution:
        return 'Execution';
      case NotificationCategory.regimeShift:
        return 'Regime Shift';
      case NotificationCategory.riskSentinel:
        return 'Risk Shield';
      case NotificationCategory.shariahAudit:
        return 'Shariah Audit';
      case NotificationCategory.canaryAi:
        return 'Canary AI';
      case NotificationCategory.systemAlert:
        return 'System';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final notifService = context.watch<BotNotificationService>();
    final allNotifications = notifService.notifications;

    final filtered = _selectedCategoryFilter == null
        ? allNotifications
        : allNotifications.where((n) => n.category == _selectedCategoryFilter).toList();

    return Container(
      height: screenHeight * 0.82,
      decoration: BoxDecoration(
        color: AppTheme.appBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppTheme.charcoalBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header & Drag Handle
          Container(
            padding: const EdgeInsets.only(left: 20, right: 14, top: 12, bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.charcoalCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                bottom: BorderSide(color: AppTheme.charcoalBorder),
              ),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.charcoalInnerBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.charcoalInnerPill,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.charcoalInnerBorder),
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: AppTheme.textWhite,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 2,
                                  children: [
                                    Text(
                                      'Bot Notifications',
                                      style: GoogleFonts.spaceMono(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textWhite,
                                      ),
                                    ),
                                    if (notifService.unreadCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.charcoalInnerPill,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppTheme.charcoalInnerBorder),
                                        ),
                                        child: Text(
                                          '${notifService.unreadCount} NEW',
                                          style: GoogleFonts.spaceMono(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textWhite,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Text(
                                  'Real-time alerts & execution feed',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    color: AppTheme.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (notifService.unreadCount > 0)
                          IconButton(
                            onPressed: () {
                              AppHaptics.mediumImpact();
                              notifService.markAllAsRead();
                            },
                            icon: const Icon(
                              Icons.done_all_rounded,
                              color: AppTheme.textWhite,
                              size: 18,
                            ),
                            tooltip: 'Mark All as Read',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        if (allNotifications.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              AppHaptics.heavyImpact();
                              _confirmClearAll(context, notifService);
                            },
                            icon: const Icon(
                              Icons.delete_sweep_rounded,
                              color: AppTheme.referenceRed,
                              size: 18,
                            ),
                            tooltip: 'Clear All Alerts',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppTheme.textMuted,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Category Filter Chips
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(label: 'All Alerts', category: null),
                const SizedBox(width: 8),
                _buildFilterChip(label: '⚡ Executions', category: NotificationCategory.execution),
                const SizedBox(width: 8),
                _buildFilterChip(label: '📈 Regime Shifts', category: NotificationCategory.regimeShift),
                const SizedBox(width: 8),
                _buildFilterChip(label: '🛡️ Risk Sentinel', category: NotificationCategory.riskSentinel),
                const SizedBox(width: 8),
                _buildFilterChip(label: '🕋 Shariah Audits', category: NotificationCategory.shariahAudit),
              ],
            ),
          ),

          // Test Notification Trigger Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      AppHaptics.successNotification();
                      await notifService.requestPermissions();
                      await notifService.addNotification(
                        title: '⚡ Trading Cockpit: Limit Order Filled',
                        body: 'Executed 8 shares of CRWD at \$218.40. Trailing stop armed at \$207.50 (+100% Cash Protected).',
                        category: NotificationCategory.execution,
                        showNativePush: true,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '🔔 Live push notification sent to your phone! Lock your phone or check your notification shade.',
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textWhite),
                            ),
                            backgroundColor: AppTheme.charcoalCard,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.charcoalInnerPill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.charcoalInnerBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, color: AppTheme.textWhite, size: 13),
                          const SizedBox(width: 6),
                          Text(
                            'TEST NATIVE PUSH ALERT',
                            style: GoogleFonts.spaceMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textWhite,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Notification Feed List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 48,
                            color: AppTheme.textMuted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No Notifications',
                            style: GoogleFonts.spaceMono(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textWhite,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Important trading milestones, regime shifts, and risk sentinel alerts will appear here in real time.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: AppTheme.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final notif = filtered[index];
                      final catIcon = _getCategoryIcon(notif.category);
                      final catLabel = _getCategoryLabel(notif.category);

                      return Dismissible(
                        key: ValueKey(notif.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.referenceRed.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.referenceRed.withValues(alpha: 0.5)),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppTheme.referenceRed,
                            size: 22,
                          ),
                        ),
                        onDismissed: (_) {
                          AppHaptics.heavyImpact();
                          notifService.deleteNotification(notif.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.charcoalCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.charcoalBorder,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.charcoalInnerPill,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.charcoalInnerBorder),
                                    ),
                                    child: Icon(
                                      catIcon,
                                      color: AppTheme.textWhite,
                                      size: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.charcoalInnerPill,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.charcoalInnerBorder),
                                    ),
                                    child: Text(
                                      catLabel.toUpperCase(),
                                      style: GoogleFonts.spaceMono(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textWhite,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatTimestamp(notif.timestamp),
                                    style: GoogleFonts.spaceMono(
                                      fontSize: 10,
                                      color: AppTheme.textMuted.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    onPressed: () {
                                      AppHaptics.mediumImpact();
                                      notifService.deleteNotification(notif.id);
                                    },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: AppTheme.textMuted,
                                      size: 16,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                notif.title,
                                style: GoogleFonts.spaceMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textWhite,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notif.body,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: AppTheme.textMuted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required NotificationCategory? category,
  }) {
    final isSelected = _selectedCategoryFilter == category;
    return GestureDetector(
      onTap: () {
        AppHaptics.selectionClick();
        setState(() {
          _selectedCategoryFilter = category;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.charcoalInnerPill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.textWhite.withValues(alpha: 0.8) : AppTheme.charcoalInnerBorder,
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppTheme.textWhite : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context, BotNotificationService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.charcoalCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppTheme.charcoalBorder),
        ),
        title: Text(
          'Clear All Notifications?',
          style: GoogleFonts.spaceMono(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.textWhite,
          ),
        ),
        content: Text(
          'This will clear all logged alerts and milestone notifications.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.spaceMono(color: AppTheme.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.referenceRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              AppHaptics.heavyImpact();
              service.clearAll();
              Navigator.of(ctx).pop();
            },
            child: Text(
              'Clear All',
              style: GoogleFonts.spaceMono(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
