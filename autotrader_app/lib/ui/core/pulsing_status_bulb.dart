import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';

class PulsingStatusBulb extends StatefulWidget {
  final bool isActive;
  final String label;
  final Color? activeColor;
  final Color? inactiveColor;
  final VoidCallback? onTap;

  const PulsingStatusBulb({
    super.key,
    required this.isActive,
    required this.label,
    this.activeColor,
    this.inactiveColor,
    this.onTap,
  });

  @override
  State<PulsingStatusBulb> createState() => _PulsingStatusBulbState();
}

class _PulsingStatusBulbState extends State<PulsingStatusBulb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 3.5, end: 12.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.isActive
        ? (widget.activeColor ?? AppTheme.mint)
        : (widget.inactiveColor ?? AppTheme.referenceRed);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Pulsing Bulb (10px diameter with breathing aura)
              Transform.scale(
                scale: widget.isActive ? _scaleAnimation.value : 1.0,
                child: Container(
                  width: 9.5,
                  height: 9.5,
                  decoration: BoxDecoration(
                    color: effectiveColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: effectiveColor.withValues(
                          alpha: widget.isActive ? 0.65 * (_glowAnimation.value / 12.0) : 0.35,
                        ),
                        blurRadius: widget.isActive ? _glowAnimation.value : 5.0,
                        spreadRadius: widget.isActive ? (_glowAnimation.value / 3.5) : 0.6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 3.0,
                      height: 3.0,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              // Subsystem Label
              Text(
                widget.label,
                style: GoogleFonts.spaceMono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: widget.isActive ? AppTheme.textWhite : AppTheme.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
