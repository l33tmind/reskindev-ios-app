import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Brand Colors ────────────────────────────────────────────
  static const Color primary       = Color(0xFF00C6A2); // Teal
  static const Color primaryDark   = Color(0xFF00A888);
  static const Color primaryLight  = Color(0xFFB2F5EA);
  static const Color accent        = Color(0xFF6C5CE7); // Purple accent
  static const Color accentLight   = Color(0xFFEDE9FE);

  // ─── Status Colors ───────────────────────────────────────────
  static const Color success       = Color(0xFF10B981);
  static const Color warning       = Color(0xFFF59E0B);
  static const Color error         = Color(0xFFEF4444);
  static const Color info          = Color(0xFF3B82F6);

  // ─── Light Theme Colors ──────────────────────────────────────
  static const Color background    = Color(0xFFF0F4F8);
  static const Color surface       = Colors.white;
  static const Color surfaceCard   = Color(0xFFFFFFFF);
  static const Color textDark      = Colors.black;
  static const Color textLight     = Color(0xFF475569);
  static const Color textMuted     = Color(0xFF94A3B8);
  static const Color border        = Color(0xFFE2E8F0);

  // ─── Dark Theme Colors ───────────────────────────────────────
  static const Color darkBackground  = Color(0xFF0A0F1E);
  static const Color darkSurface     = Color(0xFF111827);
  static const Color darkCard        = Color(0xFF1A2236);
  static const Color darkBorder      = Color(0xFF2D3748);
  static const Color darkText        = Color(0xFFF1F5F9);
  static const Color darkTextLight   = Color(0xFF94A3B8);

  // ─── Gradients ───────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C6A2), Color(0xFF6C5CE7)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F172A), Color(0xFF115E59), Color(0xFF0F172A)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C6A2), Color(0xFF0095A8)],
  );

  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C5CE7), Color(0xFF8B5CF6)],
  );

  // ─── Light Theme ─────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: surface,
        onSurface: textDark,
        onPrimary: Colors.white,
        error: error,
        outline: border,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge:  GoogleFonts.outfit(color: textDark, fontWeight: FontWeight.w900, fontSize: 40),
        displayMedium: GoogleFonts.outfit(color: textDark, fontWeight: FontWeight.w800, fontSize: 32),
        headlineLarge: GoogleFonts.outfit(color: textDark, fontWeight: FontWeight.w800, fontSize: 26),
        headlineMedium: GoogleFonts.outfit(color: textDark, fontWeight: FontWeight.w700, fontSize: 22),
        titleLarge:    GoogleFonts.outfit(color: textDark, fontWeight: FontWeight.w700, fontSize: 18),
        titleMedium:   GoogleFonts.inter(color: textDark,  fontWeight: FontWeight.w600, fontSize: 15),
        bodyLarge:     GoogleFonts.inter(color: textDark,  fontSize: 15),
        bodyMedium:    GoogleFonts.inter(color: textLight, fontSize: 13),
        labelLarge:    GoogleFonts.inter(color: textDark,  fontWeight: FontWeight.w600, fontSize: 13),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        iconTheme: const IconThemeData(color: textDark),
        titleTextStyle: GoogleFonts.outfit(
          color: textDark, fontWeight: FontWeight.w800, fontSize: 20,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.2),
        ),
        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: textDark, fontSize: 14),
        floatingLabelStyle: GoogleFonts.inter(color: primary, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: primary);
          }
          return GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }
          return const IconThemeData(color: textMuted, size: 24);
        }),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: background,
        selectedColor: primary.withValues(alpha: 0.15),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        side: const BorderSide(color: border),
      ),
      dividerTheme: const DividerThemeData(color: border, space: 1),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  // ─── Dark Theme ──────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primary,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: darkSurface,
        onSurface: darkText,
        onPrimary: Colors.white,
        error: error,
        outline: darkBorder,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge:  GoogleFonts.outfit(color: darkText, fontWeight: FontWeight.w900, fontSize: 40),
        displayMedium: GoogleFonts.outfit(color: darkText, fontWeight: FontWeight.w800, fontSize: 32),
        headlineLarge: GoogleFonts.outfit(color: darkText, fontWeight: FontWeight.w800, fontSize: 26),
        headlineMedium: GoogleFonts.outfit(color: darkText, fontWeight: FontWeight.w700, fontSize: 22),
        titleLarge:    GoogleFonts.outfit(color: darkText, fontWeight: FontWeight.w700, fontSize: 18),
        titleMedium:   GoogleFonts.inter(color: darkText,  fontWeight: FontWeight.w600, fontSize: 15),
        bodyLarge:     GoogleFonts.inter(color: darkText,  fontSize: 15),
        bodyMedium:    GoogleFonts.inter(color: darkTextLight, fontSize: 13),
        labelLarge:    GoogleFonts.inter(color: darkText,  fontWeight: FontWeight.w600, fontSize: 13),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        iconTheme: const IconThemeData(color: darkText),
        titleTextStyle: GoogleFonts.outfit(
          color: darkText, fontWeight: FontWeight.w800, fontSize: 20,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: primary.withValues(alpha: 0.20),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: primary);
          }
          return GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: darkTextLight);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }
          return const IconThemeData(color: darkTextLight, size: 24);
        }),
        elevation: 0,
        height: 68,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: GoogleFonts.inter(color: darkTextLight, fontSize: 14),
      ),
    );
  }
}


extension ThemeColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get themeBackground => isDarkMode ? AppTheme.darkBackground : AppTheme.background;
  Color get themeSurface => isDarkMode ? AppTheme.darkSurface : AppTheme.surface;
  Color get themeTextDark => isDarkMode ? AppTheme.darkText : AppTheme.textDark;
  Color get themeTextLight => isDarkMode ? AppTheme.darkTextLight : AppTheme.textLight;
  Color get themeBorder => isDarkMode ? AppTheme.darkBorder : AppTheme.border;
  Color get themeCard => isDarkMode ? AppTheme.darkCard : AppTheme.surfaceCard;
}
