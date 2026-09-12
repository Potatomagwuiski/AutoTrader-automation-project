import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NotificationCategory {
  execution,
  regimeShift,
  riskSentinel,
  shariahAudit,
  canaryAi,
  systemAlert,
}

class BotNotificationItem {
  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime timestamp;
  bool isRead;

  BotNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category.name,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  factory BotNotificationItem.fromJson(Map<String, dynamic> json) {
    return BotNotificationItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Bot Alert',
      body: json['body'] as String? ?? '',
      category: NotificationCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => NotificationCategory.systemAlert,
      ),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}

class BotNotificationService extends ChangeNotifier {
  static const String _prefNotificationsKey = 'autotrader_saved_notifications_v1';
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final BotNotificationService _instance = BotNotificationService._internal();
  factory BotNotificationService() => _instance;

  final List<BotNotificationItem> _notifications = [];
  bool _isSystemPushInitialized = false;

  List<BotNotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  BotNotificationService._internal() {
    _initLocalNotifications();
    _loadFromStorage();
  }

  Future<void> _initLocalNotifications() async {
    if (_isSystemPushInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _localNotificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          debugPrint('Notification clicked: ${details.payload}');
        },
      );

      // Explicitly request permissions on both platforms
      await requestPermissions();

      // Create Android Notification Channel for High-Priority Trading Alerts
      final androidImplementation = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        const channel = AndroidNotificationChannel(
          'autotrader_high_priority_channel',
          'Trading Cockpit Alerts',
          description: 'High-priority alerts for order fills, breakout triggers, and risk stops',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
          showBadge: true,
        );
        await androidImplementation.createNotificationChannel(channel);
      }

      _isSystemPushInitialized = true;
      debugPrint('[BotNotificationService] Native Push Notification system armed');
    } catch (e, stack) {
      debugPrint('[BotNotificationService] Failed to init native push: $e\n$stack');
    }
  }

  /// Explicitly requests system notification permissions from the OS
  Future<bool> requestPermissions() async {
    try {
      final androidImpl = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        debugPrint('[BotNotificationService] Android notification permission granted: $granted');
      }

      final iosImpl = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosImpl != null) {
        final granted = await iosImpl.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('[BotNotificationService] iOS notification permission granted: $granted');
      }
      return true;
    } catch (e) {
      debugPrint('[BotNotificationService] Error requesting permissions: $e');
      return false;
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefNotificationsKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _notifications.clear();
        _notifications.addAll(
          decoded.map((item) => BotNotificationItem.fromJson(item as Map<String, dynamic>)),
        );
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } else {
        _seedInitialMilestoneNotifications();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  void _seedInitialMilestoneNotifications() {
    final now = DateTime.now();
    _notifications.addAll([
      BotNotificationItem(
        id: 'notif_1',
        title: 'Breakout Watchlist Armed',
        body: 'Canary AI & RVOL Scanner active on top leaders: CRWD (\$230.91), MRVL (\$256.60), SNOW (\$337.50), PLTR (\$189.90).',
        category: NotificationCategory.execution,
        timestamp: now.subtract(const Duration(minutes: 5)),
        isRead: false,
      ),
      BotNotificationItem(
        id: 'notif_2',
        title: 'Macro Regime: BULL_TRENDING',
        body: 'S&P 500 trading firmly above 200-EMA. Full swing allocation authorized with 100% cash preserved in standby.',
        category: NotificationCategory.regimeShift,
        timestamp: now.subtract(const Duration(minutes: 25)),
        isRead: false,
      ),
      BotNotificationItem(
        id: 'notif_3',
        title: 'AAOIFI Shariah Audit Verified',
        body: 'Automated 10-Q filing balance sheet audit confirmed 100% compliance across active watchlist. Debt ratios < 30%.',
        category: NotificationCategory.shariahAudit,
        timestamp: now.subtract(const Duration(hours: 1)),
        isRead: false,
      ),
      BotNotificationItem(
        id: 'notif_4',
        title: 'Alpaca Direct Market Access Bridge Active',
        body: 'Connected to Alpaca Paper Broker (PA3NWAUW7TP1) with \$20,000.00 cash purchasing power and sub-5ms routing.',
        category: NotificationCategory.systemAlert,
        timestamp: now.subtract(const Duration(hours: 2)),
        isRead: true,
      ),
    ]);
  }

  /// Triggers both in-app list logging AND native OS push notifications (lock screen / notification shade)
  Future<void> addNotification({
    required String title,
    required String body,
    required NotificationCategory category,
    bool showNativePush = true,
  }) async {
    final item = BotNotificationItem(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      category: category,
      timestamp: DateTime.now(),
      isRead: false,
    );
    _notifications.insert(0, item);
    _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
    _saveToStorage();

    // Trigger Native OS Background Notification
    if (showNativePush) {
      await _deliverNativePushNotification(title: title, body: body, category: category);
    }
  }

  Future<void> _deliverNativePushNotification({
    required String title,
    required String body,
    required NotificationCategory category,
  }) async {
    try {
      if (!_isSystemPushInitialized) {
        await _initLocalNotifications();
      }

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      const androidDetails = AndroidNotificationDetails(
        'autotrader_high_priority_channel',
        'Trading Cockpit Alerts',
        channelDescription: 'High-priority alerts for order fills, breakout triggers, and risk stops',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      // When the user is actively inside the app, suppress intrusive drop-down banners
      // so they can use the cockpit smoothly. In-app bell badge & decision feeds update live.
      // Full banners still appear when the app is in the background or the phone is locked.
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: true,
        presentSound: false,
        presentBanner: false,
        presentList: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _localNotificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: category.name,
      );
      debugPrint('[BotNotificationService] Native push sent successfully: $title');
    } catch (e, stack) {
      debugPrint('[BotNotificationService] Error delivering native push: $e\n$stack');
    }
  }

  void markAllAsRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
    _saveToStorage();
  }

  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
    _saveToStorage();
  }

  void clearAll() {
    _notifications.clear();
    cancelAllPush();
    notifyListeners();
    _saveToStorage();
  }

  Future<void> cancelAllPush() async {
    try {
      await _localNotificationsPlugin.cancelAll();
      debugPrint('[BotNotificationService] Cleared all native OS notifications');
    } catch (e) {
      debugPrint('[BotNotificationService] Error clearing native notifications: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_notifications.map((n) => n.toJson()).toList());
      await prefs.setString(_prefNotificationsKey, encoded);
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }
}
