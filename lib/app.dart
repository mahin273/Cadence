import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'core/theme/circadian_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/security/security_providers.dart';
import 'core/security/presentation/app_lock_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';

class CadenceApp extends ConsumerWidget {
  const CadenceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeSettingsProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ThemeData themeData;
        ThemeData darkThemeData;
        ThemeMode themeMode;

        final lightFallback = lightDynamic ?? CircadianTheme.defaultLightScheme;
        final darkFallback = darkDynamic ?? CircadianTheme.defaultDarkScheme;

        switch (themeSettings.mode) {
          case AppThemeMode.light:
            themeData = CircadianTheme.buildTheme(lightFallback);
            darkThemeData = CircadianTheme.buildTheme(darkFallback);
            themeMode = ThemeMode.light;
            break;

          case AppThemeMode.dark:
            themeData = CircadianTheme.buildTheme(lightFallback);
            darkThemeData = CircadianTheme.buildTheme(darkFallback);
            themeMode = ThemeMode.dark;
            break;

          case AppThemeMode.system:
            themeData = CircadianTheme.buildTheme(lightFallback);
            darkThemeData = CircadianTheme.buildTheme(darkFallback);
            themeMode = ThemeMode.system;
            break;

          case AppThemeMode.circadian:
            final activeTime = themeSettings.simulatedTime ?? DateTime.now();
            final circadianScheme = CircadianTheme.computeCircadianScheme(
              time: activeTime,
              dynamicLight: lightDynamic,
              dynamicDark: darkDynamic,
            );
            themeData = CircadianTheme.buildTheme(circadianScheme);
            darkThemeData = themeData;
            themeMode = ThemeMode.light;
            break;
        }

        return MaterialApp(
          title: 'Cadence',
          debugShowCheckedModeBanner: false,
          theme: themeData,
          darkTheme: darkThemeData,
          themeMode: themeMode,
          home: Consumer(
            builder: (context, ref, _) {
              final isLocked = ref.watch(isAppLockedProvider);
              if (isLocked) {
                return const AppLockScreen();
              }
              return const DashboardScreen();
            },
          ),
        );
      },
    );
  }
}
