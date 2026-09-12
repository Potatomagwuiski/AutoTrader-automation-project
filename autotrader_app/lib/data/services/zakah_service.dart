import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ZakahMethodology {
  activeTrading, // Urud al-Tijarah: 100% of liquid portfolio equity at 2.5% (AAOIFI Standard)
  passiveWorkingCapital, // 25% Rule proxy on share equity + 100% cash
}

enum ZakahCalendar {
  lunar, // 354 days / 2.500% statutory rate
  solar, // 365 days / 2.577% adjusted rate
}

class ZakahPaymentRecord {
  final String id;
  final DateTime timestamp;
  final double amount;
  final String methodology;
  final String calendar;
  final String recipientNote;

  const ZakahPaymentRecord({
    required this.id,
    required this.timestamp,
    required this.amount,
    required this.methodology,
    required this.calendar,
    required this.recipientNote,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'amount': amount,
        'methodology': methodology,
        'calendar': calendar,
        'recipientNote': recipientNote,
      };

  factory ZakahPaymentRecord.fromJson(Map<String, dynamic> json) =>
      ZakahPaymentRecord(
        id: json['id'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        methodology: json['methodology'] as String? ?? 'activeTrading',
        calendar: json['calendar'] as String? ?? 'lunar',
        recipientNote: json['recipientNote'] as String? ?? '',
      );
}

class ZakahCalculationResult {
  final double totalEquity;
  final double cashBalance;
  final double positionsMarketValue;
  final double zakatableEquity;
  final double nisabThreshold;
  final bool isNisabMet;
  final double zakahRate;
  final double estimatedZakahDue;
  final ZakahMethodology methodology;
  final ZakahCalendar calendar;
  final DateTime hawlStartDate;
  final int hawlCycleDays;
  final int daysElapsed;
  final int daysRemaining;
  final double hawlProgress;

  const ZakahCalculationResult({
    required this.totalEquity,
    required this.cashBalance,
    required this.positionsMarketValue,
    required this.zakatableEquity,
    required this.nisabThreshold,
    required this.isNisabMet,
    required this.zakahRate,
    required this.estimatedZakahDue,
    required this.methodology,
    required this.calendar,
    required this.hawlStartDate,
    required this.hawlCycleDays,
    required this.daysElapsed,
    required this.daysRemaining,
    required this.hawlProgress,
  });
}

class ZakahService extends ChangeNotifier {
  static const String _prefMethodologyKey = 'zakah_methodology_v1';
  static const String _prefCalendarKey = 'zakah_calendar_v1';
  static const String _prefHawlStartKey = 'zakah_hawl_start_v1';
  static const String _prefNisabKey = 'zakah_custom_nisab_v1';
  static const String _prefPaymentsKey = 'zakah_payment_history_v1';

  static const double defaultGoldNisabUsd = 7000.0; // 85 grams of gold standard benchmark

  ZakahMethodology _methodology = ZakahMethodology.activeTrading;
  ZakahCalendar _calendar = ZakahCalendar.lunar;
  DateTime _hawlStartDate = DateTime.now().subtract(const Duration(days: 70));
  double _nisabThreshold = defaultGoldNisabUsd;
  List<ZakahPaymentRecord> _payments = [];
  bool _isLoaded = false;

  ZakahService() {
    _loadPreferences();
  }

  ZakahMethodology get methodology => _methodology;
  ZakahCalendar get calendar => _calendar;
  DateTime get hawlStartDate => _hawlStartDate;
  double get nisabThreshold => _nisabThreshold;
  List<ZakahPaymentRecord> get payments => List.unmodifiable(_payments);
  bool get isLoaded => _isLoaded;

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final methodStr = prefs.getString(_prefMethodologyKey);
      if (methodStr != null) {
        _methodology = methodStr == 'passiveWorkingCapital'
            ? ZakahMethodology.passiveWorkingCapital
            : ZakahMethodology.activeTrading;
      }

      final calStr = prefs.getString(_prefCalendarKey);
      if (calStr != null) {
        _calendar = calStr == 'solar' ? ZakahCalendar.solar : ZakahCalendar.lunar;
      }

      final hawlStr = prefs.getString(_prefHawlStartKey);
      if (hawlStr != null) {
        final parsed = DateTime.tryParse(hawlStr);
        if (parsed != null) _hawlStartDate = parsed;
      }

      _nisabThreshold = prefs.getDouble(_prefNisabKey) ?? defaultGoldNisabUsd;

      final rawPayments = prefs.getString(_prefPaymentsKey);
      if (rawPayments != null && rawPayments.trim().isNotEmpty) {
        final decoded = jsonDecode(rawPayments) as List<dynamic>;
        _payments = decoded
            .map((item) =>
                ZakahPaymentRecord.fromJson(item as Map<String, dynamic>))
            .toList();
        _payments.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } else {
        // Pre-seed an archived verified payment for demonstration
        _payments = [
          ZakahPaymentRecord(
            id: 'seed_zakah_1446',
            timestamp: DateTime.now().subtract(const Duration(days: 70)),
            amount: 475.00,
            methodology: 'activeTrading',
            calendar: 'lunar',
            recipientNote: 'Ramadan 1446 Direct Shariah Relief Fund',
          ),
        ];
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading Zakah preferences: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefMethodologyKey,
          _methodology == ZakahMethodology.passiveWorkingCapital
              ? 'passiveWorkingCapital'
              : 'activeTrading');
      await prefs.setString(
          _prefCalendarKey, _calendar == ZakahCalendar.solar ? 'solar' : 'lunar');
      await prefs.setString(_prefHawlStartKey, _hawlStartDate.toIso8601String());
      await prefs.setDouble(_prefNisabKey, _nisabThreshold);

      final encoded =
          jsonEncode(_payments.map((p) => p.toJson()).toList());
      await prefs.setString(_prefPaymentsKey, encoded);
    } catch (e) {
      debugPrint('Error saving Zakah preferences: $e');
    }
  }

  void setMethodology(ZakahMethodology method) {
    if (_methodology == method) return;
    _methodology = method;
    notifyListeners();
    _savePreferences();
  }

  void setCalendar(ZakahCalendar cal) {
    if (_calendar == cal) return;
    _calendar = cal;
    notifyListeners();
    _savePreferences();
  }

  void setHawlStartDate(DateTime date) {
    _hawlStartDate = date;
    notifyListeners();
    _savePreferences();
  }

  void setCustomNisab(double amount) {
    if (amount <= 0) return;
    _nisabThreshold = amount;
    notifyListeners();
    _savePreferences();
  }

  Future<void> recordPayment({
    required double amount,
    required String recipientNote,
  }) async {
    final record = ZakahPaymentRecord(
      id: 'zakah_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      amount: amount,
      methodology: _methodology == ZakahMethodology.activeTrading
          ? 'activeTrading'
          : 'passiveWorkingCapital',
      calendar: _calendar == ZakahCalendar.solar ? 'solar' : 'lunar',
      recipientNote: recipientNote.trim().isEmpty
          ? 'Verified Zakah Disbursal'
          : recipientNote.trim(),
    );

    _payments.insert(0, record);
    // Reset Hawl anniversary to current date upon payment
    _hawlStartDate = DateTime.now();
    notifyListeners();
    await _savePreferences();
  }

  Future<void> deletePayment(String id) async {
    _payments.removeWhere((p) => p.id == id);
    notifyListeners();
    await _savePreferences();
  }

  ZakahCalculationResult calculate({
    required double portfolioValue,
    required double cashBalance,
    required double positionsMarketValue,
  }) {
    // 1. Determine Zakatable Equity Base
    double zakatableEquity;
    if (_methodology == ZakahMethodology.activeTrading) {
      // Urud al-Tijarah (Trade goods): 100% of portfolio equity
      zakatableEquity = portfolioValue > 0 ? portfolioValue : (cashBalance + positionsMarketValue);
    } else {
      // Passive investment: 100% Cash + 25% Working Capital Proxy of open shares
      zakatableEquity = cashBalance + (positionsMarketValue * 0.25);
    }

    // 2. Nisab Check
    final isNisabMet = zakatableEquity >= _nisabThreshold;

    // 3. Statutory Rate
    // Lunar year = 2.500% (1/40th)
    // Solar year = 2.577% (adjusts for 365 vs 354 days)
    final zakahRate = _calendar == ZakahCalendar.lunar ? 0.025 : 0.02577;

    final estimatedZakahDue = isNisabMet ? (zakatableEquity * zakahRate) : 0.0;

    // 4. Hawl Cycle Tracking
    final cycleDays = _calendar == ZakahCalendar.lunar ? 354 : 365;
    final now = DateTime.now();
    final differenceDays = now.difference(_hawlStartDate).inDays;
    final daysElapsed = differenceDays < 0 ? 0 : differenceDays;
    final daysRemaining = (cycleDays - (daysElapsed % cycleDays)) % cycleDays;
    final rawProgress = (daysElapsed % cycleDays) / cycleDays;
    final hawlProgress = rawProgress.clamp(0.0, 1.0);

    return ZakahCalculationResult(
      totalEquity: portfolioValue,
      cashBalance: cashBalance,
      positionsMarketValue: positionsMarketValue,
      zakatableEquity: zakatableEquity,
      nisabThreshold: _nisabThreshold,
      isNisabMet: isNisabMet,
      zakahRate: zakahRate,
      estimatedZakahDue: estimatedZakahDue,
      methodology: _methodology,
      calendar: _calendar,
      hawlStartDate: _hawlStartDate,
      hawlCycleDays: cycleDays,
      daysElapsed: daysElapsed,
      daysRemaining: daysRemaining,
      hawlProgress: hawlProgress,
    );
  }
}
