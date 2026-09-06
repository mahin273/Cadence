import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeMode {
  circadian,
  light,
  dark,
  system,
}

class ThemeSettings {
  final AppThemeMode mode;
  final DateTime? simulatedTime;

  const ThemeSettings({
    this.mode = AppThemeMode.circadian,
    this.simulatedTime,
  });

  ThemeSettings copyWith({
    AppThemeMode? mode,
    DateTime? Function()? simulatedTime,
  }) {
    return ThemeSettings(
      mode: mode ?? this.mode,
      simulatedTime: simulatedTime != null ? simulatedTime() : this.simulatedTime,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeSettings> {
  @override
  ThemeSettings build() {
    return const ThemeSettings();
  }

  void setThemeMode(AppThemeMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setSimulatedTime(DateTime? time) {
    state = state.copyWith(simulatedTime: () => time);
  }

  void resetToActualTime() {
    state = state.copyWith(simulatedTime: () => null);
  }
}

final themeSettingsProvider = NotifierProvider<ThemeNotifier, ThemeSettings>(
  ThemeNotifier.new,
);
