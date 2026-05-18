import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color spaceBlack = Color(0xFF090D16);
  static const Color obsidianCard = Color(0xFF151D30);
  static const Color borderBlue = Color(0xFF233554);
  
  static const Color primaryNeon = Color(0xFF6366F1); // Indigo
  static const Color secondaryNeon = Color(0xFF06B6D4); // Cyan/Teal
  
  static const Color successGreen = Color(0xFF10B981); // Emerald
  static const Color warningOrange = Color(0xFFF59E0B); // Amber
  static const Color errorRed = Color(0xFFEF4444); // Rose
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color textWhite = Color(0xFFF8FAFC); // Slate 50

  // Glassmorphic Card Decoration helper
  static BoxDecoration glassCardDecoration({
    Color? color,
    double radius = 16,
    double borderWidth = 1.0,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color ?? obsidianCard.withOpacity(0.8),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? borderBlue.withOpacity(0.5),
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Linear Gradients for Buttons and Hero sections
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryNeon, secondaryNeon],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [spaceBlack, Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Material Theme Data
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: spaceBlack,
      primaryColor: primaryNeon,
      colorScheme: const ColorScheme.dark().copyWith(
        primary: primaryNeon,
        secondary: secondaryNeon,
        background: spaceBlack,
        surface: obsidianCard,
        error: errorRed,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textWhite,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textWhite,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16,
          color: textWhite,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14,
          color: textMuted,
        ),
      ),
      cardTheme: CardThemeData(
        color: obsidianCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderBlue, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: obsidianCard.withOpacity(0.5),
        hintStyle: GoogleFonts.outfit(color: textMuted, fontSize: 14),
        labelStyle: GoogleFonts.outfit(color: textWhite, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderBlue, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderBlue, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryNeon, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: spaceBlack,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textWhite,
        ),
        iconTheme: const IconThemeData(color: textWhite),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNeon,
          foregroundColor: textWhite,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryNeon,
        foregroundColor: textWhite,
        elevation: 6,
      ),
    );
  }
}
