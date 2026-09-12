import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import '../../../../data/services/gemini_ai_service.dart';

class SavedConversationsSheet extends StatelessWidget {
  final Function(GeminiConversationSession session) onSelectSession;
  final VoidCallback onNewChat;

  const SavedConversationsSheet({
    super.key,
    required this.onSelectSession,
    required this.onNewChat,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(GeminiConversationSession session) onSelectSession,
    required VoidCallback onNewChat,
  }) {
    AppHaptics.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SavedConversationsSheet(
        onSelectSession: onSelectSession,
        onNewChat: onNewChat,
      ),
    );
  }

  String _formatSessionDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(dt.year, dt.month, dt.day);

    if (sessionDay == today) {
      return 'Today, ${DateFormat('hh:mm a').format(dt)}';
    } else if (sessionDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${DateFormat('hh:mm a').format(dt)}';
    } else {
      return DateFormat('MMM dd, hh:mm a').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final gemini = context.watch<GeminiAiService>();
    final sessions = gemini.savedConversations;

    return Container(
      height: screenHeight * 0.78,
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
          // Drag Handle & Header
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
                // Drag handle
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
                              Icons.forum_rounded,
                              color: AppTheme.textWhite,
                              size: 18,
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
                                      'Chat History',
                                      style: GoogleFonts.spaceMono(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textWhite,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.charcoalInnerPill,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.charcoalInnerBorder),
                                      ),
                                      child: Text(
                                        '${sessions.length}',
                                        style: GoogleFonts.spaceMono(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textWhite,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Review or resume past quant dialogues',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (sessions.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              AppHaptics.heavyImpact();
                              _confirmClearAll(context, gemini);
                            },
                            icon: const Icon(
                              Icons.delete_sweep_rounded,
                              color: AppTheme.referenceRed,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            tooltip: 'Clear All History',
                          ),
                        const SizedBox(width: 4),
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

          // Action Button: Start New Conversation
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  AppHaptics.mediumImpact();
                  Navigator.of(context).pop();
                  onNewChat();
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.charcoalInnerPill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.charcoalInnerBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.charcoalCard,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.charcoalInnerBorder),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: AppTheme.textWhite,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start New Chat Session',
                              style: GoogleFonts.spaceMono(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textWhite,
                              ),
                            ),
                            Text(
                              'Fresh slate with real-time portfolio telemetry',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.textWhite,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Conversation List or Empty State
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: AppTheme.textMuted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No Saved Conversations',
                            style: GoogleFonts.spaceMono(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textWhite,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Conversations with your Gemini Quant Co-Pilot will be automatically saved here for future reference.',
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
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final lastMsg = session.messages.isNotEmpty
                          ? session.messages.last.text
                          : 'Empty conversation';

                      return Dismissible(
                        key: ValueKey(session.id),
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
                          gemini.deleteConversation(session.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.charcoalCard,
                              content: Text(
                                'Conversation deleted',
                                style: GoogleFonts.spaceMono(
                                  color: AppTheme.textWhite,
                                  fontSize: 12,
                                ),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              AppHaptics.lightClick();
                              Navigator.of(context).pop();
                              onSelectSession(session);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.charcoalCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.charcoalBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          session.title,
                                          style: GoogleFonts.spaceMono(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textWhite,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.charcoalInnerPill,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${session.messages.length} msgs',
                                          style: GoogleFonts.spaceMono(
                                            fontSize: 9.5,
                                            color: AppTheme.textWhite,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        onPressed: () {
                                          AppHaptics.mediumImpact();
                                          gemini.deleteConversation(session.id);
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: AppTheme.textMuted,
                                          size: 17,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        tooltip: 'Delete Chat',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    lastMsg,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: AppTheme.textMuted,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatSessionDate(session.updatedAt),
                                        style: GoogleFonts.spaceMono(
                                          fontSize: 10,
                                          color: AppTheme.textMuted.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            'Resume',
                                            style: GoogleFonts.spaceMono(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textWhite,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            color: AppTheme.textWhite,
                                            size: 13,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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

  void _confirmClearAll(BuildContext context, GeminiAiService gemini) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.charcoalCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppTheme.charcoalBorder),
        ),
        title: Text(
          'Clear All History?',
          style: GoogleFonts.spaceMono(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.textWhite,
          ),
        ),
        content: Text(
          'This will permanently delete all saved Gemini conversation logs from local storage.',
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
              gemini.clearAllConversations();
              Navigator.of(ctx).pop();
            },
            child: Text(
              'Delete All',
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
