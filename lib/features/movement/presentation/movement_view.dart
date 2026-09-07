import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/movement_models.dart';
import '../providers/movement_provider.dart';
import '../providers/foreground_service_provider.dart';
import '../widgets/route_recording_card.dart';
import '../widgets/recent_routes_list.dart';

/// Comprehensive Movement & Step Tracking Dashboard.
class MovementView extends ConsumerWidget {
  const MovementView({super.key});

  void _showManualLogDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: '1000');
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.directions_walk_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Log Steps Manually'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Step Count',
                suffixText: 'steps',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'e.g. Evening walk in the park',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final steps = int.tryParse(controller.text) ?? 0;
              if (steps > 0) {
                await ref.read(stepTrackingProvider.notifier).logManualSteps(
                      steps,
                      notes: notesController.text,
                    );
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logged $steps steps!')),
                  );
                }
              }
            },
            child: const Text('Log Steps'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepState = ref.watch(stepTrackingProvider);
    final dbStepsAsync = ref.watch(todayStepCountStreamProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use live sensor count or fallback to today's database count
    final totalSteps = stepState.stepsToday > 0
        ? stepState.stepsToday
        : (dbStepsAsync.value ?? 0);

    final numberFormat = NumberFormat('#,###');
    final formattedSteps = numberFormat.format(totalSteps);
    final progress = (totalSteps / stepState.dailyTarget).clamp(0.0, 1.0);
    final percentage = (progress * 100).toInt();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status & Mode Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Movement',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMMM d').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(context, stepState),
              ],
            ),
            const SizedBox(height: 24),

            // Large Circular Step Gauge
            Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background track
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 16,
                        color: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    // Foreground progress
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 16,
                        strokeCap: StrokeCap.round,
                        color: colorScheme.primary,
                      ),
                    ),
                    // Inner stats display
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_walk_rounded,
                          size: 28,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedSteps,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1.0,
                          ),
                        ),
                        Text(
                          'Goal: ${numberFormat.format(stepState.dailyTarget)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            '$percentage%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Secondary Metrics Cards
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.straighten_rounded,
                    iconColor: Colors.blueAccent,
                    label: 'Distance',
                    value: '${(totalSteps * 0.762 / 1000).toStringAsFixed(2)} km',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: Colors.orangeAccent,
                    label: 'Active Burn',
                    value: '${(totalSteps * 0.04).toStringAsFixed(0)} kcal',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: stepState.isWalking
                        ? Icons.directions_run_rounded
                        : Icons.accessibility_new_rounded,
                    iconColor: stepState.isWalking ? Colors.green : Colors.grey,
                    label: 'Cadence',
                    value: stepState.isWalking ? 'Active' : 'Resting',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Background Foreground Service Active Session Card
            Consumer(
              builder: (context, ref, _) {
                final isTracking = ref.watch(foregroundServiceProvider);
                return Card(
                  elevation: 0,
                  color: isTracking
                      ? colorScheme.primaryContainer.withAlpha(60)
                      : colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                    side: BorderSide(
                      color: isTracking
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                    ),
                  ),
                  child: SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: isTracking
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 20,
                        color: isTracking
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: const Text(
                      'Persistent Background Service',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      isTracking
                          ? 'Active • Sticky notification prevents OS kill'
                          : 'Disabled • OS may throttle sensors when locked',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: isTracking,
                    onChanged: (val) async {
                      final notifier =
                          ref.read(foregroundServiceProvider.notifier);
                      if (val) {
                        await notifier.startTracking(
                          title: 'Cadence Workout Active',
                          text: '$totalSteps steps • ${stepState.pedestrianStatus}',
                        );
                      } else {
                        await notifier.stopTracking();
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Live GPS Route Recording Card
            const RouteRecordingCard(),
            const SizedBox(height: 24),

            // Historical Completed GPS Routes
            const RecentRoutesList(),
            const SizedBox(height: 24),

            // Quick-Log Action Buttons
            Text(
              'Quick Add Steps',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ref
                        .read(stepTrackingProvider.notifier)
                        .logManualSteps(500, notes: '+500 quick log'),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+500'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ref
                        .read(stepTrackingProvider.notifier)
                        .logManualSteps(1000, notes: '+1000 quick log'),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+1,000'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showManualLogDialog(context, ref),
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text('Custom'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Cross-Module Goal Integration Card
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.track_changes_rounded,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Connected to Daily Goals',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Step entries automatically update your Daily Step Goals and unbroken streaks on the Today dashboard.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, MovementState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String label;
    IconData icon;
    Color badgeColor;

    switch (state.status) {
      case StepSensorStatus.listening:
        if (state.isWalking) {
          label = 'Walking';
          icon = Icons.directions_walk_rounded;
          badgeColor = Colors.green;
        } else {
          label = 'Hardware Live';
          icon = Icons.sensors_rounded;
          badgeColor = colorScheme.primary;
        }
        break;
      case StepSensorStatus.permissionDenied:
        label = 'Permission Needed';
        icon = Icons.warning_amber_rounded;
        badgeColor = Colors.orange;
        break;
      case StepSensorStatus.unavailable:
        label = 'Manual Mode';
        icon = Icons.touch_app_rounded;
        badgeColor = colorScheme.secondary;
        break;
      case StepSensorStatus.stopped:
      case StepSensorStatus.initial:
        label = 'Idle';
        icon = Icons.pause_circle_outline_rounded;
        badgeColor = colorScheme.outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(30),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: badgeColor.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: badgeColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 10.0),
        child: Column(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
