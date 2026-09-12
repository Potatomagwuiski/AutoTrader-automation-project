import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/services/gemini_ai_service.dart';
import '../../../../data/services/live_bot_service.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import '../view_models/dashboard_view_model.dart';

class AiCompanionSettingsSheet extends StatefulWidget {
  const AiCompanionSettingsSheet({super.key});

  @override
  State<AiCompanionSettingsSheet> createState() => _AiCompanionSettingsSheetState();
}

class _AiCompanionSettingsSheetState extends State<AiCompanionSettingsSheet> {
  late TextEditingController _controller;
  late TextEditingController _serverController;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _serverFocusNode = FocusNode();
  final FocusNode _keyFocusNode = FocusNode();
  bool _obscureText = true;
  bool _isConnectingServer = false;
  String? _testSuccessMessage;
  String? _serverSuccessMessage;

  @override
  void initState() {
    super.initState();
    final gemini = context.read<GeminiAiService>();
    _controller = TextEditingController(text: gemini.apiKey);
    _serverController = TextEditingController(text: LiveBotService().baseUrl);
    _loadSavedServerUrl();

    _serverFocusNode.addListener(() {
      if (_serverFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (_scrollController.hasClients && mounted) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    });
  }

  Future<void> _loadSavedServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(LiveBotService.serverPrefKey);
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _serverController.text = saved);
    }
  }

  Future<void> _saveAndConnectServer() async {
    AppHaptics.mediumImpact();
    final raw = _serverController.text.trim();
    final targetUrl = raw.isEmpty ? LiveBotService.defaultGlobalUrl : raw;

    setState(() {
      _isConnectingServer = true;
      _serverSuccessMessage = null;
    });

    LiveBotService().configureServerUrl(targetUrl);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LiveBotService.serverPrefKey, LiveBotService().baseUrl);

    // Test connectivity
    final ok = await LiveBotService().checkConnection();
    if (!mounted) return;

    setState(() {
      _isConnectingServer = false;
      if (ok) {
        AppHaptics.successNotification();
        _serverSuccessMessage = '✓ Connected to AutoTrader Global Engine!';
      } else {
        _serverSuccessMessage = '⚠️ Server offline. Please verify the tunnel is active.';
      }
    });

    if (ok && mounted) {
      try {
        context.read<DashboardViewModel>().refreshAllData();
      } catch (_) {}
    }
  }

  Future<void> _resetToGlobalPreset() async {
    AppHaptics.lightClick();
    _serverController.text = LiveBotService.defaultGlobalUrl;
    await _saveAndConnectServer();
  }

  @override
  void dispose() {
    _controller.dispose();
    _serverController.dispose();
    _scrollController.dispose();
    _serverFocusNode.dispose();
    _keyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _testAndSave(GeminiAiService gemini) async {
    AppHaptics.mediumImpact();
    final key = _controller.text.trim();
    if (key.isEmpty) {
      await gemini.saveApiKey('');
      if (!mounted) return;
      setState(() {
        _testSuccessMessage = 'Switched to High-Speed Local Engine (0ms, \$0).';
      });
      try {
        context.read<DashboardViewModel>().refreshAllData();
      } catch (_) {}
      return;
    }

    final success = await gemini.testConnection(key);
    if (!mounted) return;
    if (success) {
      await gemini.saveApiKey(key);
      if (!mounted) return;
      AppHaptics.successNotification();
      setState(() {
        _testSuccessMessage = '✓ Connected to Google Gemini Live API!';
      });
      try {
        context.read<DashboardViewModel>().refreshAllData();
      } catch (_) {}
    }
  }

  String _formatErrorMessage(String raw) {
    if (raw.contains('Quota exceeded') || raw.contains('429') || raw.contains('exceeded your current quota')) {
      return 'Google Free Tier Quota Reached. The On-Device Engine is active (0ms, \$0).';
    }
    if (raw.contains('404') || raw.contains('not found')) {
      return 'Model updated. Please test connection again.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final gemini = context.watch<GeminiAiService>();
    final isConnected = gemini.isGeminiConnected && gemini.hasApiKey;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.charcoalCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: AppTheme.charcoalBorder, width: 1.5)),
        ),
        padding: const EdgeInsets.only(
          left: 22,
          right: 22,
          top: 16,
          bottom: 28,
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.charcoalInnerBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.mint.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.psychology_rounded, color: AppTheme.mint, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Engine & Gemini API',
                              style: GoogleFonts.spaceMono(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textWhite,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Official Google ${gemini.modelDisplayName} Integration',
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
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Live Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isConnected
                    ? AppTheme.mint.withValues(alpha: 0.12)
                    : AppTheme.charcoalInnerPill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isConnected
                      ? AppTheme.mint.withValues(alpha: 0.3)
                      : AppTheme.charcoalInnerBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isConnected ? AppTheme.mint : AppTheme.referenceOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isConnected
                          ? 'Google Gemini Live API (Online 🟢)'
                          : 'Local High-Speed Engine (Active ⚡, 0ms latency, \$0)',
                      style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isConnected ? AppTheme.mint : AppTheme.textWhite,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // API Key Input
            Text(
              'GOOGLE GEMINI API KEY (FREE)',
              style: GoogleFonts.spaceMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.charcoalInnerPill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.charcoalInnerBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _keyFocusNode,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      obscureText: _obscureText,
                      style: GoogleFonts.spaceMono(fontSize: 12.5, color: AppTheme.textWhite),
                      decoration: InputDecoration(
                        hintText: 'AIzaSy...',
                        hintStyle: GoogleFonts.spaceMono(fontSize: 12, color: AppTheme.textMuted),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 18,
                      color: AppTheme.textMuted,
                    ),
                    onPressed: () {
                      setState(() => _obscureText = !_obscureText);
                    },
                  ),
                ],
              ),
            ),

            if (!isConnected && gemini.lastError != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.referenceRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.referenceRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppTheme.referenceRed, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatErrorMessage(gemini.lastError!),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          height: 1.35,
                          color: AppTheme.referenceRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_testSuccessMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _testSuccessMessage!,
                style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.mint, fontWeight: FontWeight.w600),
              ),
            ],

            const SizedBox(height: 14),

            // Gemini Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      _controller.clear();
                      await gemini.saveApiKey('');
                      setState(() {
                        _testSuccessMessage = 'Reset to Local Engine.';
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textMuted,
                      side: const BorderSide(color: AppTheme.charcoalInnerBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Clear Key',
                      style: GoogleFonts.spaceMono(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: gemini.isLoading ? null : () => _testAndSave(gemini),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mint,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: gemini.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Text(
                            'Test & Save Key',
                            style: GoogleFonts.spaceMono(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── SINGLE GLOBAL PRESET SERVER SECTION ─────────────────────────
            Container(width: double.infinity, height: 1, color: AppTheme.charcoalInnerBorder),
            const SizedBox(height: 20),

            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.public_rounded, color: Color(0xFF00E5FF), size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AutoTrader Cloud Engine',
                        style: GoogleFonts.spaceMono(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textWhite,
                        ),
                      ),
                      Text(
                        '24/7 DigitalOcean Cloud Engine (Permanent IP)',
                        style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF00E5FF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Server Status Badge (Fixed double circle bug)
            StreamBuilder<bool>(
              stream: LiveBotService().connectionStatusStream,
              initialData: LiveBotService().isConnected,
              builder: (ctx, snap) {
                final live = snap.data ?? false;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: live
                        ? const Color(0xFF00E5FF).withValues(alpha: 0.10)
                        : AppTheme.charcoalInnerPill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: live
                          ? const Color(0xFF00E5FF).withValues(alpha: 0.35)
                          : AppTheme.charcoalInnerBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: live ? const Color(0xFF00E5FF) : AppTheme.referenceRed,
                          boxShadow: [
                            BoxShadow(
                              color: (live ? const Color(0xFF00E5FF) : AppTheme.referenceRed).withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        live ? 'LIVE — Cloud Engine Connected' : 'OFFLINE — Engine Unreachable',
                        style: GoogleFonts.spaceMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: live ? const Color(0xFF00E5FF) : AppTheme.referenceRed,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CLOUD SERVER URL',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                GestureDetector(
                  onTap: _resetToGlobalPreset,
                  child: Text(
                    'Reset to Default Preset',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF00E5FF),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.charcoalInnerPill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.charcoalInnerBorder),
              ),
              child: TextField(
                controller: _serverController,
                focusNode: _serverFocusNode,
                scrollPadding: const EdgeInsets.only(bottom: 160),
                style: GoogleFonts.spaceMono(fontSize: 12, color: AppTheme.textWhite),
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'http://127.0.0.1:8000 or http://165.22.41.58:8000',
                  hintStyle: GoogleFonts.spaceMono(fontSize: 11, color: AppTheme.textMuted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('🖥️ Localhost (127.0.0.1)'),
                  backgroundColor: AppTheme.charcoalCard,
                  side: const BorderSide(color: AppTheme.charcoalBorder),
                  labelStyle: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textWhite),
                  onPressed: () {
                    setState(() {
                      _serverController.text = 'http://127.0.0.1:8000';
                    });
                  },
                ),
                ActionChip(
                  label: const Text('☁️ Cloud VPS (165.22.41.58)'),
                  backgroundColor: AppTheme.charcoalCard,
                  side: const BorderSide(color: AppTheme.charcoalBorder),
                  labelStyle: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textWhite),
                  onPressed: () {
                    setState(() {
                      _serverController.text = 'http://165.22.41.58:8000';
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Reactive Live Status Message
            StreamBuilder<bool>(
              stream: LiveBotService().connectionStatusStream,
              initialData: LiveBotService().isConnected,
              builder: (ctx, snap) {
                final isLive = snap.data ?? false;
                final message = isLive
                    ? '✓ Live Telemetry Streaming (${LiveBotService().baseUrl})'
                    : (_serverSuccessMessage ?? '⚠️ Offline — Auto-reconnecting in background...');
                final color = isLive ? const Color(0xFF00E5FF) : AppTheme.referenceOrange;

                return Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // Single Global Connect Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isConnectingServer ? null : _saveAndConnectServer,
                icon: _isConnectingServer
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.public_rounded, size: 18),
                label: Text(
                  _isConnectingServer ? 'Connecting...' : 'Connect Global Engine',
                  style: GoogleFonts.spaceMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
