import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/route_models.dart';
import '../providers/route_recording_provider.dart';

/// Interactive UI Card for controlling GPS Route Recording.
class RouteRecordingCard extends ConsumerStatefulWidget {
  const RouteRecordingCard({super.key});

  @override
  ConsumerState<RouteRecordingCard> createState() => _RouteRecordingCardState();
}

class _RouteRecordingCardState extends ConsumerState<RouteRecordingCard> {
  ActivityType _selectedActivity = ActivityType.walk;

  void _showDiscardDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Route?'),
        content: const Text(
          'Are you sure you want to discard this recorded route? All coordinate breadcrumbs for this session will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Recording'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              ref.read(routeRecordingProvider.notifier).cancelRoute();
              Navigator.of(ctx).pop();
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeRecordingProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (routeState.status == RouteRecordingStatus.completed) {
      return _buildCompletedSummary(context, routeState, colorScheme);
    }

    if (routeState.isActive) {
      return _buildActiveRecordingCard(context, routeState, colorScheme);
    }

    return _buildIdleCard(context, colorScheme);
  }

  Widget _buildIdleCard(BuildContext context, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.route_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outdoor GPS Tracking',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Record trail, pace, distance & altitude',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Activity Type Selector Segmented Row
            SegmentedButton<ActivityType>(
              segments: const [
                ButtonSegment(
                  value: ActivityType.walk,
                  label: Text('Walk'),
                  icon: Icon(Icons.directions_walk_rounded),
                ),
                ButtonSegment(
                  value: ActivityType.run,
                  label: Text('Run'),
                  icon: Icon(Icons.directions_run_rounded),
                ),
                ButtonSegment(
                  value: ActivityType.cycle,
                  label: Text('Cycle'),
                  icon: Icon(Icons.directions_bike_rounded),
                ),
              ],
              selected: {_selectedActivity},
              onSelectionChanged: (set) {
                if (set.isNotEmpty) {
                  setState(() => _selectedActivity = set.first);
                }
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Start ${_selectedActivity.label}'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                ),
                onPressed: () async {
                  await ref.read(routeRecordingProvider.notifier).startRoute(
                        title: 'Outdoor ${_selectedActivity.label}',
                        activityType: _selectedActivity,
                      );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRecordingCard(
    BuildContext context,
    RouteRecordingState state,
    ColorScheme colorScheme,
  ) {
    final isRecording = state.isRecording;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
        side: BorderSide(
          color: isRecording ? colorScheme.primary : colorScheme.tertiary,
          width: 1.5,
        ),
      ),
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Status Header
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRecording ? Colors.green : Colors.amber,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isRecording ? 'LIVE TRACKING' : 'PAUSED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: isRecording ? Colors.green : Colors.amber,
                  ),
                ),
                const Spacer(),
                Text(
                  state.activityType.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live Metrics Grid
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'DISTANCE',
                    value: state.formattedDistance,
                    color: colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    label: 'DURATION',
                    value: state.formattedDuration,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'AVG PACE',
                    value: state.formattedPace,
                    color: colorScheme.secondary,
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    label: 'SPEED',
                    value: state.formattedSpeed,
                    color: colorScheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Control Buttons Row
            Row(
              children: [
                // Discard Button
                IconButton.outlined(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Discard',
                  color: colorScheme.error,
                  onPressed: () => _showDiscardDialog(context, ref),
                ),
                const SizedBox(width: 12),
                // Pause / Resume Button
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(
                      isRecording
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(isRecording ? 'Pause' : 'Resume'),
                    onPressed: () {
                      if (isRecording) {
                        ref.read(routeRecordingProvider.notifier).pauseRoute();
                      } else {
                        ref.read(routeRecordingProvider.notifier).resumeRoute();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Finish / Stop Button
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Finish'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                    ),
                    onPressed: () {
                      ref.read(routeRecordingProvider.notifier).stopRoute();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedSummary(
    BuildContext context,
    RouteRecordingState state,
    ColorScheme colorScheme,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
      color: colorScheme.primaryContainer.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Route Complete!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  state.activityType.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MetricTile(
                  label: 'TOTAL DISTANCE',
                  value: state.formattedDistance,
                  color: colorScheme.primary,
                ),
                _MetricTile(
                  label: 'TOTAL TIME',
                  value: state.formattedDuration,
                  color: colorScheme.onSurface,
                ),
                _MetricTile(
                  label: 'AVG PACE',
                  value: state.formattedPace,
                  color: colorScheme.secondary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ref.read(routeRecordingProvider.notifier).reset();
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
