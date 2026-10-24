import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kInk = Color(0xFF1E2B33);
const kPaper = Color(0xFFF1F3F1);
const kPine = Color(0xFF2F5D50);
const kOchre = Color(0xFFB7791F);
const kBrick = Color(0xFFA4372B);
const kSlate = Color(0xFF3D5A6C);
const kLine = Color(0xFFDDE3E5);

/// Headline font: Fraunces, a warm serif with character.
/// Body font (set in the theme): Atkinson Hyperlegible, designed for low vision.
TextStyle serif(
  double size, {
  FontWeight weight = FontWeight.w700,
  Color color = kInk,
  double? height,
  double? letterSpacing,
}) =>
    GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(seedColor: kPine, surface: kPaper).copyWith(
    primary: kPine,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFDDE8E3),
    onPrimaryContainer: kInk,
    secondaryContainer: const Color(0xFFE3E9EC),
    onSecondaryContainer: kInk,
    tertiaryContainer: const Color(0xFFF6E8CC),
    onTertiaryContainer: kInk,
    onSurface: kInk,
  );
  final base = ThemeData(colorScheme: scheme, scaffoldBackgroundColor: kPaper);
  // Scale every style by hand. TextTheme.apply(fontSizeFactor:) asserts when
  // any style has a null fontSize, which some Flutter versions leave unset.
  const scale = 1.15;
  TextStyle? big(TextStyle? t) =>
      t?.copyWith(fontSize: (t.fontSize ?? 14) * scale);
  TextStyle? serifOf(TextStyle? t) => t == null
      ? null
      : GoogleFonts.fraunces(textStyle: t, fontWeight: FontWeight.w700);

  final raw = GoogleFonts.atkinsonHyperlegibleTextTheme(base.textTheme)
      .apply(bodyColor: kInk, displayColor: kInk); // colors only: no size args
  final textTheme = TextTheme(
    displayLarge: serifOf(big(raw.displayLarge)),
    displayMedium: serifOf(big(raw.displayMedium)),
    displaySmall: serifOf(big(raw.displaySmall)),
    headlineLarge: serifOf(big(raw.headlineLarge)),
    headlineMedium: serifOf(big(raw.headlineMedium)),
    headlineSmall: serifOf(big(raw.headlineSmall)),
    titleLarge: serifOf(big(raw.titleLarge)),
    titleMedium: big(raw.titleMedium),
    titleSmall: big(raw.titleSmall),
    bodyLarge: big(raw.bodyLarge),
    bodyMedium: big(raw.bodyMedium),
    bodySmall: big(raw.bodySmall),
    labelLarge: big(raw.labelLarge),
    labelMedium: big(raw.labelMedium),
    labelSmall: big(raw.labelSmall),
  );

  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  final buttonText = GoogleFonts.atkinsonHyperlegible(
      fontSize: 18, fontWeight: FontWeight.w700);

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: kPaper,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: serif(26, weight: FontWeight.w800),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: const Color(0x26000000),
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: kLine),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
          minimumSize: const Size(88, 56), textStyle: buttonText, shape: shape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(88, 56),
        textStyle: buttonText,
        shape: shape,
        side: const BorderSide(color: kPine, width: 1.5),
        foregroundColor: kPine,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
          minimumSize: const Size(64, 48), textStyle: buttonText),
    ),
  );
}
