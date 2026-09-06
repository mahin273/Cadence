import 'package:flutter/material.dart';

/// Circadian phases throughout a 24-hour cycle.
enum CircadianPhase {
  day,
  dusk,
  night,
  dawn,
}

class CircadianTheme {
  /// Default seed color if Android dynamic color is not available.
  static const Color defaultSeedColor = Color(0xFF0D9488); // Modern Teal

  /// Fallback base schemes
  static final ColorScheme defaultLightScheme = ColorScheme.fromSeed(
    seedColor: defaultSeedColor,
    brightness: Brightness.light,
  );

  static final ColorScheme defaultDarkScheme = ColorScheme.fromSeed(
    seedColor: defaultSeedColor,
    brightness: Brightness.dark,
  );

  /// Warm dusk palette (reduces blue light, warmer undertones)
  static final ColorScheme warmDuskScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFD97706), // Warm Amber
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF1C1917), // Warm Stone
    onSurface: const Color(0xFFF5F5F4),
  );

  /// Deep AMOLED night palette
  static final ColorScheme deepNightScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0E7490), // Cyan/Night
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF09090B), // Near Black Zinc
    onSurface: const Color(0xFFE4E4E7),
  );

  /// Determine the current circadian phase based on time of day.
  static CircadianPhase getPhase(DateTime time) {
    final hour = time.hour + (time.minute / 60.0);
    if (hour >= 6.0 && hour < 18.0) {
      return CircadianPhase.day;
    } else if (hour >= 18.0 && hour < 22.0) {
      return CircadianPhase.dusk;
    } else if (hour >= 22.0 || hour < 5.0) {
      return CircadianPhase.night;
    } else {
      return CircadianPhase.dawn;
    }
  }

  /// Calculates an interpolated [ColorScheme] dynamically adapting to the hour.
  /// 
  /// Uses [ColorScheme.lerp] (which calls [Color.lerp] on each token).
  static ColorScheme computeCircadianScheme({
    required DateTime time,
    ColorScheme? dynamicLight,
    ColorScheme? dynamicDark,
  }) {
    final hour = time.hour + (time.minute / 60.0);
    final light = dynamicLight ?? defaultLightScheme;
    final dark = dynamicDark ?? defaultDarkScheme;

    // 06:00 - 18:00: Pure Daytime
    if (hour >= 6.0 && hour < 18.0) {
      return light;
    }

    // 18:00 - 22:00: Evening transition into warm dusk (4-hour blend)
    if (hour >= 18.0 && hour < 22.0) {
      final t = (hour - 18.0) / 4.0; // 0.0 at 18:00 -> 1.0 at 22:00
      return ColorScheme.lerp(dark, warmDuskScheme, t);
    }

    // 22:00 - 05:00: Deep Night
    if (hour >= 22.0 || hour < 5.0) {
      return deepNightScheme;
    }

    // 05:00 - 06:00: Dawn transition back to daytime (1-hour blend)
    final t = (hour - 5.0) / 1.0;
    return ColorScheme.lerp(deepNightScheme, light, t);
  }

  /// Builds a [ThemeData] configured for Material 3 Expressive.
  static ThemeData buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: CardThemeData(
        elevation: 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 2.0,
        indicatorColor: colorScheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
