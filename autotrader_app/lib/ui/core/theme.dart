import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Exact luxury multi-variant black / dark graphite palette from reference
  static const Color appBackground = Color(0xFF0C0D10);
  static const Color scaffoldBg = Color(0xFF0C0D10);
  static const Color charcoalCard = Color(0xFF17181D);
  static const Color charcoalCardSecondary = Color(0xFF1D1E24);
  static const Color charcoalInnerPill = Color(0xFF23242A);
  static const Color charcoalBorder = Color(0xFF23242A);
  static const Color charcoalInnerBorder = Color(0xFF2D2E36);

  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF7E828C);
  static const Color textDim = Color(0xFF50535C);

  static const Color mint = Color(0xFF4ADE80); // Exact pastel lime green
  static const Color mintDarkBg = Color(0xFF142B1A);
  static const Color mintDarkBorder = Color(0xFF1E4628);
  static const Color referenceGreen = Color(0xFF4ADE80);
  static const Color referenceRed = Color(0xFFF87171); // Exact soft coral red
  static const Color referenceOrange = Color(0xFFFF5C00); // Exact center floating orange
  static const Color emeraldShariah = Color(0xFF10B981);
  static const Color coralRed = Color(0xFFF87171);
  static const Color cyanFloor = Color(0xFF22D3EE);
  static const Color geminiBlue = Color(0xFF4E82EE); // Signature Google Gemini Electric Blue
  static const Color geminiPurple = Color(0xFF9B72CF); // Gemini secondary glow
  static const Color charcoalSurface = Color(0xFF23242A);
  static const Color charcoalButton = Color(0xFF23242A);
  static const Color charcoalButtonBorder = Color(0xFF2D2E36);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: appBackground,
      fontFamily: GoogleFonts.spaceMono().fontFamily,
      textTheme: GoogleFonts.spaceMonoTextTheme().apply(
        bodyColor: textWhite,
        displayColor: textWhite,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
      ),
    );
  }

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get dockShadow => cardShadow;
}
