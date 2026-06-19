import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFF1A1411); // dark warm chocolate
  static const surface = Color(0xFF221A16);
  static const surface2 = Color(0xFF2A201B);
  static const border = Color(0x14FFFFFF); // white @ ~0.08
  static const accent = Color(0xFFE07A3F); // vivid burnt orange
  static const accentDim = Color(0x22E07A3F); // accent @ ~0.13
  static const text = Color(0xFFF5EFE9); // slightly warm cream
  static const muted = Color(0xFF8A7F7F); // warm muted gray
  static const sage = Color(0xFFA8C9A8); // soft sage for "mastered" state

  // Feature section backgrounds (rotated through each section)
  static const sectionBg1 = Color(0xFF1A1411);
  static const sectionBg2 = Color(0xFF211814);
  static const sectionBg3 = Color(0xFF1D1612); // subtle warm shift
}

class AppText {
  // Fraunces — used for hero + feature headlines (display serif)
  static TextStyle serif({
    required double size,
    FontWeight weight = FontWeight.w500,
    FontStyle style = FontStyle.normal,
    Color? color,
    double letterSpacing = -0.5,
    double height = 1.1,
  }) => GoogleFonts.fraunces(
    fontSize: size,
    fontWeight: weight,
    fontStyle: style,
    letterSpacing: letterSpacing,
    height: height,
    color: color ?? AppColors.text,
  );

  // Outfit — used for everything else (body sans)
  static TextStyle sans({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.outfit(
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppColors.text,
    letterSpacing: letterSpacing,
    height: height,
  );
}

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.bg,
  textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
);
