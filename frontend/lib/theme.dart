import 'package:flutter/material.dart';

// ── Design token colors (from Whisper Coach Design System) ──────────────────

const kBrand = Color(0xFF1D9E75);
const kBrandPressed = Color(0xFF168363);
const kBrandSubtle = Color(0xFFE1F5EE);
const kBrandBorder = Color(0xFF5DCAA5);
const kTextBrand = Color(0xFF0F6E56); // dark green for AI labels

const kPitch = Color(0xFF2D7A3E);
const kPitchDark = Color(0xFF246332);
const kPitchLight = Color(0xFF35914A);
const kPitchLine = Color(0x59FFFFFF); // rgba(255,255,255,0.35)

const kSurfacePage = Color(0xFFF5F5F4);
const kSurfaceCard = Color(0xFFFFFFFF);
const kSurfaceInverse = Color(0xFF0A0A0A);

const kTextPrimary = Color(0xFF1A1A1A);
const kTextSecondary = Color(0xFF666666);
const kTextTertiary = Color(0xFF999999);
const kTextOnBrand = Color(0xFFFFFFFF);

const kBorderHairline = Color(0x1F000000); // rgba(0,0,0,0.12)
const kBorderStrong = Color(0x33000000); // rgba(0,0,0,0.20)

const kAmberBg = Color(0xFFFAEEDA);
const kAmberFg = Color(0xFF854F0B);
const kRedBg = Color(0xFFFCEBEB);
const kRedFg = Color(0xFFA32D2D);
const kGreenBg = Color(0xFFE1F5EE);
const kGreenFg = Color(0xFF0F6E56);

// ── Radii ────────────────────────────────────────────────────────────────────

const kRadiusInput = 8.0;
const kRadiusCard = 12.0;
const kRadiusSheet = 16.0;

// ── Text styles ──────────────────────────────────────────────────────────────

const kStyleScreenTitle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w500,
  color: kTextPrimary,
  height: 1.3,
);

const kStyleBody = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  color: kTextPrimary,
  height: 1.5,
);

const kStyleBodyMd = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w400,
  color: kTextPrimary,
  height: 1.5,
);

const kStyleSecondary = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w400,
  color: kTextSecondary,
  height: 1.5,
);

const kStyleLabel = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w500,
  color: kTextSecondary,
  letterSpacing: 0.06 * 11,
);

// ── Theme ────────────────────────────────────────────────────────────────────

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kBrand,
      primary: kBrand,
      onPrimary: kTextOnBrand,
      surface: kSurfacePage,
      onSurface: kTextPrimary,
    ),
    scaffoldBackgroundColor: kSurfacePage,
    appBarTheme: const AppBarTheme(
      backgroundColor: kSurfaceCard,
      foregroundColor: kTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: kStyleScreenTitle,
      centerTitle: false,
      shadowColor: kBorderHairline,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: kSurfaceCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
        side: const BorderSide(color: kBorderHairline, width: 0.5),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceCard,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusInput),
        borderSide: const BorderSide(color: kBorderStrong, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusInput),
        borderSide: const BorderSide(color: kBorderStrong, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusInput),
        borderSide: const BorderSide(color: kBrand, width: 1.5),
      ),
      labelStyle: kStyleSecondary.copyWith(color: kTextTertiary),
      hintStyle: kStyleBody.copyWith(color: kTextTertiary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kBrand,
        foregroundColor: kTextOnBrand,
        elevation: 0,
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusInput),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        minimumSize: const Size(double.infinity, 46),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kTextPrimary,
        side: const BorderSide(color: kBorderStrong),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusInput),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kSurfaceCard,
      side: const BorderSide(color: kBorderStrong, width: 1),
      labelStyle:
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: const StadiumBorder(),
    ),
    dividerTheme: const DividerThemeData(
      color: kBorderHairline,
      thickness: 0.5,
      space: 0,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: kSurfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: kBorderStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusInput),
        side: const BorderSide(color: kBorderHairline, width: 0.5),
      ),
      // Ensure menu items are always dark text on the white menu surface
      // (without this, items with no explicit style render unreadably on iOS).
      textStyle: kStyleBody,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kSurfaceCard,
      selectedItemColor: kBrand,
      unselectedItemColor: kTextTertiary,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle:
          TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      unselectedLabelStyle:
          TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kSurfaceInverse,
      contentTextStyle:
          const TextStyle(color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusInput),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
