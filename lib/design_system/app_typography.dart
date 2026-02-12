import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Two-font typography system for Bark
/// Font 1: Joti One - for hero text, display, and h1 titles (playful, bold)
/// Font 2: Poppins - for all other text (clean, modern, various weights)
class AppTypography {
  // Helper to safely try Google Font or fallback to system
  static TextStyle _safeJotiOne({
    double fontSize = 32,
    FontWeight fontWeight = FontWeight.w400,
    double letterSpacing = 0,
    double height = 1.2,
    Color? color,
  }) {
    try {
      return GoogleFonts.jotiOne(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        color: color,
      );
    } catch (_) {
      // Fallback to system font
      return TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700, // Bold to mimic display font
        fontFamily: 'Georgia', // iOS fallback
        letterSpacing: letterSpacing,
        height: height,
        color: color,
      );
    }
  }

  static TextStyle _safePoppins({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    double letterSpacing = 0.25,
    double height = 1.5,
    Color? color,
    TextDecoration? decoration,
  }) {
    try {
      return GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
        color: color,
        decoration: decoration,
      );
    } catch (_) {
      // Fallback to system font
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: '.SF Pro Text', // iOS system font
        letterSpacing: letterSpacing,
        height: height,
        color: color,
        decoration: decoration,
      );
    }
  }

  // Display styles (Joti One - extra large headings)
  static TextStyle display1({Color? color, FontWeight? fontWeight}) =>
      _safeJotiOne(
        fontSize: 40,
        fontWeight: fontWeight ?? FontWeight.w400,
        letterSpacing: 0,
        height: 1.2,
        color: color,
      );

  static TextStyle display2({Color? color, FontWeight? fontWeight}) =>
      _safeJotiOne(
        fontSize: 32,
        fontWeight: fontWeight ?? FontWeight.w400,
        letterSpacing: 0,
        height: 1.2,
        color: color,
      );

  // H1 style (Joti One - page titles)
  static TextStyle h1({Color? color, FontWeight? fontWeight}) => _safeJotiOne(
        fontSize: 28,
        fontWeight: fontWeight ?? FontWeight.w400,
        letterSpacing: 0,
        height: 1.25,
        color: color,
      );

  // H2 and below (Poppins)
  static TextStyle h2({Color? color, FontWeight? fontWeight}) => _safePoppins(
        fontSize: 24,
        fontWeight: fontWeight ?? FontWeight.w500,
        letterSpacing: 0,
        height: 1.3,
        color: color,
      );

  static TextStyle h3({Color? color, FontWeight? fontWeight}) => _safePoppins(
        fontSize: 20,
        fontWeight: fontWeight ?? FontWeight.w500,
        letterSpacing: 0,
        height: 1.3,
        color: color,
      );

  static TextStyle h4({Color? color, FontWeight? fontWeight}) => _safePoppins(
        fontSize: 18,
        fontWeight: fontWeight ?? FontWeight.w500,
        letterSpacing: 0.15,
        height: 1.4,
        color: color,
      );

  // Body styles (Poppins - lighter weights)
  static TextStyle bodyLarge({Color? color, FontWeight? fontWeight}) =>
      _safePoppins(
        fontSize: 16,
        fontWeight: fontWeight ?? FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.5,
        color: color,
      );

  static TextStyle bodyMedium({Color? color, FontWeight? fontWeight}) =>
      _safePoppins(
        fontSize: 14,
        fontWeight: fontWeight ?? FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.5,
        color: color,
      );

  static TextStyle bodySmall({Color? color, FontWeight? fontWeight}) =>
      _safePoppins(
        fontSize: 12,
        fontWeight: fontWeight ?? FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.4,
        color: color,
      );

  // Label styles (Poppins - medium weight for buttons, chips)
  static TextStyle labelLarge({Color? color, FontWeight? fontWeight}) =>
      _safePoppins(
        fontSize: 16,
        fontWeight: fontWeight ?? FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.4,
        color: color,
      );

  static TextStyle labelMedium({Color? color, FontWeight? fontWeight}) =>
      _safePoppins(
        fontSize: 14,
        fontWeight: fontWeight ?? FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.4,
        color: color,
      );

  static TextStyle labelSmall({Color? color, FontWeight? fontWeight}) =>
      _safePoppins(
        fontSize: 12,
        fontWeight: fontWeight ?? FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.4,
        color: color,
      );

  // Caption styles (Poppins - extra light)
  static TextStyle caption({Color? color, FontWeight? fontWeight}) =>
      _safePoppins(
        fontSize: 11,
        fontWeight: fontWeight ?? FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.3,
        color: color,
      );

  // Special styles
  static TextStyle button({Color? color}) => _safePoppins(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.2,
        color: color,
      );

  static TextStyle link({Color? color}) => _safePoppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.4,
        color: color,
        decoration: TextDecoration.underline,
      );

  // Brand title style (Joti One for "Bark" logo text)
  static TextStyle brandTitle({Color? color}) => _safeJotiOne(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        letterSpacing: 1,
        height: 1.2,
        color: color,
      );
}
