import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Airbnb-inspired typography system
/// Clean, readable, and hierarchical text styles
class AppTypography {
  // Font family
  static String get fontFamily => 'Inter';
  
  // Display styles (extra large headings)
  static TextStyle display1({Color? color, FontWeight? fontWeight}) => GoogleFonts.inter(
    fontSize: 40,
    fontWeight: fontWeight ?? FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
    color: color,
  );
  
  static TextStyle display2({Color? color, FontWeight? fontWeight}) => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: fontWeight ?? FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
    color: color,
  );
  
  // Heading styles
  static TextStyle h1({Color? color, FontWeight? fontWeight}) => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: fontWeight ?? FontWeight.w600,
    letterSpacing: -0.25,
    height: 1.25,
    color: color,
  );
  
  static TextStyle h2({Color? color, FontWeight? fontWeight}) => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: fontWeight ?? FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
    color: color,
  );
  
  static TextStyle h3({Color? color, FontWeight? fontWeight}) => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: fontWeight ?? FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
    color: color,
  );
  
  static TextStyle h4({Color? color, FontWeight? fontWeight}) => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: fontWeight ?? FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.4,
    color: color,
  );
  
  // Body styles
  static TextStyle bodyLarge({Color? color, FontWeight? fontWeight}) => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: fontWeight ?? FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.5,
    color: color,
  );
  
  static TextStyle bodyMedium({Color? color, FontWeight? fontWeight}) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: fontWeight ?? FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.5,
    color: color,
  );
  
  static TextStyle bodySmall({Color? color, FontWeight? fontWeight}) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: fontWeight ?? FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.4,
    color: color,
  );
  
  // Label styles (buttons, chips, etc.)
  static TextStyle labelLarge({Color? color, FontWeight? fontWeight}) => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: fontWeight ?? FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
    color: color,
  );
  
  static TextStyle labelMedium({Color? color, FontWeight? fontWeight}) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: fontWeight ?? FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
    color: color,
  );
  
  static TextStyle labelSmall({Color? color, FontWeight? fontWeight}) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: fontWeight ?? FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
    color: color,
  );
  
  // Caption styles (very small text)
  static TextStyle caption({Color? color, FontWeight? fontWeight}) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: fontWeight ?? FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.3,
    color: color,
  );
  
  // Special styles
  static TextStyle button({Color? color}) => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.2,
    color: color,
  );
  
  static TextStyle link({Color? color}) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
    color: color,
    decoration: TextDecoration.underline,
  );
}
