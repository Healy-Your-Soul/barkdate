import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Two-font typography system for Bark
/// Font 1: Joti One - for hero text, display, and h1 titles (playful, bold)
/// Font 2: Poppins - for all other text (clean, modern, various weights)
class AppTypography {
  // Display styles (Joti One - extra large headings)
  static TextStyle display1({Color? color, FontWeight? fontWeight}) => GoogleFonts.jotiOne(
    fontSize: 40,
    fontWeight: fontWeight ?? FontWeight.w400, // Joti One only has regular weight
    letterSpacing: 0,
    height: 1.2,
    color: color,
  );
  
  static TextStyle display2({Color? color, FontWeight? fontWeight}) => GoogleFonts.jotiOne(
    fontSize: 32,
    fontWeight: fontWeight ?? FontWeight.w400,
    letterSpacing: 0,
    height: 1.2,
    color: color,
  );
  
  // H1 style (Joti One - page titles)
  static TextStyle h1({Color? color, FontWeight? fontWeight}) => GoogleFonts.jotiOne(
    fontSize: 28,
    fontWeight: fontWeight ?? FontWeight.w400,
    letterSpacing: 0,
    height: 1.25,
    color: color,
  );
  
  // H2 and below (Poppins)
  static TextStyle h2({Color? color, FontWeight? fontWeight}) => GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: fontWeight ?? FontWeight.w500, // Medium
    letterSpacing: 0,
    height: 1.3,
    color: color,
  );
  
  static TextStyle h3({Color? color, FontWeight? fontWeight}) => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: fontWeight ?? FontWeight.w500, // Medium
    letterSpacing: 0,
    height: 1.3,
    color: color,
  );
  
  static TextStyle h4({Color? color, FontWeight? fontWeight}) => GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: fontWeight ?? FontWeight.w500, // Medium
    letterSpacing: 0.15,
    height: 1.4,
    color: color,
  );
  
  // Body styles (Poppins - lighter weights)
  static TextStyle bodyLarge({Color? color, FontWeight? fontWeight}) => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: fontWeight ?? FontWeight.w400, // Regular
    letterSpacing: 0.15,
    height: 1.5,
    color: color,
  );
  
  static TextStyle bodyMedium({Color? color, FontWeight? fontWeight}) => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: fontWeight ?? FontWeight.w400, // Regular
    letterSpacing: 0.25,
    height: 1.5,
    color: color,
  );
  
  static TextStyle bodySmall({Color? color, FontWeight? fontWeight}) => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: fontWeight ?? FontWeight.w400, // Regular
    letterSpacing: 0.4,
    height: 1.4,
    color: color,
  );
  
  // Label styles (Poppins - medium weight for buttons, chips)
  static TextStyle labelLarge({Color? color, FontWeight? fontWeight}) => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: fontWeight ?? FontWeight.w500, // Medium
    letterSpacing: 0.1,
    height: 1.4,
    color: color,
  );
  
  static TextStyle labelMedium({Color? color, FontWeight? fontWeight}) => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: fontWeight ?? FontWeight.w500, // Medium
    letterSpacing: 0.5,
    height: 1.4,
    color: color,
  );
  
  static TextStyle labelSmall({Color? color, FontWeight? fontWeight}) => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: fontWeight ?? FontWeight.w500, // Medium
    letterSpacing: 0.5,
    height: 1.4,
    color: color,
  );
  
  // Caption styles (Poppins - extra light)
  static TextStyle caption({Color? color, FontWeight? fontWeight}) => GoogleFonts.poppins(
    fontSize: 11,
    fontWeight: fontWeight ?? FontWeight.w400, // Regular
    letterSpacing: 0.4,
    height: 1.3,
    color: color,
  );
  
  // Special styles
  static TextStyle button({Color? color}) => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500, // Medium
    letterSpacing: 0.5,
    height: 1.2,
    color: color,
  );
  
  static TextStyle link({Color? color}) => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.4,
    color: color,
    decoration: TextDecoration.underline,
  );
  
  // Brand title style (Joti One for "Bark" logo text)
  static TextStyle brandTitle({Color? color}) => GoogleFonts.jotiOne(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    letterSpacing: 1,
    height: 1.2,
    color: color,
  );
}

