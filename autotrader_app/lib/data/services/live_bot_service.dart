import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bot_state.dart';
import '../models/position.dart';
import 'bot_telemetry_service.dart';

class LiveBotService {
  static final LiveBotService _instance = LiveBotService._internal();
  factory LiveBotService() => _instance;
  LiveBotService._internal();

  static const String defaultGlobalUrl = 'http://165.22.41.58:8000';
  static const String serverPrefKey = 'autotrader_server_url';

  // Server Base URL (Single Permanent Cloud Preset by default)
  String _baseUrl = defaultGlobalUrl;
  String _wsUrl = 'ws://165.22.41.58:8000/ws/telemetry';

  WebSocket? _webSocket;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _isAutoDiscovering = false;

  final _connectionStatusController = StreamController<bool>.broadcast();
  final _liveStateController = StreamController<BotState>.broadcast();
  final _livePositionsController = StreamController<List<Position>>.broadcast();
  final _liveSetupsController = StreamController<List<PotentialPurchase>>.broadcast();
  final _liveDecisionsController = StreamController<List<BotDecisionLog>>.broadcast();

  bool get isConnected => _isConnected;
  bool get isAutoDiscovering => _isAutoDiscovering;
  String get baseUrl => _baseUrl;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<BotState> get liveStateStream => _liveStateController.stream;
  Stream<List<Position>> get livePositionsStream => _livePositionsController.stream;
  Stream<List<PotentialPurchase>> get liveSetupsStream => _liveSetupsController.stream;
  Stream<List<BotDecisionLog>> get liveDecisionsStream => _liveDecisionsController.stream;

  void configureServer({required String host, int port = 8000}) {
    configureServerUrl('http://$host:$port');
  }

  void configureServerUrl(String rawInput) {
    var input = rawInput.trim();
    if (input.isEmpty) {
      input = defaultGlobalUrl;
    }

    // Handle bare IPs or hosts without scheme
    if (!input.startsWith('http://') && !input.startsWith('https://') &&
        !input.startsWith('ws://') && !input.startsWith('wss://')) {
      input = 'https://$input';
    }

    final uri = Uri.tryParse(input);
    if (uri == null || uri.host.isEmpty) return;

    final isSecure = uri.scheme == 'https' || uri.scheme == 'wss';
    final host = uri.host;
    final int? explicitPort = uri.hasPort ? uri.port : null;
    final defaultPort = isSecure ? 443 : 8000;
    final port = explicitPort ?? defaultPort;
    final portString = (isSecure && port == 443) || (!isSecure && port == 80) ? '' : ':$port';
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');

    _baseUrl = '${isSecure ? 'https' : 'http'}://$host$portString$path';
    _wsUrl = '${isSecure ? 'wss' : 'ws'}://$host$portString$path/ws/telemetry';

    if (kDebugMode) {
      print('[LiveBotService] Configured baseUrl: $_baseUrl | wsUrl: $_wsUrl');
    }
    reconnect();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(serverPrefKey) ?? defaultGlobalUrl;
    configureServerUrl(savedUrl);

    final isAlive = await checkConnection();
    if (!isAlive) {
      // If global tunnel is offline, check local loopback / LAN fallback
      if (kDebugMode) {
        print('[LiveBotService] Primary preset offline, probing local LAN fallback...');
      }
      autoDiscoverServer();
    } else {
      _startWebSocket();
    }
  }

  /// Probes UDP broadcast & local subnet to automatically locate the AutoTrader server
  Future<String?> autoDiscoverServer() async {
    if (_isAutoDiscovering) return null;
    _isAutoDiscovering = true;

    try {
      // Phase 1: Try UDP Discovery Broadcast (Fastest: < 100ms)
      try {
        final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        socket.broadcastEnabled = true;
        final data = utf8.encode('AUTOTRADER_DISCOVER');
        socket.send(data, InternetAddress('255.255.255.255'), 8001);

        final completer = Completer<String?>();
        late StreamSubscription sub;
        sub = socket.listen((event) {
          if (event == RawSocketEvent.read) {
            final dg = socket.receive();
            if (dg != null) {
              try {
                final text = utf8.decode(dg.data);
                final json = jsonDecode(text);
                if (json['service'] == 'autotrader') {
                  final ip = dg.address.address;
                  final port = json['port'] ?? 8000;
                  final target = 'http://$ip:$port';
                  if (!completer.isCompleted) completer.complete(target);
                }
              } catch (_) {}
            }
          }
        });

        final foundUdp = await completer.future.timeout(
          const Duration(milliseconds: 600),
          onTimeout: () => null,
        );
        await sub.cancel();
        socket.close();

        if (foundUdp != null) {
          if (kDebugMode) print('[LiveBotService] Auto-discovered via UDP: $foundUdp');
          await _applyDiscoveredUrl(foundUdp);
          return foundUdp;
        }
      } catch (e) {
        if (kDebugMode) print('[LiveBotService] UDP discovery error: $e');
      }

      // Phase 2: Probe Known Candidates
      final commonCandidates = [
        'http://165.22.41.58:8000', // DigitalOcean Cloud VPS (Permanent 24/7)
        'http://127.0.0.1:8000', // iOS Simulator & Localhost
        'http://192.168.1.82:8000', // Host Wi-Fi IP
        'http://10.0.2.2:8000', // Android Emulator Host
      ];

      for (final candidate in commonCandidates) {
        final ok = await _testCandidate(candidate);
        if (ok) {
          if (kDebugMode) print('[LiveBotService] Auto-discovered candidate: $candidate');
          await _applyDiscoveredUrl(candidate);
          return candidate;
        }
      }
    } finally {
      _isAutoDiscovering = false;
    }

    return null;
  }

  static const Map<String, String> standardHeaders = {
    'ngrok-skip-browser-warning': 'true',
    'User-Agent': 'AutoTraderApp/1.0',
    'Accept': 'application/json',
  };

  Future<bool> _testCandidate(String url) async {
    try {
      final res = await http.get(
        Uri.parse('$url/api/health'),
        headers: standardHeaders,
      ).timeout(const Duration(milliseconds: 500));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _applyDiscoveredUrl(String discoveredUrl) async {
    configureServerUrl(discoveredUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(serverPrefKey, discoveredUrl);
    await checkConnection();
    _startWebSocket();
  }

  Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/health'),
        headers: standardHeaders,
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        _setConnected(true);
        return true;
      }
    } catch (_) {
      _setConnected(false);
    }
    return false;
  }

  void _setConnected(bool status) {
    if (_isConnected != status) {
      _isConnected = status;
      _connectionStatusController.add(_isConnected);
      if (kDebugMode) {
        print('[LiveBotService] Connection status changed: $_isConnected (baseUrl: $_baseUrl)');
      }
    }
  }

  void _startWebSocket() async {
    _reconnectTimer?.cancel();
    if (_webSocket != null) {
      try {
        final oldWs = _webSocket;
        _webSocket = null;
        await oldWs?.close();
      } catch (_) {}
    }

    try {
      final ws = await WebSocket.connect(_wsUrl).timeout(const Duration(seconds: 4));
      _webSocket = ws;
      _setConnected(true);
      unawaited(fetchDecisions());

      ws.listen(
        (data) {
          _handleWebSocketMessage(data);
        },
        onDone: () {
          if (_webSocket == ws) {
            _setConnected(false);
            _scheduleReconnect();
          }
        },
        onError: (error) {
          if (_webSocket == ws) {
            _setConnected(false);
            _scheduleReconnect();
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      _setConnected(false);
      _scheduleReconnect();
    }
  }

  void _handleWebSocketMessage(dynamic data) {
    try {
      var rawString = data.toString();
      // Sanitize Python unquoted NaN and Infinity values in objects or arrays
      rawString = rawString.replaceAll(RegExp(r'-?\b(NaN|nan|Infinity)\b'), 'null');

      final Map<String, dynamic> json = jsonDecode(rawString);
      _setConnected(true);
      
      // Parse State
      if (json.containsKey('state') && json['state'] != null) {
        final s = json['state'];
        final portVal = (s['portfolio_value'] as num?)?.toDouble() ?? 20000.0;
        final cash = (s['cash'] as num?)?.toDouble() ?? (portVal * 0.18);
        final state = BotState(
          portfolioValue: portVal,
          todayGainDollars: (s['today_gain_dollars'] as num?)?.toDouble() ?? 0.0,
          totalGainDollars: (s['total_gain_dollars'] as num?)?.toDouble() ?? 0.0,
          totalGainPercent: (s['total_gain_percent'] as num?)?.toDouble() ?? 0.0,
          cashBalance: cash,
          buyingPower: cash,
          activeRegime: s['active_regime'] ?? 'BULL_TRENDING',
          executionLoopActive: s['execution_loop_active'] ?? true,
          canaryAiActive: s['canary_ai_active'] ?? true,
          shariahDaemonActive: s['shariah_daemon_active'] ?? true,
          charityCleansedDollars: (s['total_charity_purified'] as num?)?.toDouble() ?? 0.0,
        );
        _liveStateController.add(state);
      }

      // Parse Positions
      if (json.containsKey('positions') && json['positions'] != null) {
        final List list = json['positions'];
        final positions = list.map((p) => Position(
          symbol: p['symbol'] ?? 'ASSET',
          companyName: p['company_name'] ?? p['symbol'] ?? 'Asset',
          entryPrice: (p['entry_price'] as num?)?.toDouble() ?? 0.0,
          livePrice: (p['live_price'] as num?)?.toDouble() ?? 0.0,
          shares: (p['shares'] as num?)?.round() ?? 100,
          protectedFloor: (p['protected_floor'] as num?)?.toDouble() ?? 0.0,
          lockedGainPercent: (p['locked_gain_percent'] as num?)?.toDouble() ?? 0.0,
          ratchetTier: p['ratchet_tier'] ?? 'Tier 2 (+60% Locked)',
          isHalal: p['is_halal'] ?? true,
          priceNodes: (p['price_nodes'] as List?)?.map((e) => (e as num?)?.toDouble() ?? 0.0).toList() ?? [],
          charityPurificationRate: (p['charity_purification_rate'] as num?)?.toDouble() ?? 0.01,
        )).toList();
        _livePositionsController.add(positions);
      }

      // Parse Potential Setups
      if (json.containsKey('setups') && json['setups'] != null) {
        final List list = json['setups'];
        final setups = list.map((s) => PotentialPurchase(
          symbol: s['symbol'] ?? 'ASSET',
          companyName: s['company_name'] ?? s['symbol'] ?? 'Asset',
          currentPrice: (s['current_price'] as num?)?.toDouble() ?? 184.20,
          rvol: (s['rvol'] as num?)?.toDouble() ?? 1.0,
          distance200Ema: (s['distance_200_ema'] as num?)?.toDouble() ?? 0.0,
          suggestedEntry: (s['suggested_entry'] as num?)?.toDouble() ?? 189.90,
          suggestedStopLoss: (s['suggested_stop_loss'] as num?)?.toDouble() ?? 172.80,
          setupReason: s['setup_reason'] ?? '',
          rank: s['rank'] ?? 1,
          probabilityScore: (s['probability_score'] as num?)?.toDouble() ?? 85.0,
          priorityLabel: s['priority_label'] ?? 'READY',
          priceNodes: (s['price_nodes'] as List?)?.map((e) => (e as num?)?.toDouble() ?? 0.0).toList() ?? [],
        )).toList();
        _liveSetupsController.add(setups);
      }

      // Parse Universal Server Decisions
      if (json.containsKey('decisions')) {
        final List list = json['decisions'];
        final decisions = list.map((d) {
          final (dateKey, formattedTime, parsedDate) = _formatTimestampAndDateKey(
            d['timestamp'],
            d['iso_timestamp'],
            d['date_key'],
          );
          return BotDecisionLog(
            dateKey: dateKey,
            timestamp: formattedTime,
            category: d['category'] ?? 'EXECUTION',
            assetSymbol: d['asset_symbol'] ?? 'BOT',
            assetName: d['asset_name'] ?? 'AutoTrader Engine',
            impactBadge: d['impact_badge'] ?? 'ACTIVE',
            title: d['title'] ?? '',
            detail: d['detail'] ?? '',
            aiTakeaway: d['ai_takeaway'] ?? '',
            isPositive: d['is_positive'] ?? true,
            dateTime: parsedDate,
          );
        }).toList();
        _liveDecisionsController.add(decisions);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LiveBotService] Error parsing WebSocket payload: $e');
      }
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_isConnected) {
        timer.cancel();
        return;
      }
      final alive = await checkConnection();
      if (alive) {
        timer.cancel();
        _startWebSocket();
      } else {
        await autoDiscoverServer();
      }
    });
  }

  void reconnect() {
    _reconnectTimer?.cancel();
    _startWebSocket();
  }

  // REST API Actions
  Future<bool> closePosition(String symbol) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/trade/close'),
        headers: {
          ...standardHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'symbol': symbol}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> triggerUniverseScan() async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/scan'),
        headers: {
          ...standardHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'top_n': 4}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static (String dateKey, String formattedTime, DateTime? parsedDate) _formatTimestampAndDateKey(dynamic raw, dynamic iso, String? rawDateKey) {
    if (iso != null) {
      try {
        final parsed = DateTime.parse(iso.toString()).toLocal();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final eventDate = DateTime(parsed.year, parsed.month, parsed.day);
        final diffDays = today.difference(eventDate).inDays;

        final hour = parsed.hour > 12 ? parsed.hour - 12 : (parsed.hour == 0 ? 12 : parsed.hour);
        final period = parsed.hour >= 12 ? 'PM' : 'AM';
        final min = parsed.minute.toString().padLeft(2, '0');
        final timeStr = '${hour.toString().padLeft(2, '0')}:$min $period';

        if (diffDays == 0) {
          return ('Today', 'Today, $timeStr', parsed);
        } else if (diffDays == 1) {
          return ('Yesterday', 'Yesterday, $timeStr', parsed);
        } else {
          final monthStr = _monthNames[parsed.month - 1];
          final dateStr = '$monthStr ${parsed.day}';
          return (dateStr, '$dateStr, $timeStr', parsed);
        }
      } catch (_) {}
    }
    final fallbackDateKey = rawDateKey ?? 'Today';
    return (fallbackDateKey, raw?.toString() ?? '$fallbackDateKey, 09:30 AM', null);
  }

  Future<List<BotDecisionLog>> fetchDecisions() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/decisions'), headers: standardHeaders)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        final decisions = list.map((d) {
          final (dateKey, formattedTime, parsedDate) = _formatTimestampAndDateKey(
            d['timestamp'],
            d['iso_timestamp'],
            d['date_key'],
          );
          return BotDecisionLog(
            dateKey: dateKey,
            timestamp: formattedTime,
            category: d['category'] ?? 'EXECUTION',
            assetSymbol: d['asset_symbol'] ?? 'BOT',
            assetName: d['asset_name'] ?? 'AutoTrader Engine',
            impactBadge: d['impact_badge'] ?? 'ACTIVE',
            title: d['title'] ?? '',
            detail: d['detail'] ?? '',
            aiTakeaway: d['ai_takeaway'] ?? '',
            isPositive: d['is_positive'] ?? true,
            dateTime: parsedDate,
          );
        }).toList();
        _liveDecisionsController.add(decisions);
        return decisions;
      }
    } catch (_) {}
    return [];
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _webSocket?.close();
    _connectionStatusController.close();
    _liveStateController.close();
    _livePositionsController.close();
    _liveSetupsController.close();
  }
}
