import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/haptics.dart';
import '../../../core/theme.dart';
import '../../../../data/services/live_bot_service.dart';
import '../view_models/dashboard_view_model.dart';

class AlpacaHeaderCard extends StatelessWidget {
  const AlpacaHeaderCard({super.key});

  void _openDiagnostics(BuildContext context, DashboardViewModel vm) {
    AppHaptics.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _BackendDiagnosticsSheet(viewModel: vm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();
    final isLive = viewModel.isLiveEngineConnected;

    return GestureDetector(
      onTap: () => _openDiagnostics(context, viewModel),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: AppTheme.charcoalCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.charcoalBorder),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.charcoalInnerPill,
                    border: Border.all(color: AppTheme.charcoalInnerBorder),
                  ),
                  child: const Center(
                    child: Text('👨🏻', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Alpaca Linked',
                          style: GoogleFonts.spaceMono(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textWhite,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isLive ? AppTheme.mint : Colors.amber).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (isLive ? AppTheme.mint : Colors.amber).withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isLive ? AppTheme.mint : Colors.amber,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isLive ? 'LIVE ENGINE' : 'STANDBY SIM',
                                style: GoogleFonts.spaceMono(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: isLive ? AppTheme.mint : Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      isLive ? 'Real-Time Telemetry Bridge Active' : 'Offline Simulator Active',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.charcoalInnerPill,
                border: Border.all(color: AppTheme.charcoalInnerBorder),
              ),
              child: Icon(
                isLive ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: isLive ? AppTheme.mint : AppTheme.textMuted,
                size: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackendDiagnosticsSheet extends StatefulWidget {
  final DashboardViewModel viewModel;

  const _BackendDiagnosticsSheet({required this.viewModel});

  @override
  State<_BackendDiagnosticsSheet> createState() => _BackendDiagnosticsSheetState();
}

class _BackendDiagnosticsSheetState extends State<_BackendDiagnosticsSheet> {
  bool _isChecking = false;
  String? _pingResult;

  Future<void> _testPing() async {
    setState(() {
      _isChecking = true;
      _pingResult = null;
    });

    final stopwatch = Stopwatch()..start();
    final ok = await LiveBotService().checkConnection();
    stopwatch.stop();

    if (mounted) {
      setState(() {
        _isChecking = false;
        _pingResult = ok
            ? 'Connected • ${stopwatch.elapsedMilliseconds}ms Latency'
            : 'Connection Failed • Server Unreachable';
      });
      widget.viewModel.reconnectBackend();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLive = widget.viewModel.isLiveEngineConnected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Engine Bridge Diagnostics',
                style: GoogleFonts.spaceMono(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isLive ? AppTheme.mint : Colors.amber).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isLive ? 'ONLINE' : 'OFFLINE',
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isLive ? AppTheme.mint : Colors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Server Host', LiveBotService().baseUrl),
          _buildInfoRow('WebSocket Stream', isLive ? 'ws://127.0.0.1:8000/ws/telemetry' : 'Disconnected'),
          _buildInfoRow('Active Regime', widget.viewModel.state.activeRegime),
          _buildInfoRow('Canary Gen', 'Gen #42 (Evolution Active)'),
          if (_pingResult != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.charcoalInnerPill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _pingResult!,
                style: GoogleFonts.spaceMono(
                  fontSize: 11,
                  color: isLive ? AppTheme.mint : Colors.amber,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.charcoalInnerPill,
                    foregroundColor: AppTheme.textWhite,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppTheme.charcoalInnerBorder),
                    ),
                  ),
                  onPressed: _isChecking ? null : _testPing,
                  icon: _isChecking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.mint),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    'PING SERVER',
                    style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mint,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    AppHaptics.selectionClick();
                    widget.viewModel.triggerUniverseScan();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.radar_rounded, size: 16),
                  label: Text(
                    'SCAN 500 S&P',
                    style: GoogleFonts.spaceMono(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
          Text(
            value,
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textWhite,
            ),
          ),
        ],
      ),
    );
  }
}
