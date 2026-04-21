import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF183765);
  static const secondary = Color(0xFF47BDB1);

  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF1F5F9);

  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  static const darkBackground = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF111B2E);
  static const darkSurfaceMuted = Color(0xFF1A2742);
  static const darkText = Color(0xFFE2E8F0);
  static const darkTextMuted = Color(0xFF94A3B8);
  static const darkBorder = Color(0xFF26334F);
}

ThemeData buildAppTheme() {
  return _buildTheme(Brightness.light);
}

ThemeData buildDarkAppTheme() {
  return _buildTheme(Brightness.dark);
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: isDark ? AppColors.darkSurface : AppColors.surface,
      error: AppColors.error,
      brightness: brightness,
    ),
    scaffoldBackgroundColor:
        isDark ? AppColors.darkBackground : AppColors.background,
  );

  final textColor = isDark ? AppColors.darkText : AppColors.text;
  final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
  final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    displaySmall: GoogleFonts.inter(
      fontSize: 32,
      height: 1.4,
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: 24,
      height: 1.4,
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: 22,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 20,
      height: 1.45,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w500,
      color: textColor,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w500,
      color: textColor,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12,
      height: 1.5,
      fontWeight: FontWeight.w500,
      color: mutedColor,
    ),
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: borderColor),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: textColor,
      titleTextStyle: textTheme.titleLarge,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.textMuted;
          }
          if (states.contains(WidgetState.pressed)) {
            return const Color(0xFF132D54);
          }
          return AppColors.primary;
        }),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: AppColors.secondary, width: 1.25),
        foregroundColor: AppColors.secondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.darkSurfaceMuted : AppColors.surfaceMuted,
      labelStyle: textTheme.bodyMedium?.copyWith(color: mutedColor),
      hintStyle: textTheme.bodyMedium?.copyWith(color: mutedColor),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 1.4),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      elevation: 0,
      indicatorColor: AppColors.secondary.withValues(alpha: 0.18),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primary);
        }
        return IconThemeData(color: mutedColor);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          );
        }
        return GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: mutedColor,
        );
      }),
    ),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      margin: const EdgeInsets.all(8),
    ),
    dividerTheme: DividerThemeData(color: borderColor, thickness: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.surfaceMuted,
    ),
  );
}
