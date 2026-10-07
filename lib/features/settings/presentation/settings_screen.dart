import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/security/presentation/security_settings_view.dart';
import '../../../core/security/security_providers.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../core/supabase/auth_provider.dart';
import '../../../core/supabase/auth_state.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/theme/circadian_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/presentation/auth_modal.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(appSettingsProvider);
    final themeSettings = ref.watch(themeSettingsProvider);
    final authState = ref.watch(authNotifierProvider);

    final currentTime = themeSettings.simulatedTime ?? DateTime.now();
    final phase = CircadianTheme.getPhase(currentTime);
    final timeFormatter = DateFormat('hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // 1. Account and Profile Card
          _buildAccountCard(context, ref, authState, colorScheme, theme),
          const SizedBox(height: 16),

          // 2. Appearance and Circadian Theme
          _buildThemeSection(
            context,
            ref,
            themeSettings,
            phase,
            currentTime,
            timeFormatter,
            colorScheme,
            theme,
          ),
          const SizedBox(height: 16),

          // 3. Daily Targets and Goals
          _buildGoalsSection(context, ref, settings, colorScheme, theme),
          const SizedBox(height: 16),

          // 4. Focus and Productivity
          _buildFocusSection(context, ref, settings, colorScheme, theme),
          const SizedBox(height: 16),

          // 5. Movement and GPS Tracking
          _buildMovementSection(ref, settings, colorScheme, theme),
          const SizedBox(height: 16),

          // 6. Finance Preferences
          _buildFinanceSection(context, ref, settings, colorScheme, theme),
          const SizedBox(height: 16),

          // 7. Cloud Sync and Storage
          _buildSyncSection(context, ref, settings, colorScheme, theme),
          const SizedBox(height: 16),

          // 8. Security and Privacy
          _buildSecuritySection(context, ref, colorScheme, theme),
          const SizedBox(height: 16),

          // 9. About Cadence
          _buildAboutSection(colorScheme, theme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    WidgetRef ref,
    CadenceAuthState authState,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final user = authState.user;
    final isGuest = user == null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                isGuest ? Icons.person_outline : Icons.person,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isGuest ? 'Offline Guest Mode' : (user.email ?? 'Logged In'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isGuest
                        ? 'Data preserved in local SQLite only'
                        : 'Connected with Supabase cloud backup',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () => AuthModal.show(context),
              child: Text(isGuest ? 'Sign In' : 'Manage'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSection(
    BuildContext context,
    WidgetRef ref,
    ThemeSettings themeSettings,
    CircadianPhase phase,
    DateTime currentTime,
    DateFormat timeFormatter,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Appearance and Circadian Theme',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Theme Mode Selector
            Text(
              'Theme Mode',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ChoiceChip(
                  label: const Text('Circadian'),
                  selected: themeSettings.mode == AppThemeMode.circadian,
                  onSelected: (val) {
                    if (val) {
                      ref
                          .read(themeSettingsProvider.notifier)
                          .setThemeMode(AppThemeMode.circadian);
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Light'),
                  selected: themeSettings.mode == AppThemeMode.light,
                  onSelected: (val) {
                    if (val) {
                      ref
                          .read(themeSettingsProvider.notifier)
                          .setThemeMode(AppThemeMode.light);
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('Dark'),
                  selected: themeSettings.mode == AppThemeMode.dark,
                  onSelected: (val) {
                    if (val) {
                      ref
                          .read(themeSettingsProvider.notifier)
                          .setThemeMode(AppThemeMode.dark);
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('System'),
                  selected: themeSettings.mode == AppThemeMode.system,
                  onSelected: (val) {
                    if (val) {
                      ref
                          .read(themeSettingsProvider.notifier)
                          .setThemeMode(AppThemeMode.system);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Daylight Phase and Circadian Simulation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(_getPhaseIcon(phase), color: colorScheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _getPhaseTitle(phase),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    timeFormatter.format(currentTime),
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getPhaseDescription(phase),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Preview Circadian Shifts (Color.lerp)',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.wb_sunny_outlined, size: 16),
                  label: const Text('Day (12:00)'),
                  onPressed: () {
                    ref.read(themeSettingsProvider.notifier).setSimulatedTime(
                          DateTime(2026, 1, 1, 12, 0),
                        );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.wb_twilight_rounded, size: 16),
                  label: const Text('Dusk (20:00)'),
                  onPressed: () {
                    ref.read(themeSettingsProvider.notifier).setSimulatedTime(
                          DateTime(2026, 1, 1, 20, 0),
                        );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.bedtime_outlined, size: 16),
                  label: const Text('Night (23:00)'),
                  onPressed: () {
                    ref.read(themeSettingsProvider.notifier).setSimulatedTime(
                          DateTime(2026, 1, 1, 23, 0),
                        );
                  },
                ),
                if (themeSettings.simulatedTime != null)
                  ActionChip(
                    avatar: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text('Reset Time'),
                    onPressed: () {
                      ref
                          .read(themeSettingsProvider.notifier)
                          .resetToActualTime();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsSection(
    BuildContext context,
    WidgetRef ref,
    dynamic settings,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.flag_outlined, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Daily Targets and Goals',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.directions_walk_rounded),
            title: const Text('Daily Step Target'),
            subtitle: Text('${settings.stepGoal} steps'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNumberDialog(
              context: context,
              title: 'Daily Step Target',
              initialValue: settings.stepGoal.toDouble(),
              isInteger: true,
              unit: 'steps',
              onSave: (val) => ref
                  .read(appSettingsProvider.notifier)
                  .updateStepGoal(val.toInt()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.water_drop_outlined),
            title: const Text('Daily Hydration Target'),
            subtitle: Text('${settings.waterGoalGlasses.toStringAsFixed(1)} glasses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNumberDialog(
              context: context,
              title: 'Daily Hydration Target',
              initialValue: settings.waterGoalGlasses,
              unit: 'glasses',
              onSave: (val) =>
                  ref.read(appSettingsProvider.notifier).updateWaterGoal(val),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bedtime_outlined),
            title: const Text('Daily Sleep Target'),
            subtitle: Text('${settings.sleepGoalHours.toStringAsFixed(1)} hours'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNumberDialog(
              context: context,
              title: 'Daily Sleep Target',
              initialValue: settings.sleepGoalHours,
              unit: 'hours',
              onSave: (val) =>
                  ref.read(appSettingsProvider.notifier).updateSleepGoal(val),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.phone_android_outlined),
            title: const Text('Screen Time Budget Limit'),
            subtitle:
                Text('${settings.screenTimeLimitHours.toStringAsFixed(1)} hours/day'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNumberDialog(
              context: context,
              title: 'Screen Time Budget Limit',
              initialValue: settings.screenTimeLimitHours,
              unit: 'hours',
              onSave: (val) => ref
                  .read(appSettingsProvider.notifier)
                  .updateScreenTimeLimit(val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusSection(
    BuildContext context,
    WidgetRef ref,
    dynamic settings,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Focus and Pomodoro',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('Focus Duration'),
            subtitle: Text('${settings.pomodoroFocusMinutes} minutes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNumberDialog(
              context: context,
              title: 'Focus Duration',
              initialValue: settings.pomodoroFocusMinutes.toDouble(),
              isInteger: true,
              unit: 'minutes',
              onSave: (val) => ref
                  .read(appSettingsProvider.notifier)
                  .updatePomodoroSettings(focus: val.toInt()),
            ),
          ),
          ListTile(
            title: const Text('Short Break Duration'),
            subtitle: Text('${settings.pomodoroShortBreakMinutes} minutes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNumberDialog(
              context: context,
              title: 'Short Break Duration',
              initialValue: settings.pomodoroShortBreakMinutes.toDouble(),
              isInteger: true,
              unit: 'minutes',
              onSave: (val) => ref
                  .read(appSettingsProvider.notifier)
                  .updatePomodoroSettings(shortBreak: val.toInt()),
            ),
          ),
          ListTile(
            title: const Text('Long Break Duration'),
            subtitle: Text('${settings.pomodoroLongBreakMinutes} minutes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNumberDialog(
              context: context,
              title: 'Long Break Duration',
              initialValue: settings.pomodoroLongBreakMinutes.toDouble(),
              isInteger: true,
              unit: 'minutes',
              onSave: (val) => ref
                  .read(appSettingsProvider.notifier)
                  .updatePomodoroSettings(longBreak: val.toInt()),
            ),
          ),
          SwitchListTile(
            title: const Text('Auto-start Breaks'),
            subtitle: const Text('Start break countdown automatically when focus session completes'),
            value: settings.pomodoroAutoStartBreaks,
            onChanged: (val) => ref
                .read(appSettingsProvider.notifier)
                .updatePomodoroSettings(autoStart: val),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementSection(
    WidgetRef ref,
    dynamic settings,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.directions_run_outlined,
                    color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Movement and GPS Tracking',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Metric Units'),
            subtitle: Text(settings.useMetricUnits
                ? 'Kilometers and meters'
                : 'Miles and feet'),
            value: settings.useMetricUnits,
            onChanged: (val) => ref
                .read(appSettingsProvider.notifier)
                .updateMeasurementUnits(useMetric: val),
          ),
          SwitchListTile(
            title: const Text('High Accuracy GPS'),
            subtitle: const Text('Use high precision satellite fixes during route tracking'),
            value: settings.highAccuracyGps,
            onChanged: (val) => ref
                .read(appSettingsProvider.notifier)
                .updateGpsSettings(highAccuracy: val),
          ),
          SwitchListTile(
            title: const Text('Auto-pause Tracking'),
            subtitle: const Text('Pause active recording when stationary'),
            value: settings.autoPauseTracking,
            onChanged: (val) => ref
                .read(appSettingsProvider.notifier)
                .updateGpsSettings(autoPause: val),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceSection(
    BuildContext context,
    WidgetRef ref,
    dynamic settings,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Finance and Currencies',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('Default Currency'),
            subtitle: Text('Current: ${settings.defaultCurrency}'),
            trailing: DropdownButton<String>(
              value: settings.defaultCurrency,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: '\$', child: Text('USD (\$)')),
                DropdownMenuItem(value: '€', child: Text('EUR (€)')),
                DropdownMenuItem(value: '£', child: Text('GBP (£)')),
                DropdownMenuItem(value: '৳', child: Text('BDT (৳)')),
                DropdownMenuItem(value: '₹', child: Text('INR (₹)')),
                DropdownMenuItem(value: '¥', child: Text('JPY (¥)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(appSettingsProvider.notifier)
                      .updateFinanceSettings(currency: val);
                }
              },
            ),
          ),
          ListTile(
            title: const Text('Budget Alert Threshold'),
            subtitle: Text('${(settings.budgetAlertThreshold * 100).toInt()}% of monthly budget'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNumberDialog(
              context: context,
              title: 'Budget Alert Threshold (%)',
              initialValue: (settings.budgetAlertThreshold * 100),
              isInteger: true,
              unit: '%',
              onSave: (val) => ref
                  .read(appSettingsProvider.notifier)
                  .updateFinanceSettings(threshold: val / 100.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncSection(
    BuildContext context,
    WidgetRef ref,
    dynamic settings,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final syncInfo = ref.watch(syncNotifierProvider);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.sync_rounded, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cloud Sync and SQLite Storage',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Sync on Wi-Fi Only'),
            subtitle: const Text('Conserve cellular data for cloud database sync'),
            value: settings.syncWifiOnly,
            onChanged: (val) => ref
                .read(appSettingsProvider.notifier)
                .updateSyncSettings(wifiOnly: val),
          ),
          ListTile(
            title: const Text('Sync Status'),
            subtitle: Text(syncInfo.message ?? syncInfo.status.name.toUpperCase()),
            trailing: FilledButton.tonal(
              onPressed: () => ref.read(syncNotifierProvider.notifier).syncNow(),
              child: const Text('Sync Now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final isAppLockEnabled = ref.watch(appLockEnabledProvider);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.security_outlined,
                    color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Security and Privacy',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Biometric App Lock'),
            subtitle: const Text('Require fingerprint or device unlock on app launch'),
            value: isAppLockEnabled,
            onChanged: (val) async {
              if (val) {
                final bioService = ref.read(biometricServiceProvider);
                final canAuth = await bioService.canAuthenticate();
                if (!canAuth) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Biometrics not available on this device'),
                      ),
                    );
                  }
                  return;
                }
                final success = await bioService.authenticate(
                  localizedReason: 'Verify identity to enable Biometric Lock',
                );
                if (success) {
                  ref.read(appLockEnabledProvider.notifier).setEnabled(true);
                }
              } else {
                ref.read(appLockEnabledProvider.notifier).setEnabled(false);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_zip_outlined),
            title: const Text('Data Sovereignty & Full JSON Backup'),
            subtitle: const Text('Export or import complete local database JSON'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SecuritySettingsView()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(ColorScheme colorScheme, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'About Cadence',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Cadence v1.0.0 (Build 1)',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'A personal productivity and health operating system engineered with an offline-first architecture. All entries, habits, finances, routes, and logs remain sovereign on your device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNumberDialog({
    required BuildContext context,
    required String title,
    required double initialValue,
    required String unit,
    required ValueChanged<double> onSave,
    bool isInteger = false,
  }) {
    final controller = TextEditingController(
      text: isInteger
          ? initialValue.toInt().toString()
          : initialValue.toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            suffixText: unit,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null) {
                onSave(val);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  IconData _getPhaseIcon(CircadianPhase phase) {
    switch (phase) {
      case CircadianPhase.day:
        return Icons.wb_sunny_rounded;
      case CircadianPhase.dusk:
        return Icons.wb_twilight_rounded;
      case CircadianPhase.night:
        return Icons.nightlight_round;
      case CircadianPhase.dawn:
        return Icons.wb_sunny_outlined;
    }
  }

  String _getPhaseTitle(CircadianPhase phase) {
    switch (phase) {
      case CircadianPhase.day:
        return 'Daylight Phase';
      case CircadianPhase.dusk:
        return 'Warm Dusk Transition';
      case CircadianPhase.night:
        return 'Deep AMOLED Night';
      case CircadianPhase.dawn:
        return 'Dawn Emergence';
    }
  }

  String _getPhaseDescription(CircadianPhase phase) {
    switch (phase) {
      case CircadianPhase.day:
        return 'Optimized for high readability and active tracking under natural daylight.';
      case CircadianPhase.dusk:
        return 'Warmer amber undertones interpolate smoothly to minimize blue light strain.';
      case CircadianPhase.night:
        return 'Low-contrast AMOLED black palette designed for bed-time reflection.';
      case CircadianPhase.dawn:
        return 'Gradual sunrise luminance gently waking your daily cadence.';
    }
  }
}
