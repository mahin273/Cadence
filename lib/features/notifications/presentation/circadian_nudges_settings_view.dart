import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_providers.dart';

/// Settings screen for configuring circadian-aware notifications,
/// hourly hydration pacing, and focus recovery nudges.
class CircadianNudgesSettingsView extends ConsumerWidget {
  const CircadianNudgesSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final prefs = ref.watch(notificationPreferencesProvider);
    final prefsNotifier = ref.read(notificationPreferencesProvider.notifier);
    final service = ref.watch(circadianNotificationServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Circadian Nudges & Alerts'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Informational Card
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withAlpha(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biologically Paced, Never Spammed',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Unlike rigid interval timers, Cadence consults your local SQLite database first. If you are on track with your water intake, you will never be alerted.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Master Switch
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: const Text(
              'Enable Circadian Nudges',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Allow contextual notifications on this device'),
            value: prefs.masterEnabled,
            onChanged: (val) {
              prefsNotifier.toggleMaster(val);
              if (val) {
                service.requestPermission();
              }
            },
          ),

          const Divider(height: 24),

          // Sub-options
          Opacity(
            opacity: prefs.masterEnabled ? 1.0 : 0.4,
            child: IgnorePointer(
              ignoring: !prefs.masterEnabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Text(
                      'CONTEXTUAL MODES',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),

                  // 1. Paced Hydration
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.water_drop_outlined, color: Colors.blue, size: 20),
                    ),
                    title: const Text('Paced Hydration Nudge'),
                    subtitle: Text(
                      'Checks actual intake against hourly target (${prefs.dailyWaterTargetGlasses} glasses/day)',
                    ),
                    value: prefs.pacedHydrationEnabled,
                    onChanged: (val) => prefsNotifier.togglePacedHydration(val),
                  ),

                  // 2. Circadian Phase Shifts
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.wb_twilight_rounded, color: Colors.amber, size: 20),
                    ),
                    title: const Text('Circadian Phase Shifts'),
                    subtitle: const Text('Alerts at Dawn, Daylight Peak, Dusk, and Night transitions'),
                    value: prefs.circadianTransitionsEnabled,
                    onChanged: (val) => prefsNotifier.toggleCircadianTransitions(val),
                  ),

                  // 3. Deep Work Recovery
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.hourglass_bottom_rounded, color: Colors.purple, size: 20),
                    ),
                    title: const Text('Deep Work Recovery'),
                    subtitle: const Text('Prompts posture, eye relief, and hydration after 45m+ focus blocks'),
                    value: prefs.focusRecoveryEnabled,
                    onChanged: (val) => prefsNotifier.toggleFocusRecovery(val),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Diagnostic and Testing Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              'TESTING & DIAGNOSTICS',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),

          OutlinedButton.icon(
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send Test Circadian Notification'),
            onPressed: () async {
              await service.showTestNudge();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Test notification dispatched via local channel'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),

          OutlinedButton.icon(
            icon: const Icon(Icons.speed_rounded, size: 18),
            label: const Text('Simulate Paced Hydration Check'),
            onPressed: () async {
              final triggered = await service.checkAndTriggerPacedHydrationNudge();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      triggered
                          ? 'Hydration deficit detected: Paced nudge triggered!'
                          : 'Hydration is on pace: Nudge suppressed to avoid spam.',
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
