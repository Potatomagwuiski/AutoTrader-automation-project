// Real-time temporal & US equity market session context

class CockpitTimeContext {
  final DateTime localTime;
  final DateTime usEasternTime;
  final String timeOfDayGreeting;
  final String localFormatted;
  final String usEasternFormatted;
  final String marketSession;
  final String sessionDescription;
  final bool isMarketOpen;

  const CockpitTimeContext({
    required this.localTime,
    required this.usEasternTime,
    required this.timeOfDayGreeting,
    required this.localFormatted,
    required this.usEasternFormatted,
    required this.marketSession,
    required this.sessionDescription,
    required this.isMarketOpen,
  });

  factory CockpitTimeContext.fromDateTime(DateTime local) {
    final hour = local.hour;
    final String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good afternoon';
    } else if (hour >= 17 && hour < 22) {
      greeting = 'Good evening';
    } else {
      // 22:00 to 04:59 (late night / overnight)
      greeting = 'Good evening';
    }

    // US Eastern Time calculation (UTC-4 during DST, UTC-5 during standard time)
    final utc = local.toUtc();
    final isDst = _isUsEasternDst(utc);
    final etOffsetHours = isDst ? -4 : -5;
    final et = utc.add(Duration(hours: etOffsetHours));

    // Market Session Evaluation based on US Eastern Time
    final etHour = et.hour;
    final etMinute = et.minute;
    final etTotalMinutes = etHour * 60 + etMinute;
    final etWeekday = et.weekday; // 1: Mon ... 5: Fri, 6: Sat, 7: Sun

    final String session;
    final String desc;
    final bool isOpen;

    if (etWeekday == 6 || etWeekday == 7) {
      session = 'WEEKEND_STANDBY';
      desc = 'US Equity Markets are CLOSED for the weekend. Screener on standby for Monday opening bell.';
      isOpen = false;
    } else {
      // Weekday (Mon-Fri)
      if (etTotalMinutes >= 4 * 60 && etTotalMinutes < 9 * 60 + 30) {
        session = 'PRE_MARKET';
        desc = 'US Pre-Market session active (04:00 - 09:30 ET). Monitoring pre-bell institutional gap and volume.';
        isOpen = false;
      } else if (etTotalMinutes >= 9 * 60 + 30 && etTotalMinutes < 16 * 60) {
        session = 'REGULAR_TRADING_HOURS';
        desc = 'US Regular Trading Hours active (09:30 - 16:00 ET). Order execution router armed for live trigger crosses.';
        isOpen = true;
      } else if (etTotalMinutes >= 16 * 60 && etTotalMinutes < 20 * 60) {
        session = 'AFTER_HOURS';
        desc = 'US Post-Market / After-Hours session active (16:00 - 20:00 ET). Reviewing closing prints and institutional volume.';
        isOpen = false;
      } else {
        session = 'OVERNIGHT_STANDBY';
        desc = 'US Equity Markets are CLOSED for the night (20:00 - 04:00 ET). 100% capital safely guarded in liquid cash defense.';
        isOpen = false;
      }
    }

    final localFormatted = _formatDateTime(local);
    final etFormatted = '${_formatDateTime(et)} ${isDst ? "EDT" : "EST"}';

    return CockpitTimeContext(
      localTime: local,
      usEasternTime: et,
      timeOfDayGreeting: greeting,
      localFormatted: localFormatted,
      usEasternFormatted: etFormatted,
      marketSession: session,
      sessionDescription: desc,
      isMarketOpen: isOpen,
    );
  }

  factory CockpitTimeContext.now() => CockpitTimeContext.fromDateTime(DateTime.now());

  static bool _isUsEasternDst(DateTime utc) {
    final year = utc.year;
    // Second Sunday in March (starts at 02:00 EST = 07:00 UTC)
    final march1 = DateTime.utc(year, 3, 1);
    final firstSunMarch = (8 - march1.weekday) % 7 + 1;
    final secondSunMarch = firstSunMarch + 7;
    final dstStart = DateTime.utc(year, 3, secondSunMarch, 7);

    // First Sunday in November (ends at 02:00 EDT = 06:00 UTC)
    final nov1 = DateTime.utc(year, 11, 1);
    final firstSunNov = (8 - nov1.weekday) % 7 + 1;
    final dstEnd = DateTime.utc(year, 11, firstSunNov, 6);

    return utc.isAfter(dstStart) && utc.isBefore(dstEnd);
  }

  static String _formatDateTime(DateTime dt) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dayName = days[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    return '$dayName, $monthName ${dt.day}, ${dt.year} at $hour12:$minuteStr $amPm';
  }
}
