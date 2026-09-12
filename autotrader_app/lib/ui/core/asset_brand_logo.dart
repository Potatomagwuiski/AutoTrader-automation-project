import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';

/// Renders authentic, official stock brand logos with network and vector fallbacks
class AssetBrandLogo extends StatelessWidget {
  final String symbol;
  final double size;

  const AssetBrandLogo({
    super.key,
    required this.symbol,
    this.size = 40,
  });

  static const _bundledLogos = {
    'AMD',
    'ARM',
    'MRVL',
    'SNOW',
    'NVDA',
    'AAPL',
    'MSFT',
    'TSLA',
    'GOOGL',
    'AMZN',
  };

  @override
  Widget build(BuildContext context) {
    final sym = symbol.toUpperCase().trim();
    final hasBundled = _bundledLogos.contains(sym);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.charcoalInnerPill,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.charcoalInnerBorder, width: 1),
      ),
      child: ClipOval(
        child: Center(
          child: hasBundled
              ? Image.asset(
                  'assets/logos/$sym.png',
                  width: size * 0.62,
                  height: size * 0.62,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => _buildFallback(sym),
                )
              : Image.network(
                  'https://financialmodelingprep.com/image-stock/$sym.png',
                  width: size * 0.62,
                  height: size * 0.62,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => _buildFallback(sym),
                ),
        ),
      ),
    );
  }

  Widget _buildFallback(String sym) {
    return SizedBox(
      width: size * 0.58,
      height: size * 0.58,
      child: CustomPaint(
        painter: _BrandLogoPainter(symbol: sym),
      ),
    );
  }
}

class _BrandLogoPainter extends CustomPainter {
  final String symbol;

  _BrandLogoPainter({required this.symbol});

  @override
  void paint(Canvas canvas, Size size) {
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final strokeWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (symbol) {
      // 1. BITCOIN (₿)
      case 'BTC':
      case 'BITCOIN':
        _paintBitcoin(canvas, size, whitePaint, strokeWhite);
        break;

      // 2. ETHEREUM (Geometric 3D Diamond)
      case 'ETH':
      case 'ETHEREUM':
        _paintEthereum(canvas, size);
        break;

      // 3. TETHER (₮ with Oval Ring)
      case 'USDT':
      case 'TETHER':
        _paintTether(canvas, size, whitePaint, strokeWhite);
        break;

      // 4. AMD (Iconic Arrow Chevrons)
      case 'AMD':
        _paintAmd(canvas, size, whitePaint);
        break;

      // 5. ARM (Iconic Arm Architecture Micro-Lines)
      case 'ARM':
        _paintArm(canvas, size, whitePaint);
        break;

      // 6. NVDA (Nvidia Spiral Eye / Claw)
      case 'NVDA':
      case 'NVIDIA':
        _paintNvidia(canvas, size, whitePaint);
        break;

      // 7. APPLE (Iconic Silhouette)
      case 'AAPL':
      case 'APPLE':
        _paintApple(canvas, size, whitePaint);
        break;

      // 8. TESLA (Tesla T badge)
      case 'TSLA':
      case 'TESLA':
        _paintTesla(canvas, size, whitePaint);
        break;

      // 9. SNOWFLAKE (Snowflake star)
      case 'SNOW':
        _paintSnowflake(canvas, size, strokeWhite);
        break;

      // 10. MARVELL (Marvell M)
      case 'MRVL':
      case 'MARVELL':
        _paintMarvell(canvas, size);
        break;

      // 11. DEFAULT
      default:
        _paintDefaultTicker(canvas, size, symbol);
        break;
    }
  }

  // Authentic Bitcoin Logo (₿ with double vertical bars)
  void _paintBitcoin(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '₿',
        style: GoogleFonts.spaceMono(
          fontSize: size.height * 0.95,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  // Authentic Ethereum 3D Diamond
  void _paintEthereum(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top pyramid (Light facet)
    final topLight = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.85, h * 0.55)
      ..lineTo(w * 0.5, h * 0.42)
      ..close();

    final lightPaint = Paint()..color = const Color(0xFFE2E8F0);
    canvas.drawPath(topLight, lightPaint);

    // Top pyramid (Dark facet)
    final topDark = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.15, h * 0.55)
      ..lineTo(w * 0.5, h * 0.42)
      ..close();

    final darkPaint = Paint()..color = const Color(0xFF94A3B8);
    canvas.drawPath(topDark, darkPaint);

    // Bottom pyramid (Light facet)
    final botLight = Path()
      ..moveTo(w * 0.5, h * 0.48)
      ..lineTo(w * 0.85, h * 0.59)
      ..lineTo(w * 0.5, h)
      ..close();

    canvas.drawPath(botLight, lightPaint);

    // Bottom pyramid (Dark facet)
    final botDark = Path()
      ..moveTo(w * 0.5, h * 0.48)
      ..lineTo(w * 0.15, h * 0.59)
      ..lineTo(w * 0.5, h)
      ..close();

    canvas.drawPath(botDark, darkPaint);
  }

  // Authentic Tether Logo (₮ with Oval Ring)
  void _paintTether(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final w = size.width;
    final h = size.height;

    // Oval Ring
    final ovalPaint = Paint()
      ..color = const Color(0xFF26A17B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.52), width: w * 0.85, height: h * 0.32),
      ovalPaint,
    );

    // T Bar
    final tPath = Path()
      ..moveTo(w * 0.22, h * 0.22)
      ..lineTo(w * 0.78, h * 0.22)
      ..lineTo(w * 0.78, h * 0.38)
      ..lineTo(w * 0.58, h * 0.38)
      ..lineTo(w * 0.58, h * 0.86)
      ..lineTo(w * 0.42, h * 0.86)
      ..lineTo(w * 0.42, h * 0.38)
      ..lineTo(w * 0.22, h * 0.38)
      ..close();

    canvas.drawPath(tPath, fill);
  }

  // Authentic AMD Logo (Dual Chevrons Arrow)
  void _paintAmd(Canvas canvas, Size size, Paint fill) {
    final w = size.width;
    final h = size.height;

    // Outer Large Chevron
    final p1 = Path()
      ..moveTo(w * 0.05, h * 0.1)
      ..lineTo(w * 0.55, h * 0.1)
      ..lineTo(w * 0.95, h * 0.5)
      ..lineTo(w * 0.55, h * 0.9)
      ..lineTo(w * 0.05, h * 0.9)
      ..lineTo(w * 0.45, h * 0.5)
      ..close();

    final amdPaint = Paint()..color = const Color(0xFFED1C24);
    canvas.drawPath(p1, amdPaint);

    // Inner Cutout Chevron
    final p2 = Path()
      ..moveTo(w * 0.25, h * 0.3)
      ..lineTo(w * 0.5, h * 0.3)
      ..lineTo(w * 0.7, h * 0.5)
      ..lineTo(w * 0.5, h * 0.7)
      ..lineTo(w * 0.25, h * 0.7)
      ..lineTo(w * 0.45, h * 0.5)
      ..close();

    final bgCut = Paint()..color = AppTheme.charcoalInnerPill;
    canvas.drawPath(p2, bgCut);
  }

  // Authentic ARM Logo (Clean Arm Architecture Lettering)
  void _paintArm(Canvas canvas, Size size, Paint fill) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'arm',
        style: GoogleFonts.inter(
          fontSize: size.height * 0.65,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF0091BD),
          letterSpacing: -1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  // Authentic Nvidia Logo (Green Eye / Claw)
  void _paintNvidia(Canvas canvas, Size size, Paint fill) {
    final w = size.width;
    final h = size.height;

    final nvdPaint = Paint()
      ..color = const Color(0xFF76B900)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.14
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(w * 0.15, h * 0.5)
      ..quadraticBezierTo(w * 0.5, h * 0.05, w * 0.85, h * 0.5)
      ..quadraticBezierTo(w * 0.5, h * 0.95, w * 0.25, h * 0.65);

    canvas.drawPath(path, nvdPaint);
  }

  // Authentic Apple Logo
  void _paintApple(Canvas canvas, Size size, Paint fill) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '',
        style: TextStyle(
          fontSize: size.height * 0.9,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  // Authentic Tesla Logo (Tesla T)
  void _paintTesla(Canvas canvas, Size size, Paint fill) {
    final w = size.width;
    final h = size.height;

    final tslaPaint = Paint()..color = const Color(0xFFE82127);

    final topBar = Path()
      ..moveTo(w * 0.1, h * 0.2)
      ..quadraticBezierTo(w * 0.5, h * 0.35, w * 0.9, h * 0.2)
      ..lineTo(w * 0.85, h * 0.12)
      ..quadraticBezierTo(w * 0.5, h * 0.25, w * 0.15, h * 0.12)
      ..close();

    canvas.drawPath(topBar, tslaPaint);

    final tBody = Path()
      ..moveTo(w * 0.38, h * 0.38)
      ..lineTo(w * 0.62, h * 0.38)
      ..lineTo(w * 0.56, h * 0.88)
      ..lineTo(w * 0.44, h * 0.88)
      ..close();

    canvas.drawPath(tBody, tslaPaint);
  }

  // Snowflake Logo
  void _paintSnowflake(Canvas canvas, Size size, Paint stroke) {
    final w = size.width;
    final h = size.height;
    final snowPaint = Paint()
      ..color = const Color(0xFF29B5E8)
      ..strokeWidth = w * 0.1
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h), snowPaint);
    canvas.drawLine(Offset(0, h * 0.5), Offset(w, h * 0.5), snowPaint);
    canvas.drawLine(Offset(w * 0.15, h * 0.15), Offset(w * 0.85, h * 0.85), snowPaint);
    canvas.drawLine(Offset(w * 0.85, h * 0.15), Offset(w * 0.15, h * 0.85), snowPaint);
  }

  // Authentic Marvell Logo (Iconic Red M)
  void _paintMarvell(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final mrvlPaint = Paint()
      ..color = const Color(0xFFE31837)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(w * 0.15, h * 0.85)
      ..lineTo(w * 0.15, h * 0.20)
      ..lineTo(w * 0.50, h * 0.65)
      ..lineTo(w * 0.85, h * 0.20)
      ..lineTo(w * 0.85, h * 0.85);

    canvas.drawPath(path, mrvlPaint);
  }

  // Default Ticker Fallback
  void _paintDefaultTicker(Canvas canvas, Size size, String sym) {
    final label = sym.length > 3 ? sym.substring(0, 3) : sym;
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: GoogleFonts.spaceMono(
          fontSize: size.height * 0.45,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BrandLogoPainter oldDelegate) =>
      oldDelegate.symbol != symbol;
}
